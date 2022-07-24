{ lib
, stdenv
, harfbuzz
, openjdk17
, openjdk17-bootstrap
, gnused
, fetchFromGitHub
, jetbrainsruntime
, jetbrains-jcef
, xdg ? true
, useSystemHarfbuzz ? false
}:

let
  inherit (import ../../data/jetbrainsruntime.nix)
    jdkVersion jdkBuildNumber buildNumber subBuildNumber bundleType hash tag;

  vendorName = "JetBrains s.r.o.";
  vendorVersionString = "JBR-${jdkVersion}+${jdkBuildNumber}-${buildNumber}.${subBuildNumber}-${bundleType}";
  version = "${jdkVersion}-b${buildNumber}.${subBuildNumber}";

in

openjdk17.overrideAttrs (oldAttrs: {
  pname = "jetbrainsruntime";
  inherit version;

  src = fetchFromGitHub {
    owner = "JetBrains";
    repo = "JetBrainsRuntime";
    rev = tag;
    inherit hash;
  };

  patches = (oldAttrs.patches ++ (if xdg then [ ./xdg.patch ] else []));

  buildInputs = (oldAttrs.buildInputs or []) ++ (if useSystemHarfbuzz then [ harfbuzz ] else []);

  configureFlags = [
    "--with-boot-jdk=${openjdk17-bootstrap.home}"
    "--enable-unlimited-crypto"
    "--with-native-debug-symbols=internal"
    "--with-libjpeg=system"
    "--with-giflib=system"
    "--with-libpng=system"
    "--with-zlib=system"
    "--with-lcms=system"
    "--with-stdc++lib=dynamic"
    "--with-jvm-features=shenandoahgc"
    "--enable-cds=yes"
    "--with-version-pre="
    "--with-version-build=${jdkBuildNumber}"
    "--with-version-opt=${buildNumber}"
    "--with-vendor-version-string=${vendorVersionString}"
  ];

  preConfigure = (oldAttrs.preConfigure or "") + ''
    configureFlagsArray+=(
      --with-vendor-name="${vendorName}"
    )
  '';

  postPatch = (oldAttrs.postPatch or "")
              + (if bundleType == "dcevm" then ''
                  for patch in jb/project/tools/patches/dcevm/*.patch; do patch -p1 < $patch; done
                 '' else "")
              + ''
    sed -ir \
      -e 's/^OPENJDK_TAG=.*$/OPENJDK_TAG=jbr-${jdkVersion}+${jdkBuildNumber}/' \
      -e 's/^SOURCE_DATE_EPOCH=.*$/SOURCE_DATE_EPOCH=1658217911/' \
      jb/project/tools/common/scripts/common.sh
  '';

  JCEF_PATH = jetbrains-jcef;

  RELEASE_NAME = "linux-${stdenv.targetPlatform.linuxArch}-server-release";

  postBuild = (oldAttrs.postBuild or "") + ''
    patch -p0 < jb/project/tools/patches/add_jcef_module.patch
    bash -c "
      set -euo pipefail
      . jb/project/tools/common/scripts/common.sh ignore ignore
      IMAGES_DIR=build/\$RELEASE_NAME/images
      JSDK=\$IMAGES_DIR/jdk
      JSDK_MODS_DIR=\$IMAGES_DIR/jmods
      update_jsdk_mods \$JSDK ${jetbrains-jcef}/jmods \$JSDK/jmods \$JSDK_MODS_DIR
    "
  '';

  installPhase = ''
    runHook preInstall
  '' + (oldAttrs.installPhase or "") + ''
    runHook postInstall
  '';

  meta = with lib; {
    description = "An OpenJDK fork to better support Jetbrains's products.";
    longDescription = ''
     JetBrains Runtime is a runtime environment for running IntelliJ Platform
     based products on Windows, Mac OS X, and Linux. JetBrains Runtime is
     based on OpenJDK project with some modifications. These modifications
     include: Subpixel Anti-Aliasing, enhanced font rendering on Linux, HiDPI
     support, ligatures, some fixes for native crashes not presented in
     official build, and other small enhancements.

     JetBrains Runtime is not a certified build of OpenJDK. Please, use at
     your own risk.
    '';
    homepage = "https://github.com/JetBrains/JetBrainsRuntime";
    license = licenses.gpl2;
    maintainers = with maintainers; [ liff ];
    platforms = jetbrains-jcef.meta.platforms;
  };

  passthru = oldAttrs.passthru // {
    home = "${jetbrainsruntime}/lib/openjdk";
  };
})
