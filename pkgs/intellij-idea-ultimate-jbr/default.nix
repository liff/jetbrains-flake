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

, udev, pulseaudio, pciutils

, harfbuzz

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

jbPackages = import ../../data/packages.nix;
latest = builtins.head jbPackages."IntelliJ IDEA".licensed.release.default;

in

stdenv.mkDerivation rec {
  pname = "intellij-idea-ultimate-jbr";
  version = builtins.replaceStrings [" "] ["+"] latest.build.version;

  src = fetchurl {
    url = latest.downloadUri;
    sha256 = latest.sha256;
  };

  dontStrip = true;

  nativeBuildInputs = [ makeWrapper patchelf unzip gnused autoPatchelfHook wrapGAppsHook copyDesktopItems ];

  buildInputs = [
    expat nspr nss
    alsa-lib cups
    cairo fontconfig freetype mesa
    atk at-spi2-core at-spi2-atk
    dbus gdk-pixbuf glib gtk2 pango gnome2.GConf gnome2.gtkglext
    libdrm libxcb libxkbcommon libxshmfence
    libX11 libXcomposite libXdamage
    libXext libXfixes libXi libXrandr libXrender
    libXScrnSaver libXtst

    harfbuzz

    stdenv.cc.cc.lib libdbusmenu lldb pam
  ];

  runtimeDependencies = [ udev pulseaudio fontconfig pciutils ];

  patches = [ ../intellij-idea/launcher.patch ];

  postPatch = ''
    substituteInPlace bin/idea.sh \
      --subst-var-by PATH                '${lib.makeBinPath [ coreutils gnugrep graphviz ]}' \
      --subst-var-by NOTIFY_SEND         '${libnotify}/bin/notify-send' \
      --subst-var-by NATIVE_LIBRARY_PATH '${lib.makeLibraryPath [ libsecret libnotify e2fsprogs ]}'
  '';

  installPhase = ''
    mkdir -p $out/{lib/$pname,bin,share/pixmaps,libexec/$pname}

    rm -rf plugins/maven/lib/maven3/lib/jansi-native/{linux32,freebsd32,freebsd64}
    rm -f plugins/performanceTesting/bin/libyjpagent.so # 32-bit
    rm -f plugins/webp/lib/libwebp/linux/libwebp_jni.so # 32-bit
    rm -rf lib/pty4j-native/linux/{aarch64,arm,mips64el,ppc64le,x86}

    cp -a . $out/lib/$pname/
    ln -s $out/lib/$pname/bin/idea.svg $out/share/pixmaps/$pname.svg
    ln -s $out/lib/$pname/bin/idea.png $out/share/pixmaps/$pname.png
    ln -s $out/lib/$pname/bin/idea.sh $out/bin/$pname

    runHook postInstall
  '';

  dontAutoPatchelf = true;

  postFixup = ''
    autoPatchelf "$out"

    runtime_rpath="${lib.makeLibraryPath runtimeDependencies}"

    for so in $(find "$out/lib/$pname" -name '*.so'); do
      so_rpath="$(patchelf --print-rpath "$so")"
      echo "Adding runtime dependencies to RPATH of library $so"
      patchelf --set-rpath "\$ORIGIN:$runtime_rpath:$so_rpath" "$so"
    done
  '';

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "IntelliJ IDEA Ultimate Edition (JBR)";
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
    description = "Integrated Development Environment (IDE) by Jetbrains, ultimate edition (JBR bundled)";
    longDescription = ''
      IDE for Java SE, Groovy & Scala development Powerful
      environment for building Google Android apps Integration
      with JUnit, TestNG, popular SCMs, Ant & Maven. Also known
      as IntelliJ.
    '';
    maintainers = with maintainers; [ liff ];
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
