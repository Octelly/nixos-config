{ lib, ... }:

with builtins;
with lib;

{
  options.modules.hardware.roleFlags = {
    personalComputer = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether this machine is a personal computer (desktop, laptop, etc.)
        used directly by a human. Enables features like VM hosting tooling.
      '';
    };
  };
}
