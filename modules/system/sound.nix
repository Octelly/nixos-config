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

      extraConfig.pipewire = {
        # RAOP/AirPlay streaming to "smart speakers"
        "10-airplay" = {
          "context.modules" = [
            {
              name = "libpipewire-module-raop-discover";

              # increase the buffer size if you get dropouts/glitches
              # args = {
              #   "raop.latency.ms" = 500;
              # };
            }
          ];
        };
        "simple-protocol-stream" = {
          "context.modules" = [
            {
              name = "libpipewire-module-protocol-simple";
              args = {
                capture = true;
                playback = true;

                #audio.rate = 48000;
                #audio.channels = 2;

                server.address = [
                  "tcp:23456"
                ];
              };
            }
          ];
        };
      };

    };
    networking.firewall.allowedTCPPorts = [
      23456 # simple-protocol-stream
    ];
  };
}
