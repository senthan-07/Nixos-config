# Home Manager for senthan (loaded from flake.nix as a NixOS module).
#
# This sits alongside rice/Dotfiles: app configs stay in Dotfiles and are
# linked into ~/.config by Dotfiles/symlink, and rice's matugen keeps writing
# GTK/Qt colours there. Home Manager only handles things that aren't files in
# Dotfiles: icon + cursor themes, GNOME/GTK settings (dconf), XDG user folders.
# Don't enable `gtk` / `qt` here: they would take over gtk-3.0, qt5ct and
# qt6ct, which are Dotfiles links.
{ config, pkgs, ... }:

let
  iconTheme = "Papirus-Dark";
  cursorTheme = "Bibata-Modern-Classic";
  cursorSize = 24;
in
{
  home.username = "senthan";
  home.homeDirectory = "/home/senthan";
  # Like system.stateVersion: the release this home was first set up with.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # ---- Icons -----------------------------------------------------------------
  # Papirus with violet folders (matches the Catppuccin mauve boot menu and
  # most rice palettes). Used by GTK 4 via dconf below, by GTK 3 through
  # Dotfiles/gtk-3.0/settings.ini (written by rice/matugen/apply.sh) and by
  # rice and Qt apps through qt5ct/qt6ct's icon_theme.
  home.packages = [
    (pkgs.papirus-icon-theme.override { color = "violet"; })

    # LazyVim needs 0.10+; nixpkgs tracks a recent stable. The config itself is
    # not a Home Manager file: it lives in Dotfiles/nvim and is linked into
    # ~/.config/nvim by Dotfiles/symlink, so nothing here would own that path.
    pkgs.neovim
  ];

  # ---- Cursor ----------------------------------------------------------------
  # Also set for Hyprland in Dotfiles/hypr/Startup/autostart.lua. This covers
  # X11/XWayland apps and ~/.icons/default. gtk.enable stays off: GTK gets it
  # from dconf and would otherwise write into the Dotfiles gtk-3.0 folder.
  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = cursorTheme;
    size = cursorSize;
    x11.enable = true;
    gtk.enable = false;
  };

  # ---- GNOME / GTK settings (dconf) -----------------------------------------
  # Only the keys listed here are set. rice switches gtk-theme and
  # color-scheme itself when the wallpaper or dark mode changes.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      icon-theme = iconTheme;
      cursor-theme = cursorTheme;
      cursor-size = cursorSize;
    };
  };

  # ---- XDG user folders --------------------------------------------------------
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}