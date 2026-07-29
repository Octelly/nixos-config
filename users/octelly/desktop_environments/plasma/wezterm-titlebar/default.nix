{ pkgs, config, lib, ... }:

let
  colorsFile = ./SonokaiShusiaWezterm.colors;
in
{
  xdg.dataFile."color-schemes/SonokaiShusiaWezterm.colors".source = colorsFile;

  programs.plasma.configFile.klassyrc = {
    General = {
      MatchTitleBarToApplicationColor = false;
    };
  };

  programs.plasma.window-rules = [{
    description = "Wezterm Sonokai Shusia titlebar";
    match = {
      window-class = { value = "org.wezfurlong.wezterm"; type = "substring"; };
    };
    apply = {
      decocolor = { value = "SonokaiShusiaWezterm"; apply = "force"; };
    };
  }];
}
