# niri compositor, as a second GDM session alongside Hyprland.
# The niri module sets defaultSession = mkDefault "niri"; override so
# Hyprland stays the default. Config.kdl and Noctalia live in home.nix.
{ config, lib, pkgs, ... }:

{
  programs.niri = {
    enable = true;
  };

  # Keep Hyprland as the default login session.
  services.displayManager.defaultSession = lib.mkForce "hyprland";
}
