{ pkgs, lib, config, inputs, ... }:
{
  xdg.configFile = {
    "kde-material-you-colors/config.conf".text =
      let
        hook = pkgs.writers.writePython3 "kde-material-you-colors-hook"
          {
            libraries = [ pkgs.python3Packages.dbus-python ];
            flakeIgnore = [ "E501" ];
          }
          (
            lib.concatStrings ([ ]
              ++ lib.optional config.programs.vicinae.enable ''
              import os
              import re
              import subprocess
              import datetime
              import dbus

              MATUGEN = "${lib.getExe pkgs.matugen}"
              NOTIFY_SEND = "${pkgs.libnotify}/bin/notify-send"

              LOG = "/tmp/matugen-hook.log"


              def strip_ansi(s):
                  return re.sub(r"\x1b\[[0-9;]*[a-zA-Z]", "", s)


              def fail(msg, exc=None, detail=""):
                  ts = datetime.datetime.now().isoformat()
                  with open(LOG, "a") as f:
                      f.write(f"[{ts}] {msg}\n")
                      if detail:
                          for line in detail.strip().splitlines():
                              f.write(f"  {line}\n")
                      if exc:
                          f.write(f"  {type(exc).__name__}: {exc}\n")
                  subprocess.run(
                      [NOTIFY_SEND, "-a", "vicinae", "-t", "0",
                       "vicinae: wallpaper colour update failed",
                       f"{msg}\nsee {LOG} for details"],
                      check=False
                  )


              wallpaper = None

              try:
                  bus = dbus.SessionBus()
                  plasma = dbus.Interface(
                      bus.get_object("org.kde.plasmashell", "/PlasmaShell"),
                      dbus_interface="org.kde.PlasmaShell",
                  )
                  cfg = plasma.wallpaper(0)
                  image = cfg.get("Image") or cfg.get("image")
                  if image:
                      path = image.replace("file://", "")
                      if os.path.isfile(path):
                          wallpaper = path
              except Exception as e:
                  fail("could not detect wallpaper", e, str(e))

              if wallpaper:
                  try:
                      result = subprocess.run(
                          [MATUGEN, "image", wallpaper, "--source-color-index", "0"],
                          capture_output=True, text=True, check=True,
                          stdin=subprocess.DEVNULL
                      )
                  except subprocess.CalledProcessError as e:
                      fail(
                          f"matugen exited {e.returncode}",
                          e,
                          strip_ansi(e.stderr.strip())
                      )
                  except Exception as e:
                      fail("matugen failed", e)
            ''));
      in
      ''
        [CUSTOM]
        pywal = False
        on_change_hook = "${hook}"
        disable_konsole = True
      '';

    "matugen/config.toml".source = pkgs.writers.writeTOML "matugen-config" {
      config = {
        fallback_color = "#4285f4";
        caching = true;
        prefer = "closest-to-fallback";
      };
      templates = { }
        // lib.optionalAttrs config.programs.vicinae.enable {
        vicinae = {
          input_path = "${./vicinae-matugen-template.toml}";
          output_path = "~/.local/share/vicinae/themes/matugen.toml";
          post_hook = "${lib.getExe config.programs.vicinae.package} theme set matugen";
        };
      }
        #  // lib.optionalAttrs config.programs.btop.enable {
        #  btop = {
        #    input_path = "${inputs.matugen-themes}/templates/btop.theme";
        #    output_path = "~/.config/btop/themes/matugen.theme";
        #    post_hook = "pkill -USR2 btop || true";
        #  };
        #}
      ;
    };
  };

  xdg.autostart = {
    enable = lib.mkDefault true;
    entries = [
      ((pkgs.makeDesktopItem {
        name = "kde-material-you-colors";
        destination = "/";

        desktopName = "KDE Material You Colors";
        comment = "Starts/Restarts background process";
        icon = "color-management";

        onlyShowIn = [ "KDE" ];
        startupNotify = false;
        exec = "${lib.getExe pkgs.python314Packages.kde-material-you-colors} -dk";

        extraConfig = {
          "X-KDE-autostart-phase" = "2";
        };
      }) + "/kde-material-you-colors.desktop")
    ];
  };
}
