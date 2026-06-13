{ config, pkgs, ... }: {

  modules = {
    hardware.bluetooth.enable = true;
    system = {
      sound.enable = true;
      xorg = {
        enable = true;
      };
    };
  };
}
