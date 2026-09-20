{
  description = "Omen NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Code flake (pre-built binary)
    claude-code.url = "github:sadjow/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";

    #Omen fan control
    linux-omen-module = {
      url = "github:Sharwesh05/linux-omen-module/a6d5de8ce5b6ada973b8527eed5041f779b7b306";
      flake = false;
    };

    # Noctalia
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, claude-code, linux-omen-module, home-manager, noctalia, ... }:
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

    zenSourceForSystem =
      sources."zen-browser".sources.${system};

    zen-browser-unwrapped =
      pkgs.callPackage ./packages/zen/zen-browser-unwrapped.nix {
        version = sources."zen-browser".version;
        url = zenSourceForSystem.url;
        hash = zenSourceForSystem.hash;
      };

    zen-browser =
      pkgs.callPackage ./packages/zen/zen-browser.nix {
        inherit zen-browser-unwrapped;
      };

    omen-tools =
      pkgs.callPackage ./packages/linux-omen-module/tools.nix {
        inherit linux-omen-module;
      };
  in {

    packages.${system} = {
      inherit zen-browser zen-browser-unwrapped omen-tools;
    };

    nixosConfigurations.Omen = nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit
          zen-browser
          linux-omen-module
          omen-tools;
      };

      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager

        {
          environment.systemPackages = [
            zen-browser
            claude-code.packages.${system}.default
          ];

          home-manager.extraSpecialArgs = {
            inherit noctalia;
          };

          home-manager.users.senthan = import ./home.nix;
        }
      ];
    };
  };
}
