import ../intellij-idea/common.nix {
  choose = idea: idea.community.release.default;
  pname = "intellij-idea-community";
  desktopName = "IntelliJ IDEA Community Edition";
  description = "Integrated Development Environment (IDE) by Jetbrains, community edition";
  chooseLicense = licenses: licenses.asl20;
  hasRemoteDev = false;
}
