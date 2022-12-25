{ lib
, stdenv
, which
, bash
, gnused
, cmake
, git
, openjdk17
, python3
, ant
, fetchFromGitHub
, fetchurl
, unzip

, autoPatchelfHook, wrapGAppsHook
, pkg-config

, udev, pulseaudio, pciutils

, expat, nspr, nss
, alsa-lib, cups
, cairo, fontconfig, freetype, mesa
, atk, at-spi2-core, at-spi2-atk
, dbus, gdk-pixbuf, glib, gtk2, pango, gnome2
, libdrm, libxcb, libxkbcommon, libxshmfence
, libX11, libXcomposite, libXdamage
, libXext, libXfixes, libXi, libXrandr, libXrender
, libXScrnSaver, libXtst
}:

let

  version = "104.4.26+g4180781+chromium-104.0.5112.102";

  cefArchs = {
    "x86_64-linux" = "linux64";
    "aarch64-linux" = "linuxarm64";
  };

  cefArch = cefArchs."${stdenv.hostPlatform.system}";

  cefFilename = "cef_binary_${version}_${cefArch}_minimal";

  cefSrcUrl = "https://cef-builds.spotifycdn.com/${builtins.replaceStrings ["+"] ["%2B"] cefFilename}.tar.bz2";

  cefSrcHashes = {
    "linux64" = "sha256-G7FGPtwr48zAYQaB8/rEIOKxEIZmGFF1PMy1Toq6oQk=";
    "linuxarm64" = "sha256-/f/fqHxQouxr/sNpKF2Bojm3Pv4hdt2aQsKN4zS/CYw=";
  };

  cefSrcHash = cefSrcHashes."${cefArch}";

  cefSrc = fetchurl {
    url = cefSrcUrl;
    hash = cefSrcHash;
    name = "${cefFilename}.tar.bz2";
  };

  cefBuildInputs = [
    expat nspr nss
    alsa-lib cups
    cairo fontconfig freetype mesa
    atk at-spi2-core at-spi2-atk
    dbus gdk-pixbuf glib gtk2 pango gnome2.GConf gnome2.gtkglext
    libdrm libxcb libxkbcommon libxshmfence
    libX11 libXcomposite libXdamage
    libXext libXfixes libXi libXrandr libXrender
    libXScrnSaver libXtst
  ];

  extraRpath = lib.makeLibraryPath [ udev pulseaudio pciutils ];

  commitNumber = 541;

  jcefSrc = fetchFromGitHub {
    owner = "JetBrains";
    repo = "jcef";
    rev = "3aa075e8a0d0b81e841b51dcf3d5b83e43c54127";
    hash = "sha256-I8zrQds5M7OzOxe2GN4wNJX9C0x97ZiSWQpn/HAAEV4=";
    name = "jcef";
  };

in

stdenv.mkDerivation {
  pname = "jetbrains-jcef";
  inherit version;

  srcs = [ jcefSrc cefSrc ];
  sourceRoot = "jcef";

  unpackCmd = "test -f $curSrc && tar xf $curSrc";

  postUnpack = ''
    # Run patchelf on CEF because the linker needs to find the libraries
    # while building the CEF distribution.
    autoPatchelf ${cefFilename}
    mv ${cefFilename} jcef/third_party/cef/
  '';

  postPatch = ''
    substituteInPlace tools/make_version_header.py \
      --replace "raise Exception('Not a valid checkout')" "pass" \
      --replace "commit_number = git.get_commit_number(jcef_dir)" "commit_number = '${toString commitNumber}'" \
      --replace "commit_hash = git.get_hash(jcef_dir)" "commit_hash = '${jcefSrc.rev}'"
  '';

  nativeBuildInputs = [ autoPatchelfHook bash unzip which git pkg-config cmake python3 ];

  dontAutoPatchelf = true;

  buildInputs = cefBuildInputs ++ [ openjdk17 ant ];

  TARGET_ARCH = stdenv.hostPlatform.linuxArch;

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DPROJECT_ARCH=${stdenv.hostPlatform.linuxArch}"
  ];

  patches = [ ./dont-download-clang-format.patch ];

  preBuild = ''
    sed -ir "s#JCEF_ROOT_DIR=.*#JCEF_ROOT_DIR=$(cd .. && pwd)#" ../jb/tools/linux/set_env.sh
    . ../jb/tools/linux/set_env.sh
    export OUT_CLS_DIR="$JCEF_ROOT_DIR"/out/${cefArch}
    export PATCHED_LIBCEF_DIR=$JCEF_ROOT_DIR/third_party/cef/cef_binary_${version}_${cefArch}_minimal/Release
  '';

  buildPhase = ''
    runHook preBuild

    ln -s build ../jcef_build

    # build_native.sh
    make -j$NIX_BUILD_CORES

    # build_java.sh
    bash "$JCEF_ROOT_DIR"/tools/compile.sh "${cefArch}" Release

    # create_bundle.sh
    bash "$JB_TOOLS_DIR"/common/create_modules.sh

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir "$out" "$out/lib"
    pushd ..
    mv -v jmods "$out/"
    mv -v jcef_build/native/Release/* "$out/lib/"
    popd

    runHook postInstall
  '';

  postFixup = ''
    patchelf --set-rpath "$(patchelf --print-rpath "$out/lib/libcef.so"):${extraRpath}" "$out/lib/libcef.so"
    patchelf --set-rpath "$(patchelf --print-rpath "$out/lib/jcef_helper"):${extraRpath}" "$out/lib/jcef_helper"
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
