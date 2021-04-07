{ lib
, stdenv
, fetchurl
, patchelf
, makeWrapper
, makeDesktopItem
, copyDesktopItems
, coreutils
, findutils
, unzip
, gnused
, gnugrep
, libsecret
, libnotify
, libdbusmenu
, lldb
, e2fsprogs
, wrapGAppsHook
, autoPatchelfHook
, jetbrainsruntime }:

let

jbPackages = import ../../data/packages.nix;
latest = builtins.head jbPackages."IntelliJ IDEA".licensed.release.nojbr;

in

stdenv.mkDerivation rec {
  pname = "intellij-idea-ultimate";
  version = latest.build.version;

  src = fetchurl {
    url = latest.downloadUri;
    sha256 = latest.sha256;
  };

  dontStrip = true;
  preferLocalBuild = true;
  
  nativeBuildInputs = [ makeWrapper patchelf unzip gnused autoPatchelfHook wrapGAppsHook copyDesktopItems ];

  buildInputs = [ stdenv.cc.cc.lib libdbusmenu lldb ];

  patches = [ ./launcher.patch ];

  postPatch = ''
    substituteInPlace bin/idea.sh \
      --subst-var-by PATH                '${lib.makeBinPath [ coreutils gnugrep ]}' \
      --subst-var-by NOTIFY_SEND         '${libnotify}/bin/notify-send' \
      --subst-var-by NATIVE_LIBRARY_PATH '${lib.makeLibraryPath [ libsecret libnotify e2fsprogs ]}'
  '';

  preFixup = ''
    gappsWrapperArgs+=(--set IDEA_JDK ${jetbrainsruntime.passthru.home})
  '';
  
  installPhase = ''
    mkdir -p $out/{lib/$pname,bin,share/pixmaps,libexec/$pname}
    rm -rf plugins/maven/lib/maven3/lib/jansi-native/{linux32,freebsd32,freebsd64}
    rm -rf plugins/performanceTesting/bin/libyjpagent.so
    rm -rf plugins/webp/lib/libwebp/linux/libwebp_jni.so
    rm bin/fsnotifier
    rm -rf lib/pty4j-native/linux/{aarch64,mips64el,ppc64le,x86}
    cp -a . $out/lib/$pname/
    ln -s $out/lib/$pname/bin/idea.svg $out/share/pixmaps/$pname.svg
    ln -s $out/lib/$pname/bin/idea.png $out/share/pixmaps/$pname.png
    ln -s $out/lib/$pname/bin/idea.sh $out/bin/$pname

    runHook postInstall
  '';

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "IntelliJ IDEA Ultimate Edition";
    genericName = "Integrated Development Environment";
    exec = pname;
    icon = pname;
    comment = lib.replaceChars ["\n"] [" "] meta.longDescription;
    categories = "Development;IDE;Java;";
    mimeType = "text/x-kotlin;text/x-java-source;text/x-scala;application/xml;application/json;";
    startupNotify = true;
  };

  desktopItems = [ desktopItem ];

  meta = with lib; {
    homepage = "https://www.jetbrains.com/idea/";
    description = "Integrated Development Environment (IDE) by Jetbrains, ultimate edition";
    longDescription = ''
      IDE for Java SE, Groovy & Scala development Powerful
      environment for building Google Android apps Integration
      with JUnit, TestNG, popular SCMs, Ant & Maven. Also known
      as IntelliJ.
    '';
    maintainers = with maintainers; [ liff ];
    license = lib.licenses.unfree;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
