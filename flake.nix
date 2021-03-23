{
  description = "A very basic flake";


  outputs = { self, nixpkgs }: {

    packages.x86_64-linux = {
      jetbrains-jcef = (import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlay ];
      }).jetbrains-jcef;

      jetbrainsruntime = (import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlay ];
      }).jetbrainsruntime;

      intellij-idea-community = (import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlay ];
      }).intellij-idea-community;

      intellij-idea-ultimate = (import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlay ];
        config.allowUnfree = true;
      }).intellij-idea-ultimate;

      intellij-idea-community-eap = (import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlay ];
      }).intellij-idea-community-eap;

    };

    overlay = final: prev: {
      jetbrains-jcef = final.callPackage ./pkgs/jetbrains-jcef {};

      jetbrainsruntime = final.callPackage ./pkgs/jetbrainsruntime {};

      intellij-idea-community = final.callPackage ./pkgs/intellij-idea-community {};

      intellij-idea-ultimate = final.callPackage ./pkgs/intellij-idea-ultimate {};

      intellij-idea-community-eap = final.callPackage ./pkgs/intellij-idea-community-eap {};
    };

    nixosModule = {
      nixpkgs.overlays = [ self.overlay ];
    };
  };
}
