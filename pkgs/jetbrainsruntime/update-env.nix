with import <nixpkgs> {};

let

  jbPackages = import ../../data/packages.nix;
  latest = builtins.head jbPackages."IntelliJ IDEA".community.release.default;

  intellij-idea-community-jbr = stdenv.mkDerivation {
    pname = "intellij-idea-community-jbr";
    version = latest.build.version;

    src = fetchurl {
      url = latest.downloadUri;
      sha256 = latest.sha256;
    };

    installPhase = ''
      runHook preInstall
      cp -a jbr $out
      runHook postInstall
    '';
  };

  bundled-jbr-java = buildFHSUserEnv {
    name = "bundled-jbr-java";

    targetPkgs = p: with p; [
      p.zlib
      intellij-idea-community-jbr
    ];

    runScript = "java";
  };

in stdenv.mkDerivation {
  name = "jbr-updater";

  buildInputs = [
    bundled-jbr-java
    (python3.withPackages(py: [py.nix-prefetch-github]))
  ];
}
