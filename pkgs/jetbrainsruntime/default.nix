{ lib
, harfbuzz
, openjdk11
, openjdk11-bootstrap
, fetchFromGitHub
, jetbrainsruntime
, jetbrains-jcef
, xdg ? true
}:

let
  inherit (import ../../data/jetbrainsruntime.nix)
    jdkVersion jdkBuildNumber buildNumber subBuildNumber bundleType hash tag;

  vendorName = "JetBrains s.r.o.";
  vendorVersionString = "JBR-${jdkVersion}.${jdkBuildNumber}-${buildNumber}.${subBuildNumber}-${bundleType}";
  version = "${jdkVersion}-b${buildNumber}.${subBuildNumber}";

in

openjdk11.overrideAttrs (oldAttrs: {
  pname = "jetbrainsruntime";
  inherit version;

  src = fetchFromGitHub {
    owner = "JetBrains";
    repo = "JetBrainsRuntime";
    rev = tag;
    inherit hash;
  };

  patches = (oldAttrs.patches or []) ++ (if xdg then [ ./xdg.patch ] else []);

  buildInputs = (oldAttrs.buildInputs or []) ++ [ harfbuzz ];

  configureFlags = [
    "--with-boot-jdk=${openjdk11-bootstrap.home}"
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
    "--with-import-modules=./modular-sdk"
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
                  for patch in jb/project/tools/patches/dcevm/*.patch; do patch -p0 < $patch; done
                 '' else "")
              + ''
                  patch -p0 < jb/project/tools/patches/add_jcef_module.patch
                  cp -R "${jetbrains-jcef}/modular-sdk" .
                  find modular-sdk -print0 | xargs -0 chmod +w
                '';

  postInstall = (oldAttrs.preInstall or "") + ''
    for f in ${jetbrains-jcef}/*; do
      if [[ ! -e $out/lib/openjdk/lib/$(basename $f) ]]; then
        ln -vs $f $out/lib/openjdk/lib/
      fi
    done
    rm $out/lib/openjdk/lib/modular-sdk
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
