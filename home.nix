{ config, pkgs, noctalia, ... }:

{
  imports = [
    noctalia.homeModules.default
  ];

  home.username = "senthan";
  home.homeDirectory = "/home/senthan";

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    ripgrep
    fd
    xwayland-satellite
  ];

  programs.home-manager.enable = true;

  programs.noctalia = {
    enable = true;
  };

  xdg.configFile."niri/config.kdl".source = ./niri.kdl;
}
