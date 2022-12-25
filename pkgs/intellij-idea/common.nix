{ choose
, pname
, desktopName
, description
, chooseLicense
, }:

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
, pam
, graphviz
, wrapGAppsHook
, autoPatchelfHook
, jetbrainsruntime
, fsnotifier }:

let

  jbPackages = import ../../data/packages.nix;
  latest = builtins.head (choose jbPackages."IntelliJ IDEA");

in

stdenv.mkDerivation rec {
  inherit pname;
  version = builtins.replaceStrings [" "] ["+"] latest.build.version;

  src = fetchurl {
    url = latest.downloadUri;
    sha256 = latest.sha256;
  };

  postUnpack = ''
    pushd idea-*
    rm -fr jbr
    grep -Ev '^\s+"javaExecutablePath":' product-info.json > product-info.json.new
    mv product-info.json.new product-info.json
    popd
  '';

  dontStrip = true;

  nativeBuildInputs = [ makeWrapper patchelf unzip gnused autoPatchelfHook wrapGAppsHook copyDesktopItems ];

  buildInputs = [ stdenv.cc.cc.lib libdbusmenu lldb pam ];

  patches = [ ./launcher.patch ];

  postPatch = ''
    substituteInPlace bin/idea.sh \
      --subst-var-by PATH                '${lib.makeBinPath [ coreutils gnugrep graphviz ]}' \
      --subst-var-by NOTIFY_SEND         '${libnotify}/bin/notify-send' \
      --subst-var-by NATIVE_LIBRARY_PATH '${lib.makeLibraryPath [ libsecret libnotify e2fsprogs ]}'
  '';

  preFixup = ''
    gappsWrapperArgs+=(--set IDEA_JDK ${jetbrainsruntime.passthru.home})
  '';

  installPhase = ''
    mkdir -p $out/{lib/$pname,bin,share/pixmaps,libexec/$pname}

    rm -rf plugins/maven/lib/maven3/lib/jansi-native/{linux32,freebsd32,freebsd64}
    rm -f plugins/performanceTesting/bin/libyjpagent.so # 32-bit x86
    rm -f plugins/webp/lib/libwebp/linux/libwebp_jni.so # 32-bit x86
    rm -rf lib/pty4j-native/linux/{arm,mips64el,ppc64le,x86}
    rm -f plugins/tailwindcss/server/node.napi.musl-*.node # TODO: avoid this

    cp -a . $out/lib/$pname/
    ln -s $out/lib/$pname/bin/idea.svg $out/share/pixmaps/$pname.svg
    ln -s $out/lib/$pname/bin/idea.png $out/share/pixmaps/$pname.png
    ln -s $out/lib/$pname/bin/idea.sh $out/bin/$pname
    ln -sf ${fsnotifier}/bin/fsnotifier $out/lib/$pname/bin

    runHook postInstall
  '';

  desktopItem = makeDesktopItem {
    name = pname;
    inherit desktopName;
    genericName = "Integrated Development Environment";
    exec = pname;
    icon = pname;
    comment = lib.replaceStrings ["\n"] [" "] meta.longDescription;
    categories = [ "Development" "IDE" "Java" ];
    mimeTypes = [ "text/x-kotlin" "text/x-java-source" "text/x-scala" "application/xml" "application/json" ];
    startupNotify = true;
    startupWMClass = "jetbrains-idea";
  };

  desktopItems = [ desktopItem ];

  meta = with lib; {
    homepage = "https://www.jetbrains.com/idea/";
    inherit description;
    longDescription = ''
      IDE for Java SE, Groovy & Scala development Powerful
      environment for building Google Android apps Integration
      with JUnit, TestNG, popular SCMs, Ant & Maven. Also known
      as IntelliJ.
    '';
    maintainers = with maintainers; [ liff ];
    license = chooseLicense lib.licenses;
    platforms = jetbrainsruntime.meta.platforms;
  };
}
