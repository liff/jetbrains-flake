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

, udev, pulseaudio

, expat, nspr, nss
, alsaLib, cups
, cairo, fontconfig, freetype, mesa
, atk, at-spi2-core, at-spi2-atk
, dbus, gdk-pixbuf, glib, gtk2, pango, gnome2
, libdrm, libxcb, libxkbcommon, libxshmfence
, libX11, libXcomposite, libXdamage
, libXext, libXfixes, libXi, libXrandr, libXrender
, libXScrnSaver, libXtst
}:

let

  version = "89.0.12+g2b76680+chromium-89.0.4389.90";

  extraRpath = lib.makeLibraryPath [ udev pulseaudio ];

  cefArchs = {
    "i686-linux" = "linux32";
    "x86_64-linux" = "linux64";
    "armv6l-linux" = "linuxarm";
    "armv7l-linux" = "linuxarm";
    "aarch64-linux" = "linuxarm64";
  };

  cefArch = cefArchs."${stdenv.hostPlatform.system}";

  cefSrcUrl = "https://cef-builds.spotifycdn.com/cef_binary_${version}_${cefArch}.tar.bz2";

  # Hashes from https://cef-builds.spotifycdn.com/index.html
  cefSrcHashes = {
    "linux32" = "sha1-P7aarOjYem0Pny21GeslJnFHdJ0=";
    "linux64" = "sha1-AwFqFKRbSLC0+7b5OzszG20A5RI=";
    "linuxarm" = "sha1-A+Wxu4UKljJbx+9dP6Bk0mopDaw=";
    "linuxarm64" = "sha1-icafFk/4tZ4ID6al7okPzazm6aQ=";
  };

  cefSrcHash = cefSrcHashes."${cefArch}";

  cefBinary = stdenv.mkDerivation {
    pname = "cef-binary";
    inherit version;

    src = fetchurl {
      url = cefSrcUrl;
      hash = cefSrcHash;
    };

    nativeBuildInputs = [ autoPatchelfHook wrapGAppsHook ];

    buildInputs = [
      expat nspr nss
      alsaLib cups
      cairo fontconfig freetype mesa
      atk at-spi2-core at-spi2-atk
      dbus gdk-pixbuf glib gtk2 pango gnome2.GConf gnome2.gtkglext
      libdrm libxcb libxkbcommon libxshmfence
      libX11 libXcomposite libXdamage
      libXext libXfixes libXi libXrandr libXrender
      libXScrnSaver libXtst
    ];

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      cp -va . "$out"
      runHook postInstall
    '';
  };

in

stdenv.mkDerivation {
  pname = "jetbrains-jcef";
  inherit version;

  src = fetchFromGitHub {
    owner = "JetBrains";
    repo = "jcef";
    rev = "4ccf29b795145e5b31df5e5de8cec04e4246fb65";
    sha256 = "sha256-MgqFaF7CCbUYDNTf30EN2Cq38VqIs9BzwWa5jk3Cvvw=";
    leaveDotGit = true;
  };

  nativeBuildInputs = [ which git pkg-config cmake python3 ];

  buildInputs = cefBinary.buildInputs ++ [ openjdk11 ant ];

  cmakeFlags = [
    "-DCEF_ROOT=${cefBinary}"
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  patches = [ ./dont-download-clang-format.patch ];

  preBuild = ''
    export JDK_11="$JAVA_HOME"
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
    bash compile.sh "${cefArch}" Release
    popd
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir "$out"
    pushd ..
    bash jb/tools/common/bundle_jogl_gluegen.sh
    cp -a jcef_build/native/Release/* "$out/"
    cp -a "$MODULAR_SDK_DIR" "$out/"
    popd
    runHook postInstall
  '';

  postFixup = ''
    patchelf --set-rpath "$(patchelf --print-rpath "$out/libcef.so"):${extraRpath}" "$out/libcef.so"
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
    platforms = builtins.attrNames cefArchs;
  };
}
