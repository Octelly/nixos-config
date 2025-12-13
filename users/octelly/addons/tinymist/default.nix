{ pkgs, ... }: {
  home.packages = with pkgs; [
    tinymist
  ];

  programs.vscode.extensions = with pkgs.vscode-extensions; [
    myriad-dreamin.tinymist
  ];
}
