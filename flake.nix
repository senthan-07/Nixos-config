{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Catppuccin themes as NixOS options (used for the Limine boot menu).
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    linux-omen-module = {
      url = "github:Sharwesh05/linux-omen-module/a6d5de8ce5b6ada973b8527eed5041f779b7b306";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, catppuccin, linux-omen-module, home-manager, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;

        overlays = [
          (import ./overlays/opencode.nix)
        ];
      };

      sources =
        builtins.fromJSON
          (builtins.readFile ./packages/source.json);

      # Zen Browser
      zenSource = sources."zen-browser";

      zenSourceForSystem =
        zenSource.sources.${system};

      zen-browser-unwrapped =
        pkgs.callPackage ./packages/zen/zen-browser-unwrapped.nix {
          version = zenSource.version;
          url = zenSourceForSystem.url;
          hash = zenSourceForSystem.hash;
        };

      zen-browser =
        pkgs.callPackage ./packages/zen/zen-browser.nix {
          inherit zen-browser-unwrapped;
        };
      
      # Omen Tools
      omen-tools =
        pkgs.callPackage ./packages/linux-omen-module/tools.nix {
          inherit linux-omen-module;
        };

    in
    {
      packages.${system} = {
        zen-browser = zen-browser;
        zen-browser-unwrapped = zen-browser-unwrapped;
        omen-tools = omen-tools;
      };

      nixosConfigurations.nixos =
        nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit
              zen-browser 
              linux-omen-module
              omen-tools;
          };

          modules = [
            ./configuration.nix
            catppuccin.nixosModules.catppuccin

            # Per-user settings: ./home.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                users.senthan = import ./home.nix;
              };
            }

            {
              nixpkgs.overlays = [
                (import ./overlays/opencode.nix)
              ];
            }
          ];
        };
        
    };
}
