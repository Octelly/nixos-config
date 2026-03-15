{ inputs, ... }:

final: prev:
{
  feishin = prev.feishin.overrideAttrs (old: rec {
    version = "1.8.0";
    pname = "feishin";

    src = prev.fetchFromGitHub {
      owner = "jeffvli";
      repo = "feishin";
      tag = "v${version}";
      hash = "sha256-sd6j3gPtNFN1hMiOMIiTICNH8mYJvO9FSXPqUFotis8=";
    };

    pnpmDeps = prev.fetchPnpmDeps {
      inherit
        pname
        version
        src
        ;
      pnpm = prev.pnpm_10;
      fetcherVersion = 3;
      hash = "sha256-XhBcZRa66QdkjXxbefzsBUdvPIEshorq1uqzoWMXuTc=";
    };

  });
}
