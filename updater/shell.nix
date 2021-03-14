with import <nixpkgs> { };

pkgs.mkShell rec {
  name = "jetbrains-updater";

  buildInputs = [
    gitAndTools.git-crypt
    (sbt.override { jre = jdk11; })
    nodejs
    graalvm11-ce
  ];

  shellHook = ''
    export NATIVE_IMAGE_INSTALLED=true
    export GRAALVM_HOME=${graalvm11-ce}
  '';
}
