{ config, lib, ... }:

with builtins;
with lib;
let cfg = config.modules.system.sound;
in {
  options.modules.system.sound = {
    enable = mkEnableOption "sound";
  };

  config = mkIf cfg.enable {
    systemd.user.services = {
      pipewire.wantedBy = [ "default.target" ];
      pipewire-pulse.wantedBy = [ "default.target" ];
    };

    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;

      jack.enable = true;
      pulse.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };

      # disable automatic BT headset mode switching
      wireplumber.extraConfig."11-bluetooth-policy" = {
        "wireplumber.settings" = {
          "bluetooth.autoswitch-to-headset-profile" = false;
        };
      };

      # opens UDP ports 6001-6002
      raopOpenFirewall = true;
    };
  };
}
