import ../intellij-idea/common.nix {
  choose = idea: idea.licensed.release.nojbr;
  pname = "intellij-idea-ultimate";
  desktopName = "IntelliJ IDEA Ultimate Edition";
  description = "Integrated Development Environment (IDE) by Jetbrains, ultimate edition";
  chooseLicense = licenses: licenses.unfree;
}
