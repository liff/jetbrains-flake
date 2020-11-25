{
  description = "A very basic flake";

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux = {
      jetbrainsruntime = (import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlay ];
      }).jetbrainsruntime;

      intellij-idea-community = (import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlay ];
      }).intellij-idea-community;

    };

    overlay = final: prev: {
      jetbrainsruntime = final.callPackage ./pkgs/jetbrainsruntime {};

      intellij-idea-community = final.callPackage ./pkgs/intellij-idea-community {};
    };

    nixosModule = { pkgs, ... }: {
      nixpkgs.overlays = [ self.overlay ];
    };
  };
}
