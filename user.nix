# User Configuration
{ config, pkgs, zen-browser, ... }:

{
  networking.hostName = "nixos";

  users.users.senthan = {
    isNormalUser = true;
    description = "senthan";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  programs.starship = {
    enable = true;
    # Configuration written to ~/.config/starship.toml
    settings = {
      # add_newline = false;

      # character = {
      #   success_symbol = "[➜](bold green)";
      #   error_symbol = "[➜](bold red)";
      # };

      # package.disabled = true;
    };
  };

  environment.sessionVariables = {
    # NIXPKGS_OPENCODE_DISABLE_LEGACY_DB_WORKAROUND = "1";
    # NIXOS_OZONE_WL = "1";
  };

  programs.bash.shellAliases = {
    disk = "cd /run/media/senthan/Disk";
  };
}
