{ lib
, stdenv
, which
, cmake
, git
, openjdk11
, python3
, ant
, fetchFromGitHub
, fetchurl

, autoPatchelfHook, wrapGAppsHook
, pkg-config

, expat, nspr, nss
, alsaLib, cups
, cairo, fontconfig, freetype, mesa
, atk, at-spi2-core, at-spi2-atk
, dbus, gdk-pixbuf, glib, gtk2, pango, gnome2
, libdrm, libxcb, libxkbcommon
, libX11, libXcomposite, libXdamage
, libXext, libXfixes, libXi, libXrandr, libXrender
, libXScrnSaver, libXtst
}:

let

  version = "87.1.13+g481a82a+chromium-87.0.4280.141";

  cef-binary = stdenv.mkDerivation {
    pname = "cef-binary";
    inherit version;

    src = fetchurl {
      url = "https://cef-builds.spotifycdn.com/cef_binary_${version}_linux64.tar.bz2";
      hash = "sha256-DFwiViZeiQB5beEA8MKAbCSmHtPdnoHdzdj+Br9T6gI=";
    };

    nativeBuildInputs = [ autoPatchelfHook wrapGAppsHook ];

    buildInputs = [
      expat nspr nss
      alsaLib cups
      cairo fontconfig freetype mesa
      atk at-spi2-core at-spi2-atk
      dbus gdk-pixbuf glib gtk2 pango gnome2.GConf gnome2.gtkglext
      libdrm libxcb libxkbcommon
      libX11 libXcomposite libXdamage
      libXext libXfixes libXi libXrandr libXrender
      libXScrnSaver libXtst
    ];

    buildPhase = ''
      runHook preBuild
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -va . "$out"
      runHook postInstall
    '';
  };

in

stdenv.mkDerivation {
  pname = "javajetbrains-jcef";
  inherit version;

  src = fetchFromGitHub {
    owner = "JetBrains";
    repo = "jcef";
    rev = "6e47691a69c63bab726f6013cf58d44a19491c03";
    sha256 = "E+YngUOIeaqiQ6/TUiWQunhDxAVWeYtUQOr02peUVg0=";
    leaveDotGit = true;
  };

  nativeBuildInputs = [ which git pkg-config cmake python3 ];

  buildInputs = cef-binary.buildInputs ++ [ openjdk11 ant ];

  cmakeFlags = [
    "-DCEF_ROOT=${cef-binary}"
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  patches = [ ./dont-download-clang-format.patch ];

  preBuild = ''
    export JDK_11=$JAVA_HOME
    pushd ../jb/tools/linux
    . ./set_env.sh
    popd
  '';

  buildPhase = ''
    runHook preBuild
    ln -s build ../jcef_build
    pushd ../jb/tools
    ./modular-jogl.sh
    popd
    make -j$NIX_BUILD_CORES
    pushd ../tools
    bash compile.sh linux64 Release
    popd
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir $out
    pushd ..
    bash jb/tools/common/bundle_jogl_gluegen.sh
    cp -a jcef_build/native/Release/* $out/
    cp -a "$MODULAR_SDK_DIR" $out/
    popd
    runHook postInstall
  '';

  meta = with lib; {
    description = "The Java Chromium Embedded Framework.";
    longDescription = ''
     The Java Chromium Embedded Framework (JCEF) is a simple framework for
     embedding Chromium-based browsers in other applications using the
     Java programming language.

     This is JetBrains’ modified version of JCEF.
    '';
    homepage = "https://github.com/JetBrains/jcef";
    license = licenses.bsd3;
    maintainers = with maintainers; [ liff ];
    platforms = [ "i686-linux" "x86_64-linux" "aarch64-linux" "armv7l-linux" "armv6l-linux" ];
  };
}
