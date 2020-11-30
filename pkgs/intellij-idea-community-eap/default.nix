{ lib
, fetchurl
, makeDesktopItem
, intellij-idea-community }:

intellij-idea-community.overrideAttrs (base: rec {
  pname = "intellij-idea-community-eap";
  version = "203.5981.114";

  src = fetchurl {
    url = "https://download.jetbrains.com/idea/ideaIC-${version}-no-jbr.tar.gz";
    sha256 = "sha256-vSGBv26ZMJKWXQhuOPf6/+3SsRwvle28Y3bhUnal6zo=";
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
