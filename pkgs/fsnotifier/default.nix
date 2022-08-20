{ stdenv
, fetchFromGitHub
, bash }:

let
  pname = "fsnotifier";
  jbPackages = import ../../data/packages.nix;
  latest = builtins.head jbPackages."IntelliJ IDEA".community.release.nojbr;
  version = "idea/${latest.build.fullNumber}";

in stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "JetBrains";
    repo = "intellij-community";
    sparseCheckout = "native/fsNotifier/linux";
    rev = version;
    hash = "sha256-W4BI0qRc79Qgz/6rKMFpfHhYZ209eJos9ncXHBJ8Xsc=";
  };

  nativeBuildInputs = [ bash ];

  buildPhase = ''
    pushd native/fsNotifier/linux
    $CC -O2 -Wall -Wextra -Wpedantic -D "VERSION=\"${version}\"" -std=c11 main.c inotify.c util.c -o fsnotifier
    popd
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp native/fsNotifier/linux/fsnotifier $out/bin
  '';
}
