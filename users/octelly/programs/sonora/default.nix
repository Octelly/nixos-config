{ lib, ... }:
{
  programs.sonora = rec {
    enable = true;
    settings = {
      check_updates = false; # useless; using a package manager
      close_to_tray = false;
      tray_icon = false;
      stay_awake = true; # no suspend during playback

      hidden_nav = [ "local" ];

      language = "auto"; # system language
      font = "Noto Sans"; #FIXME: get this config from the system font

      normalisation = true; # replaygain
      gapless = true;

      lyrics_providers = [
        "Apple Music"
        "Local"
        "LrcLib"
        "Musixmatch"
        "NetEase"
        "Spotify"
        "YouTube Music"
      ];
      karaoke_lyrics = true;
      blur_lyrics = true; # blurs lyrics based on distance to the current line
      romanized_lyrics = true;
      romanization_scripts = {
        japanese = true;
        chinese = true;
        korean = true;
        cyrillic = false;
        greek = false;
        arabic = false;
        other = false;
      };

      appearance = {
        #theme = "";
        adaptive_theme = true;
        visualizer_style = "wave";
        rounding = "round";

        # adaptive theme looks weird with non-matching windo decorations
        # would it be possible to have Plasma somehow match?
        server_side_decorations = lib.mkDefault (!settings.appearance.adaptive_theme);

        reduce_motion = "system";
        fullscreen_controls_autohide = "automatic";
      };
    };
  };
}
