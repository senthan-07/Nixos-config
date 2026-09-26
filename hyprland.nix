# Hyprland Window Manager setup.
# Write your Hyprland config yourself in ~/.config/hypr/hyprland.conf.
{ config, pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.systemPackages = with pkgs; [
    hyprland xwayland waybar
    wofi wlogout mako hyprpaper
    hyprlock hypridle grim
    slurp wl-clipboard brightnessctl
    playerctl uwsm
  ];
}