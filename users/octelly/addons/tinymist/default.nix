{ pkgs, ... }: {
  home.packages = with pkgs; [
    tinymist
  ];

  programs.vscode.profiles.default.extensions = with pkgs.vscode-extensions; [
    myriad-dreamin.tinymist
  ];
}
