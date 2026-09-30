{ inputs, pkgs, ... }:
{
  programs.vicinae = {
    enable = true;
    package = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;

    systemd = {
      enable = true;
      autoStart = true;
      environment = {
        USE_LAYER_SHELL = 0;
      };
    };

    enableFirefoxIntegration = true;

    settings = {
      launcher_window = {
        layer_shell.enabled = false;
        compact_mode.enabled = true;
        client_side_decorations = {
          enabled = true;
          border_width = 0;
        };
      };

      tray.enabled = false;

      escape_key_behavior = "close_window";
      pop_to_root_on_close = true;

      font = {
        normal.family = "Noto Sans";
        rendering = "native";
      };

      #theme = {
      #  dark = {
      #    name = "vicinae-dark";
      #  };
      #  light = {
      #    name = "vicinae-light";
      #  };
      #};

      applications.entrypoints = {
        feishin.alias = "music navidrome";
        sonora.alias = "music navidrome";
      };

      favorites = [
        "@Gelei/store.vicinae.bluetooth:devices"
        "@ShyAssassin/vicinae-extension-vscode-recents-0:open-recents"
        "@knoopx/vicinae-extension-nix-0:home-manager-options"
        "@knoopx/vicinae-extension-nix-0:options"
        "@knoopx/vicinae-extension-nix-0:packages"
        "@mmstroik/vicinae-extension-kde-system-settings-0:search-kde-settings"
        "applications:org.kde.spectacle"
        "applications:superproductivity"
        "scripts:spectacle.zsh"
        "shortcuts:sct-aa4e753254b3"
        "shortcuts:sct-cf26f447be75"
        "shortcuts:sct-e541a88157dc"
      ];
      fallbacks = [
        "@mmstroik/vicinae-extension-kde-system-settings-0:search-kde-settings"
        "shortcuts:sct-aa4e753254b3"
        "@knoopx/vicinae-extension-nix-0:packages"
        "files:search"
      ];
      providers = {
        "@Gelei/store.vicinae.bluetooth".preferences.connectionToggleable = true;
        "@ShyAssassin/vicinae-extension-vscode-recents-0".entrypoints.open-recents.alias = "code";
        clipboard.enable = false;
        "@leiserfg/vicinae-extension-ssh-0".preferences.terminal = "wezterm ssh";
        power.entrypoints = {
          sleep.enabled = false;
          soft-reboot.enabled = false;
          reboot.alias = "restart";
          suspend = {
            alias = "sleep";
            preferences.customProgram = "systemctl hybrid-sleep";
          };
        };
        snippets.enabled = false;
      };
    };

    extensions = (with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
      # FIXME: enable once this is resolved:
      # https://github.com/vicinaehq/extensions/blob/afb84fe4b5253777ff82db8e19e6cc0c9b7f811f/flake.nix#L66-L69
      #bluetooth
      #systemd
      github
      kde-system-settings
      nix
      protondb-search
      ssh
      vscode-recents
    ]);
  };

}
