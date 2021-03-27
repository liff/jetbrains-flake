{
  description = "JetBrains IntelliJ IDEA";

  outputs = { self, nixpkgs }:
    let systems = [ "i686-linux" "x86_64-linux" "armv7l-linux" "aarch64-linux" ];
        names = [
          "jetbrains-jcef"
          "jetbrainsruntime"
          "intellij-idea-community"
          "intellij-idea-community-eap"
          "intellij-idea-ultimate"
          #          "intellij-idea-ultimate-eap"
        ];

        toFlakePackage = system: name: {
          inherit name;
          value = (import nixpkgs {
            inherit system;
            overlays = [ self.overlay ];
          })."${name}";
        };

        inherit (builtins) map listToAttrs;

        packages = listToAttrs (
          map (system: {
            name = system;
            value = listToAttrs (map (toFlakePackage system) names);
          })
            systems);

        overlay = final: prev:
          listToAttrs (
            map (name: {
              inherit name;
              value = final.callPackage (./pkgs + "/${name}") {};
            })
              names);
    in {
      inherit packages overlay;

      nixosModule = {
        nixpkgs.overlays = [ self.overlay ];
      };
    };
}
