{ pkgs, lib, nixosConfigurations, hostNames, modulesPath }:

# this file is based on the upstream Nixpkgs qemu-vm.nix module
# there are quite a few changes that may seem counter-intuitive
# most of these stem from using virtiofs instead of 9p for sharing the host's Nix store with the VM
# 9p/virtiofs migration-related options are marked with [9p->virtiofs] in comments

let
  virtiofsdBin = "${pkgs.virtiofsd}/bin/virtiofsd";

  vmDefaults = {
    # the VM disk uses ext4, not btrfs — these services would error out or
    # waste resources on an ephemeral filesystem
    services.btrfs.autoScrub.enable = lib.mkForce false;
    services.beesd.filesystems = lib.mkForce { };

    # [9p->virtiofs]
    # virtiofs must be available in initrd to mount /nix/.ro-store
    # before the overlay can be assembled
    boot.initrd.kernelModules = [ "virtiofs" ];

    # [9p->virtiofs]
    # virtiofsd opens one file handle per inode it serves
    # the host-side RLIMIT_NOFILE is already raised by the wrapper;
    # this raises the guest's kernel limit to match
    boot.kernel.sysctl."fs.file-max" = lib.mkDefault 2097152;

    # the serial console (ttyS0) works alongside the graphical display,
    # matching the wrapper's default --serial=mon:stdio
    virtualisation.qemu.consoles = lib.mkForce [ "tty0" "ttyS0,115200n8" ];

    virtualisation = {
      # [9p->virtiofs]
      # this option uses 9p to mount the host's nix store —
      # replaced with our implementation
      mountHostNixStore = false;

      # /nix/store needs to be writable so the VM can install packages
      # inside its overlay on top of the read-only virtiofs share
      # -> see fileSystems
      writableStore = true;

      graphics = lib.mkDefault true;
      diskSize = lib.mkDefault 4096;
    };

    # [9p->virtiofs]
    # two-layered Nix store:
    #   1. /nix/.ro-store — virtiofs mount sharing the host's /nix/store
    #   2. /nix/store     — overlayfs on top of .ro-store with a writable
    #                       upper dir on the VM's ephemeral disk
    #
    # this avoids copying the full Nix store into the VM while still
    # allowing the guest to write
    virtualisation.fileSystems = {
      "/nix/.ro-store" = {
        device = "nix-store";
        fsType = "virtiofs";
        neededForBoot = true;
        options = [
          "suid" # needed for setuid wrappers in the store
          "noatime" # nix store is immutable — noatime is free
          "x-initrd.mount" # mounted in initrd before rootfs switch
          "x-systemd.requires=modprobe@virtiofs.service" # module must load before the mount
        ];
      };
      "/nix/store" = {
        overlay = {
          lowerdir = [ "/nix/.ro-store" ];
          upperdir = "/nix/.rw-store/upper";
          workdir = "/nix/.rw-store/work";
        };
        neededForBoot = true;
      };
    };
  };

  buildVm = name:
    let
      host = nixosConfigurations.${name};
    in
    host.extendModules {
      modules = [
        (modulesPath + "/virtualisation/qemu-vm.nix")
        host.config.nixos.vm.extraConfig
        vmDefaults
        { networking.hostName = lib.mkForce "${name}-vm"; }
      ];
    };

  mkRunner = name: vmScript: pkgs.writers.writePython3 "${name}-vm"
    {
      libraries = [ pkgs.python3Packages.click pkgs.python3Packages.systemd-python ];
      flakeIgnore = [ "E501" ];
    } ''
    import os
    import sys
    import time
    import tempfile
    import shutil
    import subprocess
    import atexit
    import resource
    import traceback
    import shlex
    import click
    from systemd import journal

    _cleaned_up = False

    VIRTIOFSD = "${virtiofsdBin}"
    VM_SCRIPT = "${vmScript}"


    def log(msg):
        click.echo(f"[wrapper] {msg}", err=True)


    def log_cmd(args):
        log(f"$ {' '.join(shlex.quote(a) for a in args)}")


    def systemd_run(args, stdout, stderr):
        log_cmd(["systemd-run", "--user", "--collect", "-q"] + args)
        proc = subprocess.Popen(
            ["systemd-run", "--user", "--collect", "-q"] + args,
            stdout=stdout, stderr=stderr,
        )
        rc = proc.wait()
        if rc != 0:
            raise RuntimeError(f"systemd-run exited with code {rc}")
        return proc


    def detect_ram_mb():
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    return int(line.split()[1]) // 1024
        return 4096


    @click.command()
    @click.option("-m", "--ram", type=int, default=0, help="RAM in MiB (default: half of host)")
    @click.option("-c", "--cpus", type=int, default=0, help="Number of CPUs (default: half of host)")
    @click.option("--no-kvm", is_flag=True, help="Disable KVM acceleration")
    @click.option("--display", type=click.Choice(["gtk", "gtk-gl", "sdl", "none"]), default="gtk-gl", help="Display backend (default: gtk-gl)")
    @click.option("--no-virgl", is_flag=True, help="Disable VirGL (use plain virtio VGA instead)")
    @click.option("--serial", default="mon:stdio", help="QEMU serial device (default: mon:stdio)")
    def cli(ram, cpus, no_kvm, display, no_virgl, serial):
        total_ram = detect_ram_mb()
        total_cpus = os.cpu_count() or 4

        if not ram:
            ram = min(total_ram // 2, 8192)
        if not cpus:
            cpus = max(total_cpus // 2, 2)

        soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
        if soft < hard:
            resource.setrlimit(resource.RLIMIT_NOFILE, (hard, hard))
            log(f"RLIMIT_NOFILE: soft={soft}, hard={hard} -> raised soft to {hard}")
        with open("/proc/sys/fs/file-nr") as f:
            parts = f.read().split()
            log(f"Host FD pressure: {parts[0]} open of {parts[2]} max")

        tmpdir = tempfile.mkdtemp(prefix="nixos-vm-")

        os.chdir(tmpdir)
        log(f"Reserving tmpdir at {tmpdir} for VM")

        virtiofs_sock = os.path.join(tmpdir, "virtiofs-nix-store.sock")
        virtiofsd_log = os.path.join(tmpdir, "virtiofsd.log")
        unit_name = f"virtiofsd-{os.path.basename(tmpdir)}"

        log(f"Starting virtiofsd (socket at {virtiofs_sock})...")
        with open(virtiofsd_log, "w") as errlog:
            run_props = [
                "--unit", unit_name,
                "-p", "NoNewPrivileges=yes",
                "-p", "MemoryDenyWriteExecute=yes",
                "-p", "RestrictRealtime=yes",
                "-p", "SystemCallFilter=@system-service open_by_handle_at",
                "-p", "RestrictAddressFamilies=AF_UNIX",
                "-p", "PrivateUsers=no", # no user namespace — breaks UID mapping for virtiofsd
                "--",
                VIRTIOFSD,
                f"--socket-path={virtiofs_sock}",
                "--shared-dir=/nix/store",
                "--cache=always",      # safe: nix store is immutable
                "--writeback",
                "--sandbox=none",       # systemd-run handles sandboxing
                "--seccomp=none",
                "--inode-file-handles=prefer",
                "--thread-pool-size=0",
            ]
            systemd = True
            try:
                virtiofsd = systemd_run(run_props, stdout=subprocess.DEVNULL, stderr=errlog)
            except FileNotFoundError:
                log("systemd-run not found, spawning directly (traceback follows)")
                for line in traceback.format_exc().splitlines():
                    log(line)
                systemd = False
            except PermissionError:
                log("systemd-run not executable, spawning directly (traceback follows)")
                for line in traceback.format_exc().splitlines():
                    log(line)
                systemd = False
            except RuntimeError as e:
                log(f"systemd-run failed ({e}), spawning directly (traceback follows)")
                for line in traceback.format_exc().splitlines():
                    log(line)
                systemd = False
            if systemd:
                log("virtiofsd running via systemd-run")
            else:
                virtiofsd_args = [
                    VIRTIOFSD,
                    f"--socket-path={virtiofs_sock}",
                    "--shared-dir=/nix/store",
                    "--cache=always",      # safe: nix store is immutable
                    "--writeback",
                    "--sandbox=none",       # systemd unavailable — no sandbox
                    "--seccomp=none",
                    "--inode-file-handles=prefer",
                    "--thread-pool-size=0",
                ]
                log_cmd(virtiofsd_args)
                virtiofsd = subprocess.Popen(
                    virtiofsd_args,
                    stdout=subprocess.DEVNULL,
                    stderr=errlog,
                )

        def stop_virtiofsd():
            if systemd:
                log_cmd(["systemctl", "--user", "is-active", unit_name])
                r = subprocess.run(["systemctl", "--user", "is-active", unit_name],
                                   capture_output=True, text=True)
                alive = r.stdout.strip() == "active"
                if alive:
                    log("stopping virtiofsd")
                log_cmd(["systemctl", "--user", "stop", unit_name])
                r = subprocess.run(["systemctl", "--user", "stop", unit_name],
                                   capture_output=True, text=True)
                if r.returncode != 0:
                    err = r.stderr.strip()
                    if alive:
                        log(f"failed to stop virtiofsd: {err}")
            else:
                if virtiofsd.poll() is None:
                    log("stopping virtiofsd")
                    virtiofsd.terminate()
                    virtiofsd.wait()

        def cleanup_tmpdir():
            log(f"removing {tmpdir}")
            try:
                shutil.rmtree(tmpdir)
            except OSError as e:
                log(f"failed to remove tmpdir: {e}")
                for line in traceback.format_exc().splitlines():
                    log(line)

        def cleanup():
            global _cleaned_up
            if _cleaned_up:
                return
            _cleaned_up = True
            stop_virtiofsd()
            cleanup_tmpdir()

        def read_virtiofsd_journal():
            lines = []
            try:
                reader = journal.Reader()
                reader.add_match(_SYSTEMD_UNIT=f"{unit_name}.service")
                reader.seek_tail()
                for _ in range(50):
                    entry = reader.get_previous()
                    if entry is None:
                        break
                    msg = entry.get("MESSAGE", "")
                    if msg:
                        lines.insert(0, msg)
            except Exception:
                pass
            return lines

        def read_virtiofsd_stderr():
            try:
                with open(virtiofsd_log) as f:
                    content = f.read().strip()
                    if content:
                        return content
            except OSError:
                pass
            return None

        def dump_virtiofsd_logs():
            for line in read_virtiofsd_journal():
                log(f"  journal: {line}")
            stderr = read_virtiofsd_stderr()
            if stderr:
                log("  stderr file:")
                for line in stderr.splitlines():
                    log(f"    {line}")

        atexit.register(cleanup)

        for _ in range(50):
            if os.path.exists(virtiofs_sock):
                break
            time.sleep(0.1)
        else:
            log("virtiofsd failed to start")
            dump_virtiofsd_logs()
            sys.exit(1)

        def virtiofsd_alive():
            if systemd:
                r = subprocess.run(
                    ["systemctl", "--user", "is-active", unit_name],
                    capture_output=True, text=True,
                )
                return r.stdout.strip() == "active"
            else:
                return virtiofsd.poll() is None

        def wait_for_socket_file(path, timeout=5.0):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                if os.path.exists(path) and virtiofsd_alive():
                    return True
                time.sleep(0.1)
            return virtiofsd_alive()

        if not wait_for_socket_file(virtiofs_sock):
            log("virtiofsd socket not ready")
            dump_virtiofsd_logs()
            sys.exit(1)

        log("virtiofsd: socket ready")

        if systemd:
            log_cmd(["systemctl", "--user", "show", "--property=MainPID", unit_name])
            r = subprocess.run(
                ["systemctl", "--user", "show", "--property=MainPID", unit_name],
                capture_output=True, text=True
            )
            if r.returncode == 0:
                pid = r.stdout.strip().removeprefix("MainPID=")
                log(f"virtiofsd ready (PID {pid}, sandboxed via systemd)")
            else:
                log("virtiofsd ready (sandboxed via systemd)")
                log("failed to query PID (systemctl show failed)")
                for line in r.stderr.strip().splitlines():
                    log(f"  {line}")
        else:
            log(f"virtiofsd ready (PID {virtiofsd.pid})")

        qemu_opts = (
            f"-m {ram}"
            f" -object memory-backend-memfd,id=mem0,size={ram}M,share=on"
            f" -machine type=q35,accel=kvm:tcg,memory-backend=mem0"
            f" -cpu max"
            f" -smp {cpus}"
            f" -serial {serial}"
            f" -device virtio-rng-pci"
            f" -device virtio-keyboard"
            f" -device usb-tablet,bus=usb-bus.0"
            f" -chardev socket,id=char0,path={virtiofs_sock}"
            f" -device vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=nix-store"
        )

        if no_kvm:
            log("KVM: disabled by --no-kvm")
        elif not os.access("/dev/kvm", os.R_OK | os.W_OK):
            log("KVM: /dev/kvm not accessible — try `groups`; are you in the 'kvm' group?")

        if display == "gtk-gl":
            qemu_opts += " -display gtk,gl=on"
        elif display == "gtk":
            qemu_opts += " -display gtk"
        elif display == "sdl":
            qemu_opts += " -display sdl,gl=on"
        elif display == "none":
            qemu_opts += " -display none"

        if not no_virgl:
            qemu_opts += " -device virtio-vga-gl"
        else:
            qemu_opts += " -vga virtio"

        log(f"Resources: {ram}M RAM, {cpus} CPUs, {display} display, {'virgl' if not no_virgl else 'none'} acceleration")
        for line in read_virtiofsd_journal():
            log(line)
        log(f"Starting QEMU (serial: {serial})...")

        os.environ["QEMU_OPTS"] = qemu_opts

        script = os.environ.get("NIXOS_VM_SCRIPT", VM_SCRIPT)

        vm_name = os.path.basename(script).removeprefix("run-").removesuffix("-vm")
        sys.stdout.write(f"\033]0;{vm_name}\007")
        sys.stdout.flush()

        log_cmd([script])
        rc = subprocess.call([script])
        log("QEMU exited, cleaning up")
        cleanup()
        sys.exit(rc)


    if __name__ == "__main__":
        cli()
  '';

  packages = builtins.listToAttrs (map
    (name: {
      name = "${name}-vm";
      value = (buildVm name).config.system.build.vm;
    })
    hostNames);

  apps = builtins.listToAttrs (map
    (name:
      let
        vmPkg = packages."${name}-vm";
        vmHostName = "${name}-vm";
        vmScript = "${vmPkg}/bin/run-${vmHostName}-vm";
      in
      {
        name = "${name}-vm";
        value = {
          type = "app";
          program = toString (mkRunner name vmScript);
        };
      }
    )
    hostNames);
in
{ inherit packages apps; }
