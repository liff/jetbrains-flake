import ../intellij-idea/common.nix {
  choose = idea: idea.community.release.nojbr;
  pname = "intellij-idea-community";
  desktopName = "IntelliJ IDEA Community Edition";
  description = "Integrated Development Environment (IDE) by Jetbrains, community edition";
  chooseLicense = licenses: licenses.asl20;
}
