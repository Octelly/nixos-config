{ inputs, ... }:

final: prev:
{
  # https://github.com/Megumori/MeguOS/blob/4338a7bbf7f2fa701dda63b5290e4eb0a7f7629c/hosts/MeguPC/commonUsers/megumori/home/retroarch/default.nix
  melonds-ds = prev.stdenv.mkDerivation (old: rec {
    pname = "libretro-melonds-ds";
    version = "1.2.0";

    src = prev.fetchurl {
      url = "https://github.com/JesseTG/melonds-ds/releases/download/v${version}/melondsds_libretro-linux-x86_64-Release.zip";
      hash = "sha256-m3we8Iqe09GmG+OYHPQDMsiM4/Wcp2M2JicBsn2r2ys=";
    };

    nativeBuildInputs = [ prev.unzip ];
    sourceRoot = "melondsds_libretro-linux-x86_64-Release";

    installPhase = ''
      mkdir -p $out/lib/retroarch/cores
      cp cores/melondsds_libretro.so $out/lib/retroarch/cores
      #cp cores/melondsds_libretro.info $out/lib/retroarch/cores
      
      patchelf --set-rpath "${prev.lib.makeLibraryPath [ prev.libGL prev.stdenv.cc.cc ]}" \
        $out/lib/retroarch/cores/melondsds_libretro.so
    '';

    passthru = {
      libretroCore = "/lib/retroarch/cores";
    };
  });
}
