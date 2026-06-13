{ config, pkgs, ... }: {
  modules = {
    desktop = {
      gaming = {
        steam.enable = true;
        #itch.enable 		= true;
        olympus.enable = true;
        minecraft.enable = true;
      };
      hyprland.enable = false;
      # sway.enable = true;
      river.enable = true;
    };
    hardware.laptop.enable = true;
    system = {
      sound.enable = true;
      xorg = {
        enable = true;
        #layout = "fck";
      };
    };
  };
}
