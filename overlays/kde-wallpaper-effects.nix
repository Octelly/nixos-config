{ inputs, lib, ... }:

final: prev: {
  plasma-wallpaper-effects = prev.stdenv.mkDerivation rec {
    pname = "plasma-wallpaper-effects";
    version = "2.1.1";

    src = prev.fetchFromGitHub {
      owner = "luisbocanegra";
      repo = "plasma-wallpaper-effects";
      rev = "v${version}";
      hash = "sha256-KXTAG5D3nPrL5t2HkOGPPS1/WC4hf1E4p+l9LqSE8yo=";
    };

    nativeBuildInputs = with prev; [
      cmake
      kdePackages.extra-cmake-modules
      kdePackages.wrapQtAppsHook
    ];

    buildInputs = with prev.kdePackages; [
      libplasma
      plasma5support
    ];

    meta = {
      description = "KDE Plasma Widget to enable Active Blur and other effects for all Wallpaper Plugins";
      homepage = "https://github.com/luisbocanegra/plasma-wallpaper-effects";
      platforms = lib.platforms.linux;
      license = with lib.licenses; [
        gpl3Only
      ];
    };
  };
}
