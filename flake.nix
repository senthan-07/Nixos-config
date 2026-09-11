{
  description = "Omen NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Zen Browser flake
    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    # Claude Code flake (pre-built binary)
    claude-code.url = "github:sadjow/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";

    # OpenCode flake (pre-built patched binary)
    opencode-nix.url = "github:dan-online/opencode-nix";
    opencode-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, zen-browser, claude-code, opencode-nix, ... }: 
  let
    system = "x86_64-linux";
  in {
    nixosConfigurations.Omen = nixpkgs.lib.nixosSystem {
      inherit system;

      modules = [
        ./configuration.nix

        {
          environment.systemPackages = [
            zen-browser.packages.${system}.default
            claude-code.packages.${system}.default
            opencode-nix.packages.${system}.default
          ];
        }
      ];
    };
  };
}