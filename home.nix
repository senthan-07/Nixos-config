{ config, pkgs, ... }:

{
  home.username = "senthan";
  home.homeDirectory = "/home/senthan";

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    ripgrep
    fd
  ];

  xdg.configFile."niri/config.kdl".source = ./niri.kdl;

  programs.home-manager.enable = true;
}