{
  description = "Package version updater for JetBrains flake";

  inputs = {
    sbt-derivation.url = "github:zaninime/sbt-derivation";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, sbt-derivation, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        sbt11 = final: prev: { sbt = prev.sbt.override { jre = final.jdk11; }; };

        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            sbt11
            sbt-derivation.overlay
          ];
        };
      in rec {

        packages = flake-utils.lib.flattenTree {
          jetbrains-updater = pkgs.sbt.mkDerivation {
            pname = "jetbrains-updater";
            version = "1";

            depsSha256 = "sha256-6WdVa4z2uvJ01IRYSZTzqX0T02aqrjYoywUJ6zk7zkQ=";

            src = ./.;

            NATIVE_IMAGE_INSTALLED = "true";
            GRAALVM_HOME = pkgs.graalvm11-ce;

            buildPhase = ''
              runHook preBuild
              sbt nativeImage
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp target/native-image/jetbrains-updater $out/bin
              runHook postInstall
            '';
          };
        };

        defaultPackage = packages.jetbrains-updater;

        apps.jetbrains-updater = flake-utils.lib.mkApp { drv = packages.jetbrains-updater; };

        defaultApp = apps.jetbrains-updater;
      }
    );
}
