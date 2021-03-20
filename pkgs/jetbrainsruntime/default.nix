{ stdenv
, openjdk11
, fetchFromGitHub
, jetbrainsruntime
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

  preConfigure = (oldAttrs.preConfigure or "") + ''
    configureFlagsArray+=(
      --with-vendor-name="${vendorName}"
      --with-vendor-version-string="${vendorVersionString}"
      --with-version-pre=
      --with-version-build="${jdkBuildNumber}"
      --with-version-opt="${buildNumber}"
      --enable-cds=yes
    )
  '';

  postPatch = (oldAttrs.postPatch or "") + (if bundleType == "jcef" then ''
    patch -p0 < jb/project/tools/patches/add_jcef_module.patch
  '' else "");

  meta = with stdenv.lib; {
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
    homepage = "https://bintray.com/jetbrains/intellij-jdk/";
    license = licenses.gpl2;
    maintainers = with maintainers; [ edwtjo petabyteboy ];
    platforms = [ "i686-linux" "x86_64-linux" "aarch64-linux" "armv7l-linux" "armv6l-linux" ];
  };

  passthru = oldAttrs.passthru // {
    home = "${jetbrainsruntime}/lib/openjdk";
  };
})
