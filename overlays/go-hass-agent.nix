{ inputs, lib, ... }:

final: prev: {
  go-hass-agent =
    let
      gh-owner = "joshuar";
      gh-repo = "go-hass-agent";
      version = "14.9.0";

      src = prev.fetchFromGitHub {
        owner = "joshuar";
        repo = "go-hass-agent";
        tag = "v${version}";
        hash = "sha256-vY2a4nSjRzs3QahPXgKIe1YGzp7FRMxscsCP9VH9fYg=";
      };

      nodeAssets = prev.buildNpmPackage {
        pname = "go-hass-agent-assets";
        inherit src version;

        npmDepsHash = "sha256-rScsGZMdyd8chY380MxZEA6OkwqkH46LlvjCTBOohfE=";
        buildPhase = ''
          runHook preBuild
          npm run build:js
          npm run build:css
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -r web $out/
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

      vendorHash = "sha256-Lbctnz/YV8taCHpJG9XnheT0W4mVxDlewb/nTP5WnHU=";

      preBuild = ''
        cp -r ${nodeAssets}/web .
      '';

      ldflags = [
        "-w"
        "-s"
        "-X github.com/joshuar/go-hass-agent/config.AppVersion=${version}-nixpkgs"
      ];

      meta = {
        description = "A Home Assistant, native app for desktop/laptop devices.";
        homepage = "https://github.com/${gh-owner}/${gh-repo}";
        changelog = "https://github.com/joshuar/go-hass-agent/releases/tag/v${version}";
        license = lib.licenses.mit;
        mainProgram = "go-hass-agent";
        platforms = lib.platforms.linux;
      };
    };
}
