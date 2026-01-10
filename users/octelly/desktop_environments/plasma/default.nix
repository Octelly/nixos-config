{ pkgs, config, lib, ... }:
let
  darkMode = true;

  wallpapers = {
    interval = 5 * 60;
    path = "${pkgs.octelly-wallpapers}";
  };
in
{
  home.packages = with pkgs.kdePackages; [
    akonadi # storage
    akonadiconsole # manager (meant for debugging, only way of logging in without full PIM apps)
    kdepim-addons # integration with Digital Clock calendar widget
    kdepim-runtime # runtime
  ];

  programs.plasma = {
    enable = true;

    shortcuts = {
      ksmserver."Lock Session" = [ "Meta+L" "Screensaver" ];
      kwin.KrohnkiteDecrease = "Meta+-";
      kwin.KrohnkiteIncrease = "Meta+=";
      kwin.KrohnkiteToggleFloat = "Meta+Ctrl+Space";
      kwin."Walk Through Windows" = "Alt+Tab";
      kwin."Walk Through Windows (Reverse)" = "Alt+Shift+Tab";
      kwin."Window Close" = "Meta+Q";
      kwin."Window Fullscreen" = "Meta+D";
      kwin."Window Maximize" = "Meta+W";
      kwin."Window Minimize" = "Meta+E";
      kwin."Window Move Center" = "Meta+Home";
      "services/org.kde.dolphin.desktop"._launch = "Meta+F";
      "services/org.kde.krunner.desktop"._launch = "Meta+R";
      "services/org.kde.plasma.emojier.desktop"._launch = "Meta+.";
      #"services/org.kde.spectacle.desktop".RectangularRegionScreenShot = "Ctrl+Shift+Print";
    };



    fonts = rec {
      general = {
        family = "Noto Sans";
        pointSize = 10;
      };
      menu = {
        inherit (general) family;
        pointSize = general.pointSize - 2;
      };
      small = {
        inherit (general) family;
        pointSize = general.pointSize - 2;
      };
      windowTitle = {
        inherit (general) family;
        pointSize = general.pointSize - 1;
      };
      fixedWidth = {
        family = "Maple Mono NF";
        pointSize = 12;
      };
    };

    input = {
      touchpads = [
        {
          name = "SynPS/2 Synaptics TouchPad";
          vendorId = "0002";
          productId = "0007";

          naturalScroll = true;
        }
      ];
      mice = [
        {
          name = "Logitech G502 LIGHTSPEED Wireless Gaming Mouse";
          vendorId = "4403";
          productId = "299667";

          accelerationProfile = "none";
          acceleration = -0.76;
        }
      ];
    };

    kwin = {
      titlebarButtons = {
        left = [
          "more-window-actions"
        ];
        right = [
          "minimize"
          "keep-above-windows"
          "maximize"
          "close"
        ];
      };
    };

    krunner = {
      position = "center";
      activateWhenTypingOnDesktop = false;
      shortcuts.launch = "Meta+R";
    };

    spectacle = {
      shortcuts = {
        captureActiveWindow = [
          "Ctrl+Alt+Print"
          "Ctrl+Alt+Insert"
        ];
        captureCurrentMonitor = [
          "Ctrl+Print"
          "Ctrl+Insert"
        ];
        captureRectangularRegion = [
          "Ctrl+Shift+Print"
          "Ctrl+Shift+Insert"
        ];
        launchWithoutCapturing = [
          "Meta+Print"
          "Meta+Insert"
        ];
      };
    };

    hotkeys.commands = {
      launch-terminal = {
        name = "Launch Terminal";
        key = "Meta+Return";
        command = "wezterm";
      };
      launch-system-monitor = {
        name = "Launch System Monitor";
        key = "Ctrl+Shift+Escape";
        command = "kioclient exec ${pkgs.btop}/share/applications/btop.desktop";
      };
    };

    workspace = {
      cursor = {
        size = 32;
        theme = config.home.pointerCursor.name;
      };
      #colorScheme = if darkMode then "BreezeDark" else "BreezeLight";
      colorScheme = if darkMode then "Libadw-dark" else "Libadw-light";
      #theme = if darkMode then "breeze-dark" else "breeze-light";
      theme = "default";
      #iconTheme = if darkMode then "breeze-dark" else "breeze";
      iconTheme = if darkMode then "klassy-dark" else "klassy";

      splashScreen = {
        engine = "none";
        theme = "None";
      };

      clickItemTo = "select";

      wallpaperSlideShow = wallpapers;
    };

    kscreenlocker.appearance.wallpaperSlideShow = wallpapers;

    #shortcuts = {
    #  "services/org.kde.krunner.desktop" = {
    #    _launch = [ "Search" "Meta+R" ];
    #  };
    #  "services/org.kde.dolphin.desktop" = {
    #    _launch = [ "Meta+F" ];
    #  };
    #  "services/org.kde.spectacle.desktop" = {
    #    OpenWithoutScreenshot = [ ];
    #    ActiveWindowScreenShot = [ ];

    #    CurrentMonitorScreenShot = [
    #      "Ctrl+Print"
    #      "Ctrl+Ins"
    #      "Ctrl+Del"
    #    ];

    #    RectangularRegionScreenShot = [
    #      "Ctrl+Shift+Print"
    #      "Ctrl+Shift+Ins"
    #      "Ctrl+Shift+Del"
    #    ];
    #  };
    #};

    configFile = {
      dolphinrc = {
        General = {
          RememberOpenedTabs = false;
          ShowFullPath = true;
        };
        IconsMode = {
          IconSize = 160;
          PreviewSize = 224;
        };
        PreviewSettings.Plugins = (builtins.concatStringsSep ","
          [
            "appimagethumbnail"
            "audiothumbnail"
            "blenderthumbnail"
            "comicbookthumbnail"
            "cursorthumbnail"
            "djvuthumbnail"
            "ebookthumbnail"
            "exrthumbnail"
            "fontthumbnail"
            "imagethumbnail"
            "jpegthumbnail"
            "kraorathumbnail"
            "windowsexethumbnail"
            "windowsimagethumbnail"
            "mobithumbnail"
            "opendocumentthumbnail"
            "gsthumbnail"
            "rawthumbnail"
            "svgthumbnail"
            "ffmpegthumbs"
          ]);
      };

      kglobalshortcutsrc = {
        "[services][org.kde.spectacle.desktop]" = {
          OpenWithoutScreenshot = "none";
          ActiveWindowScreenShot = "none";

          CurrentMonitorScreenShot = lib.concatStringsSep "\t" [
            "Ctrl+Print"
            "Ctrl+Ins"
            "Ctrl+Del"
          ];

          RectangularRegionScreenShot = lib.concatStringsSep "\t" [
            "Ctrl+Shift+Print"
            "Ctrl+Shift+Ins"
            "Ctrl+Shift+Del"
          ];
        };
        #"[services][org.kde.krunner.desktop]" = {
        #  _launch = lib.concatStringsSep "\t" [ "Search" "Meta+R" ];
        #};
        "[services][org.kde.dolphin.desktop]" = {
          _launch = "Meta+F";
        };
      };
      kdeglobals = {
        General = {
          TerminalApplication = "wezterm start --cwd .";
          TerminalService = "org.wezfurlong.wezterm.desktop";
          fixed = "Maple Mono NF,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          font = "Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          menuFont = "Noto Sans,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          smallestReadableFont = "Noto Sans,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
        };
        Icons.Theme = "klassy-dark";
        KDE = {
          widgetStyle = "Klassy";
          ShowDeleteCommand = false;
          SingleClick = false;
        };
      };
      kwinrc = {
        "org.kde.kdecoration2" = {
          library = "org.kde.klassy";
          theme = "Klassy";
        };

        Effect-blur = {
          BlurStrength = 11;
          NoiseStrength = 14;
        };
        Effect-blurplus = {
          BlurStrength = 11;
          FakeBlur = true;
          NoiseStrength = 14;
          WindowClasses = "org.wezfurlong.wezterm";
        };

        Plugins = {
          blurEnabled = true;
          forceblurEnabled = true;
          krohnkiteEnabled = true;
        };

        Script-khronkite = {
          enableColumnsLayout = false;
          enableMonocleLayout = false;
          enableSpiralLayout = false;
          enableSpreadLayout = false;
          enableStairLayout = false;
          enableThreeColumnLayout = false;
          floatingClass = "mpv,org.kde.gwenview,re.sonny.Junction,Bitwarden";
          screenGapBottom = 5;
          screenGapLeft = 5;
          screenGapRight = 5;
          screenGapTop = 5;
          tileLayoutGap = 5;
        };
      };
      plasma-localerc.Formats = with config.home.language; {
        LC_ALL = base;

        LC_ADDRESS = address;
        LC_COLLATE = collate;
        LC_CTYPE = ctype;
        LC_MEASUREMENT = measurement;
        LC_MESSAGES = messages;
        LC_MONETARY = monetary;
        LC_NAME = name;
        LC_NUMERIC = numeric;
        LC_PAPER = paper;
        LC_TELEPHONE = telephone;
        LC_TIME = time;
      };
      plasma-localerc.Translations.LANGUAGE =
        (builtins.elemAt
          (pkgs.lib.strings.splitString "." config.home.language.base))
          0;
      plasmanotifyrc.Notifications.PopupPosition = "TopCenter";
    };
  };
}
