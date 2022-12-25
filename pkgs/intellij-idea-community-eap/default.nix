import ../intellij-idea/common.nix {
  choose = idea: idea.community.eap.default;
  pname = "intellij-idea-community-eap";
  desktopName = "IntelliJ IDEA Community Edition (EAP)";
  description = "Integrated Development Environment (IDE) by Jetbrains, community edition, EAP release";
  chooseLicense = licenses: licenses.asl20;
}
