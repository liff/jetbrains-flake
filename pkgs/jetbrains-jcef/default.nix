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
, unzip

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

  version = "89.1.10+g0fc388a+chromium-89.0.4389.114";

  cefArchs = {
    "x86_64-linux" = "linux64";
  };

  cefArch = cefArchs."${stdenv.hostPlatform.system}";

  cefFilename = "cef_binary_${version}_${cefArch}_minimal";

  cefSrcUrl = "https://cache-redirector.jetbrains.com/intellij-jbr/${builtins.replaceStrings ["+"] ["%2B"] cefFilename}.zip";

  cefSrcHashes = {
    "linux64" = "sha256-d9ISyhEQBWsL5qdHfo1FqOPw7hlZ/9Zb1HUpoW2cK30=";
  };

  cefSrcHash = cefSrcHashes."${cefArch}";

  cefSrc = fetchurl {
    url = cefSrcUrl;
    hash = cefSrcHash;
    name = "${cefFilename}.zip";
  };

  cefBuildInputs = [
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

  extraRpath = lib.makeLibraryPath [ udev pulseaudio ];

  jcefSrc = fetchFromGitHub {
    owner = "JetBrains";
    repo = "jcef";
    rev = "e6e523582e66ecf226fcc6a1d163102892e88752";
    sha256 = "sha256-2GttXEUYHKjK0FnKpWhZx4KXzpxtI8z3mFGjcvlpFto=";
    leaveDotGit = true;
    name = "jcef";
  };

in

stdenv.mkDerivation {
  pname = "jetbrains-jcef";
  inherit version;

  srcs = [ jcefSrc cefSrc ];
  sourceRoot = "jcef";

  unpackCmd = "unzip $curSrc";

  postUnpack = ''
    # Run patchelf on CEF because the linker needs to find the libraries
    # while building the CEF distribution.
    autoPatchelf ${cefFilename}
    mv ${cefFilename} jcef/third_party/cef/
  '';

  nativeBuildInputs = [ autoPatchelfHook unzip which git pkg-config cmake python3 ];

  dontAutoPatchelf = true;

  buildInputs = cefBuildInputs ++ [ openjdk11 ant ];

  cmakeFlags = [
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
