{
  description = "JetBrains IntelliJ IDEA";

  outputs = { self, nixpkgs }:
    let systems = [ "x86_64-linux" "aarch64-linux" ];
        libNames = [
          "jetbrains-jcef"
          "jetbrainsruntime"
          "fsnotifier"
        ];
        appNames = [
          "intellij-idea-community"
          "intellij-idea-community-eap"
          "intellij-idea-ultimate"
          "intellij-idea-ultimate-jbr"
        ];
        names = libNames ++ appNames;

        toFlakePackage = system: name: {
          inherit name;
          value = (import nixpkgs {
            inherit system;
            config.allowUnfree = true;
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

        mkApp = system: name: {
          inherit name;
          value = {
            type = "app";
            program = "${packages.${system}.${name}}/bin/${name}";
          };
        };

        apps = listToAttrs (
          map (system: {
            name = system;
            value = listToAttrs (map (mkApp system) appNames);
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
      inherit packages overlay apps;

      overlays.default = overlay;

      nixosModules.default = {
        nixpkgs.overlays = [ overlay ];
      };
    };
}
