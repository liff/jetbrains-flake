import ../intellij-idea/common.nix {
  choose = idea: idea.licensed.release.default;
  pname = "intellij-idea-ultimate-jbr";
  desktopName = "IntelliJ IDEA Ultimate Edition (JBR)";
  description = "Integrated Development Environment (IDE) by Jetbrains, ultimate edition (JBR bundled)";
  chooseLicense = licenses: licenses.unfree;
  useBuiltJbr = false;
}
