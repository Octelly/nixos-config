{ lib, ... }: {
  options.nixos.vm.extraConfig = lib.mkOption {
    type = lib.types.deferredModule;
    default = { };
    description = ''
      Module merged into the evaluation when building a VM via
      `nix run .#<host>-vm`.  Set per-host preferences here.
    '';
  };
}
