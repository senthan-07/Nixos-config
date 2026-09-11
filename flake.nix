{
  description = "Omen NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen Browser flake
    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    # Claude Code flake (pre-built binary)
    claude-code.url = "github:sadjow/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";

    # OpenCode flake (pre-built patched binary)
    opencode-nix.url = "github:dan-online/opencode-nix";
    opencode-nix.inputs.nixpkgs.follows = "nixpkgs";

    #Omen fan control
    linux-omen-module = {
      url = "github:Sharwesh05/linux-omen-module/ddfc4bbb786f9cd4726c93184dc74add7cbffaab";
      flake = false;
    };

  };

  outputs = { self, nixpkgs, zen-browser, claude-code, opencode-nix, linux-omen-module, home-manager, ... }: 
  let
    system = "x86_64-linux";
  in {

    packages.${system}.hpomen =
      (nixpkgs.legacyPackages.${system}).callPackage ./hpomen.nix {
        kernel = (nixpkgs.legacyPackages.${system}).linuxPackages.kernel;
        inherit linux-omen-module;
      };

    nixosConfigurations.Omen = nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit linux-omen-module;
      };

      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager

        {
          environment.systemPackages = [
            zen-browser.packages.${system}.default
            claude-code.packages.${system}.default
            opencode-nix.packages.${system}.default
          ];
          home-manager.users.senthan = import ./home.nix;
        }
      ];
    };
  };
}