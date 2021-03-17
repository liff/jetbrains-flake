{ lib
, fetchurl
, makeDesktopItem
, intellij-idea-community }:

let

jbPackages = import ../../data/packages.nix;
latest = builtins.head jbPackages."IntelliJ IDEA".community.eap.nojbr;

in

intellij-idea-community.overrideAttrs (base: rec {
  pname = "intellij-idea-community-eap";
  version = latest.build.version;

  src = fetchurl {
    url = latest.downloadUri;
    sha256 = latest.sha256;
  };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "IntelliJ IDEA Community Edition (EAP)";
    genericName = "Integrated Development Environment";
    exec = pname;
    icon = pname;
    comment = lib.replaceChars ["\n"] [" "] meta.longDescription;
    categories = "Development;IDE;Java;";
    mimeType = "text/x-kotlin;text/x-java-source;text/x-scala;application/xml;application/json;";
    startupNotify = true;
  };

  desktopItems = [ desktopItem ];

  meta = base.meta // {
    description = "Integrated Development Environment (IDE) by Jetbrains, community edition, EAP release";
  };
})
