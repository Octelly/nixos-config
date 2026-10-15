{ config, lib, ... }:
with lib;
let
  cfg = config.lightdark;
in
{
  options.lightdark = {
    enable = mkEnableOption "Enable the lightdark module";
    mode = mkOption {
      type = types.enum [ "light" "dark" ];
      description = "Whether to prefer light or dark schemes";
    };
  };

  config = mkIf cfg.enable {
    dconf.settings =
      let
        color-scheme = builtins.getAttr cfg.mode {
          light = "prefer-light";
          dark = "prefer-dark";
        };
      in
      {
        "org/gnome/desktop/interface" = {
          inherit color-scheme;
        };
        "org/freedesktop/interface" = {
          inherit color-scheme;
        };
      };
    gtk = {
      enable = true;
      colorScheme = cfg.mode;
      gtk3.colorScheme = cfg.mode;
      gtk4.colorScheme = cfg.mode;
    };

  };
}
