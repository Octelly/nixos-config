{ pkgs, ... }: {
  home.packages = [ pkgs.kdePackages.konsole ];

  programs.konsole = {
    enable = true;
    defaultProfile = "default";

    customColorSchemes.sonokai-shusia = ./sonokai-shusia.colorscheme;

    profiles.default = {
      colorScheme = "sonokai-shusia";
      font = {
        name = "Maple Mono NF";
        size = 9;
      };
      extraConfig = {
        Appearance = {
          AntiAliasFonts = true;
          BoldIntense = true;
          EmojiFont = "Twitter Color Emoji,9";
          UseFontLineChararacters = false;
          UseFontBrailleChararacters = false;
        };
        General = {
          # semantic integration when hints show
          AlternatingBackground = 1;
          AlternatingBars = 1;
          ErrorBackground = 1;
          ErrorBars = 1;
          SemanticHints = 1;

          # use shell-provided title
          LocalTabTitleFormat = "%w";
          RemoteTabTitleFormat = "%w";
        };
        Scrolling = {
          # show left-size highlight for new lines
          HighlightScrolledLines = false;

          # RAM, 1000 lines
          HistoryMode = 1;
          HistorySize = 1000;

          # hide scrollbar
          ScrollBarPosition = 2;
        };
        "Terminal Features" = {
          # system bell
          BellMode = 0;

          BlinkingCursorEnabled = true;
        };
      };
    };

    extraConfig = {
      SplitView.SplitViewVisibility = "AlwaysHideSplitHeader";
      TabBar = {
        CloseTabButton = "None";
        SearchTabsButton = "HideSearchTabsButton";
        TabBarPosition = "Bottom";
      };
    };
  };
}
