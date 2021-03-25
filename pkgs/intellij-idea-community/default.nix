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
latest = builtins.head jbPackages."IntelliJ IDEA".community.release.nojbr;

in

stdenv.mkDerivation rec {
  pname = "intellij-idea-community";
  version = latest.build.version;

  src = fetchurl {
    url = latest.downloadUri;
    sha256 = latest.sha256;
  };

  preferLocalBuild = true;
  dontStrip = true;
  
  nativeBuildInputs = [ makeWrapper patchelf unzip gnused autoPatchelfHook wrapGAppsHook copyDesktopItems ];

  buildInputs = [ stdenv.cc.cc.lib libdbusmenu lldb ];

  patches = [ ./launcher.patch ];

  postPatch = ''
    substituteInPlace bin/idea.sh \
      --subst-var-by UNAME               '${coreutils}/bin/uname' \
      --subst-var-by GREP                '${gnugrep}/bin/egrep' \
      --subst-var-by CUT                 '${coreutils}/bin/cut' \
      --subst-var-by READLINK            '${coreutils}/bin/readlink' \
      --subst-var-by XARGS               '${findutils}/bin/xargs' \
      --subst-var-by DIRNAME             '${coreutils}/bin/dirname' \
      --subst-var-by MKTEMP              '${coreutils}/bin/mktemp' \
      --subst-var-by RM                  '${coreutils}/bin/rm' \
      --subst-var-by CAT                 '${coreutils}/bin/cat' \
      --subst-var-by SED                 '${gnused}/bin/sed' \
      --subst-var-by NOTIFY_SEND         '${libnotify}/bin/notify-send' \
      --subst-var-by NATIVE_LIBRARY_PATH '${lib.makeLibraryPath [ libsecret libnotify e2fsprogs ]}'
  '';

  preFixup = ''
    gappsWrapperArgs+=(--set IDEA_JDK ${jetbrainsruntime.passthru.home})
  '';
  
  installPhase = ''
    mkdir -p $out/{lib/$pname,bin,share/pixmaps,libexec/$pname}
    cp -a . $out/lib/$pname/
    ln -s $out/lib/$pname/bin/idea.svg $out/share/pixmaps/$pname.svg
    ln -s $out/lib/$pname/bin/idea.png $out/share/pixmaps/$pname.png
    ln -s $out/lib/$pname/bin/idea.sh $out/bin/$pname

    runHook postInstall
  '';

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "IntelliJ IDEA Community Edition";
    genericName = "Integrated Development Environment";
    exec = pname;
    icon = pname;
    comment = lib.replaceChars ["\n"] [" "] meta.longDescription;
    categories = "Development;IDE;Java;";
    mimeType = "text/x-kotlin;text/x-java-source;text/x-scala;application/xml;application/json;";
    startupNotify = true;
  };

  desktopItems = [ desktopItem ];

  meta = with stdenv.lib; {
    homepage = "https://www.jetbrains.com/idea/";
    description = "Integrated Development Environment (IDE) by Jetbrains, community edition";
    longDescription = ''
      IDE for Java SE, Groovy & Scala development Powerful
      environment for building Google Android apps Integration
      with JUnit, TestNG, popular SCMs, Ant & Maven. Also known
      as IntelliJ.
    '';
    maintainers = with maintainers; [ liff ];
    license = stdenv.lib.licenses.asl20;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
