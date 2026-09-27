# Hyprland + "rice", a Quickshell desktop shell modelled on the Clavis shell:
# bar, dynamic island, spotlight launcher (apps/files/clipboard/emoji/calc),
# quick-settings sidebar, weather dashboard, dock, desktop widgets,
# notifications, OSD, screenshot/recording tools, settings app, polkit agent,
# lock screen, idle/night light, and matugen theming of the shell + apps.
#
# The QML lives in ./rice and runs as `qs -c rice` (the `rice` command below).
# Quickshell looks in ~/.config/quickshell first: rice/Dotfiles/symlink links
# ~/.config/quickshell/rice to this repo, so edits apply live. 
#
# Hyprland itself is configured in ./rice/Dotfiles/hypr (Lua), linked into
# ~/.config by rice/Dotfiles/symlink along with the other app configs.
{ config, lib, pkgs, ... }:

let
  # `rice` starts the shell; `rice ipc call <target> <fn>` talks to it.
  # Theme files and autostart entries are written into the Dotfiles repo that
  # ~/.config/hypr links into (falls back to ~/.config when it isn't a link).
  rice = pkgs.writeShellScriptBin "rice" ''
    if [ -z "''${RICE_DOTFILES:-}" ]; then
      RICE_DOTFILES=$(dirname "$(readlink -f "''${XDG_CONFIG_HOME:-$HOME/.config}/hypr")")
      export RICE_DOTFILES
    fi
    exec ${pkgs.quickshell}/bin/qs -c rice "$@"
  '';
in
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # The shell's QML, without the Dotfiles folder (that's linked into ~/.config
  # by Dotfiles/symlink and isn't needed in the read-only system copy).
  environment.etc."xdg/quickshell/rice".source = lib.cleanSourceWith {
    name = "rice";
    src = ./rice;
    filter = path: type: !(lib.hasPrefix (toString ./rice/Dotfiles) path);
  };

  environment.systemPackages = with pkgs; [
    # Compositor + session
    hyprland xwayland uwsm
    hyprlock          # fallback locker; rice has its own lock + idle service
    hyprsunset        # night light
    dex               # runs ~/.config/autostart entries (Settings > Autostart)

    # Shell + runtime tools it calls
    quickshell rice
    matugen           # wallpaper -> Material You colours (shell + app templates)
    brightnessctl     # backlight control (via logind)
    networkmanager    # nmcli
    bluez             # bluetoothctl
    libnotify         # notify-send
    playerctl
    cava              # audio visualiser in the island
    curl
    glib              # gdbus / gsettings
    pciutils          # lspci (Settings > About)
    xdg-utils         # xdg-open / xdg-mime
    fd                # launcher file search
    cliphist          # clipboard history
    wl-clipboard
    kdePackages.qtimageformats   # webp/avif wallpapers + thumbnails

    # Capture tools
    grim slurp
    wf-recorder       # screen recording
    pulseaudio        # pactl only (default sink for recording audio)
    tesseract         # OCR
    satty             # screenshot annotation ("Edit" in notifications)

    # Cursor theme (set in Dotfiles/hypr/Startup/autostart.lua)
    bibata-cursors
    nixos-icons       # NixOS snowflake for the bar's launcher button

    # Theming targets for the matugen templates
    adw-gtk3
    qt6Packages.qt6ct
    libsForQt5.qt5ct
  ];

  fonts.packages = with pkgs; [
    material-symbols        # icon font used throughout the shell
    inter                   # UI font
    noto-fonts-color-emoji  # emoji picker
  ];

  # Qt apps pick up the generated colour scheme through qt5ct/qt6ct.
  qt = {
    enable = true;
    platformTheme = "qt5ct";
  };

  # Services the shell reads over D-Bus.
  services.upower.enable = true;          # battery
  hardware.bluetooth.enable = true;       # Bluetooth tile / page
  services.power-profiles-daemon.enable = true;

  # PAM service for the lock screen (password auth only).
  security.pam.services.rice-lock = { };
}
