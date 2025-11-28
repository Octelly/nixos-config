{ inputs, lib, ... }:

final: prev: {
  go-hass-agent =
    let
      gh-owner = "joshuar";
      gh-repo = "go-hass-agent";
      version = "14.1.1";

      src = prev.fetchFromGitHub {
        owner = "joshuar";
        repo = "go-hass-agent";
        rev = "refs/tags/v${version}";
        hash = "sha256-kWrMBbSbq5DoQZdy/OgL7p9iOSNiCFn0lcZCOKihaVo=";
      };

      frontend-node_modules = prev.stdenv.mkDerivation {
        pname = "go-hass-agent-frontend-node_modules";
        inherit src version;
        impureEnvVars = lib.fetchers.proxyImpureEnvVars
          ++ [ "GIT_PROXY_COMMAND" "SOCKS_SERVER" ];
        nativeBuildInputs = [ prev.bun ];
        dontConfigure = true;
        buildPhase = ''
          bun install --no-progress --frozen-lockfile
        '';

        # NOTE: based on
        # https://github.com/NixOS/nixpkgs/blob/804c952399902e210ca8a0505ddc18e1eb34f17a/pkgs/by-name/he/helix-gpt/package.nix
        # had to add removal of cache to get rid of broken symlinks
        installPhase = ''
          mkdir -p $out/node_modules

          cp -R ./node_modules $out

          rm -rf $out/node_modules/.cache
        '';
        outputHash = "sha256-83l2P4uYfFuQng4s5lBzYgOqaRlrlQTD1zpR7GLUDm4=";
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
      };

      frontend = prev.stdenv.mkDerivation {
        pname = "go-hass-agent-frontend";
        inherit version src;

        nativeBuildInputs = [ prev.bun prev.tailwindcss_4 ];

        dontConfigure = true;

        LD_LIBRARY_PATH = "${lib.makeLibraryPath [prev.stdenv.cc.cc]}";

        buildPhase = ''
          runHook preBuild

          ln -s ${frontend-node_modules}/node_modules .

          bun run build:js
          tailwindcss -i ./web/assets/styles.css -o ./web/content/styles.css --minify --map

          # bun run build:css
          # this just returns 1 and doesn't do anything

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out
          cp -r web/content/* $out/

          runHook postInstall
        '';
      };
    in
    prev.buildGoModule rec {
      inherit version src;
      pname = gh-repo;

      desktopItems = [
        (prev.makeDesktopItem {
          # https://github.com/joshuar/go-hass-agent/blob/main/assets/go-hass-agent.desktop
          name = "Start Go Hass Agent";
          desktopName = "Start Go Hass Agent";
          comment = meta.description;
          icon = pname;
          exec = "${meta.mainProgram} run";
          terminal = false;
          categories = [ "System" "Monitor" ];
          startupNotify = true;
          keywords = [ "home" "assistant" "hass" ];
        })
      ];

      vendorHash = "sha256-VRjL4p1UIvWrXOI++cgxVpFhNCE49KTNMwOCrWKtruQ=";

      preBuild = ''
        cp -r ${frontend}/* web/content/
      '';

      ldflags = [
        "-s"
        "-w"
        "-X github.com/joshuar/go-hass-agent/config.AppVersion=${version}"
      ];

      meta = {
        description = "A Home Assistant, native app for desktop/laptop devices.";
        homepage = "https://github.com/${gh-owner}/${gh-repo}";
        changelog = "https://github.com/joshuar/go-hass-agent/blob/${src.rev}/CHANGELOG.md";
        license = lib.licenses.mit;
        mainProgram = "go-hass-agent";
        platforms = lib.platforms.linux;
      };
    };
}
