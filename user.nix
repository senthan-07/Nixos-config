{ config, pkgs, zen-browser, ... }:

{
  networking.hostName = "nixos";

  users.users."senthan" = {
    isNormalUser = true;
    description = "senthan";

    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];

    shell = pkgs.fish;

    packages = with pkgs; [
      # Accessories
      vscode
      obs-studio
      discord
      gnome-extension-manager
      pavucontrol
      gnome-tweaks
      gh
      microsoft-edge
      kitty
      zen-browser
      obsidian
      junction
      opencode
      nodejs_26

      # Docker / Cloud
      docker
      cloudflare-warp
      claude-code

      # CLI
      ripgrep
      fd
      brave
      fish
    ];
  };

  programs.starship = {
    enable = true;

    settings = {
      # add_newline = false;

      # character = {
      #   success_symbol = "[➜](bold green)";
      #   error_symbol = "[➜](bold red)";
      # };

      # package.disabled = true;
    };
  };

  programs.fish.enable = true;

  programs.fish.shellAliases = {
    disk = "cd /run/media/senthan/Disk";
  };

  # Docker is configured but does NOT start automatically at boot.
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };

  environment.sessionVariables = {
    # NIXPKGS_OPENCODE_DISABLE_LEGACY_DB_WORKAROUND = "1";
    # NIXOS_OZONE_WL = "1";
  };

  programs.bash.shellAliases = {
    disk = "cd /run/media/senthan/Disk";
  };
}