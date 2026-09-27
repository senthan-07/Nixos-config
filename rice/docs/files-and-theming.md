# Files, Dotfiles and theming

## Where things live

| What | Where | Notes |
|---|---|---|
| Shell code (QML) | `~/Modules/nixos/rice` | Runs live via `~/.config/quickshell/rice` (a Dotfiles link); a read-only copy is also installed to `/etc/xdg/quickshell/rice` by `rice.nix` |
| Packages, fonts, services, PAM | `~/Modules/nixos/rice.nix` | Imported from `configuration.nix` |
| Dotfiles | `~/Modules/nixos/rice/Dotfiles` | Part of the nixos repo; linked into `~/.config` by `Dotfiles/symlink`. Left out of the read-only system copy of the shell |
| Hyprland config (Lua) | `Dotfiles/hypr` → `~/.config/hypr` | rice parts: `hypr/Rice/rice.lua` (binds, autostart, rules), `hypr/Rice/colors.lua` (wallpaper border colours) |
| Generated app themes | `Dotfiles/<app>/…` → `~/.config/<app>` | See the table below |
| Autostart entries | `Dotfiles/autostart` → `~/.config/autostart` | Managed from Settings → Autostart; run at login by `dex` |
| rice settings + state | `~/.local/state/rice/*.json` | settings, scheme, dock, weather cache, desktop widgets, to-do, … |
| Screenshots / recordings | `~/Pictures/Screenshots`, `~/Videos/Recordings` | |
| Wallpapers | `~/Pictures/Wallpapers` | The folder can be changed in Settings → Wallpaper |

## Linking Dotfiles into ~/.config

`Dotfiles/symlink` links every top-level item of the Dotfiles folder to `~/.config/<name>`:

```sh
~/Modules/nixos/rice/Dotfiles/symlink
```

- It works from any directory (it links from the folder it lives in).
- It replaces links that point somewhere else (for example an old Dotfiles location).
- If a real file or folder is in the way, it is moved to `<name>.backup-<date>` first.
- It removes stale links, but only ones that point into the Dotfiles folder.
- It skips `.git`, `.vscode`, `README.md` and itself. Run it again after adding a new folder.

Currently linked: `autostart btop cava foot fuzzel gtk-3.0 gtk-4.0 hypr kitty qt5ct qt6ct quickshell starship.toml`.

## Theming (matugen)

When you pick a wallpaper (Super + W, Settings → Wallpaper, or `rice ipc call wallpaper set <path>`), rice runs
[matugen](https://github.com/InioX/matugen) to build a Material 3 palette. The palette recolours the shell right away,
and `rice/matugen/apply.sh` renders the app templates in `rice/matugen/templates` into Dotfiles:

| App | Files written (in `Dotfiles/`) | How it's picked up |
|---|---|---|
| kitty | `kitty/dark-theme.auto.conf`, `light-theme.auto.conf`, `no-preference-theme.auto.conf` | kitty auto-themes; reloaded with SIGUSR1. Your original theme is kept as `*.pre-rice` and restored when the target is disabled |
| GTK 3 / 4 | `gtk-3.0/rice-colors.css`, `gtk-4.0/rice-colors.css` + an `@import` line at the top of `gtk.css` | Restart GTK apps. Best with the `adw-gtk3` theme |
| Qt | `qt5ct/colors/rice.conf`, `qt6ct/colors/rice.conf` (+ `qt5ct.conf`/`qt6ct.conf` if missing) | `qt.platformTheme = "qt5ct"` in rice.nix |
| Hyprland | `hypr/Rice/wallpaper-colors.lua` | Read by `hypr/Rice/colors.lua`; applied with `hyprctl reload` |
| btop | `btop/themes/rice.theme` | Set `color_theme = "rice"` in `btop.conf` |
| cava | `cava/themes/rice` | Set `theme = 'rice'` in the cava config |
| foot / fuzzel | `foot/rice-colors.ini`, `fuzzel/rice-colors.ini` | Add an `include=` line to their configs |

If a newly created app folder has no `~/.config` link yet, `apply.sh` creates the link. If a *real* folder is already in
the way, it leaves it alone and logs a warning; run `Dotfiles/symlink` to fix that.

Generated files are listed in `Dotfiles/.gitignore`, so they don't show up as changes. The exception is
`kitty/dark-theme.auto.conf`, which your repo already tracks.

Controls:

- Settings → Appearance: dark/light, scheme style (10 matugen schemes), contrast, bar/panel opacity
- Settings → Wallpaper: folder, wallpaper, source-colour swatch
- `rice ipc call ecosystem disable <kitty|gtk|qt|hyprland|btop|cava|foot|fuzzel>` turns a target off and undoes its changes

Things that are not files:
- The GNOME `color-scheme` (prefer-dark / prefer-light) is switched with `gsettings` to match. It lives in dconf.
- `~/.config/mimeapps.list` (Settings → Default apps) stays in `~/.config`. GNOME and `xdg-mime` rewrite that file by
  replacing it, which would break a symlink.

GNOME uses the same home folder, so GTK/Qt theming and the colour scheme also apply there.

## Runtime environment

| Variable | Meaning |
|---|---|
| `RICE_DOTFILES` | Where theme files and autostart entries go. Set by the `rice` wrapper from where `~/.config/hypr` links to; falls back to `~/.config` |
| `RICE_NO_POLKIT=1` | Don't register rice's polkit agent (keep another one) |
| `RICE_SETTINGS_DRYRUN=1` | Settings pages log system changes instead of applying them (testing) |
| `RICE_AUTOSTART_DIR` | Use a different autostart folder (testing) |

## Services rice expects

Enabled in `rice.nix`: upower (battery), bluetooth, power-profiles-daemon, the `rice-lock` PAM service, and the
Material Symbols / Inter / Noto Color Emoji fonts. Don't run another notification daemon (mako, dunst), idle daemon
(hypridle) or polkit agent in the Hyprland session. rice provides all three.
