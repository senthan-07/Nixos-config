# rice

A Material 3 desktop shell for Hyprland, built on [Quickshell](https://quickshell.org).
Modelled on the Clavis shell ([StatIndet/quickshell](https://github.com/StatIndet/quickshell), built for niri),
with original code for Hyprland's Lua config.

Installed by `../rice.nix` to `/etc/xdg/quickshell/rice`; run as `rice` (`qs -c rice`).

## Features

| Area | What it does |
|---|---|
| **Bar** | Workspaces with a stretching indicator, the active window, clock, weather, media, CPU/RAM/temp rings, tray, recording indicator, status chip. It can sit at the top or bottom, floating or docked, and each module can be hidden. |
| **Dynamic island** | Pill under the clock. It morphs for media (album-art palette, cava spectrum, synced LRCLIB lyrics), volume/brightness, and notification previews, and expands into a hub with Media / Focus (pomodoro, stopwatch, calendar) / Tools tabs. |
| **Launcher** | Apps as a list or grid, ranked by usage, with desktop actions. Prefixes: `/` files, `;` clipboard (text and image preview), `.` emoji, `:` wallpapers, `>` commands, `=` calculator, units and currency, `?` web, `!` keys & help (every keybind, searchable). |
| **Sidebar (right)** | Quick tiles, a quick-actions row (screenshot, record, colour picker, OCR, clipboard, emoji), sliders, media, calendar, notifications, and Wi-Fi / Bluetooth pages. |
| **Dashboard (left)** | Open-Meteo weather: animated sky, hourly chart, 7-day forecast, AQI/UV/wind/sun/moon cards. Also Info and an app Drawer. |
| **Dock** | Pinned and running apps, magnify on hover, window previews, drag to reorder, a Downloads stack, autohide. |
| **Desktop widgets** | Cookie clock, weather, liquid CPU/RAM, sparklines, network, storage, battery, calendar and to-do cards on a snapping grid, with an edit mode. |
| **Capture** | Region/window/screen screenshots, OCR, colour picker, screen and audio recording. |
| **Settings app** | 15 pages: General, Bar, Appearance, Wallpaper, Network, Bluetooth, Audio mixer, Displays, Night light, Idle, Dock, Default apps, Autostart, Shortcuts, About. |
| **System** | Notifications, OSD, lock screen (PAM `rice-lock`), power menu, polkit agent, idle lock/DPMS/suspend, night light (hyprsunset), caps/num-lock OSD. |
| **Theming** | matugen generates the shell's colours from the wallpaper, plus kitty, GTK 3/4, Qt (qt5ct/qt6ct), btop, cava, foot, fuzzel and Hyprland borders (`matugen/`). Each target can be turned off: `rice ipc call ecosystem disable <app>`. |

## Docs

- [Keybinds](docs/keybinds.md): the rice binds, your Hyprland binds and the keys inside each panel
- [IPC](docs/ipc.md): every `rice ipc call` target and function
- [Files, Dotfiles and theming](docs/files-and-theming.md): what is written where, the symlink script, and matugen app theming
- [Dotfiles/README.md](Dotfiles/README.md): the Dotfiles repo layout

Most-used keys: **Super+/** all keybinds (searchable) · **Super+Space** launcher · **Super+N** sidebar · **Super+A** dashboard · **Super+I** island ·
**Super+,** settings · **Super+W** wallpapers · **Super+C** clipboard · **Print** screenshot · **Super+L** lock ·
**Super+Esc** power menu.

## Usage

```sh
rice                                  # start (autostarted by rice.lua)
qs -p ~/Modules/nixos/rice            # run from the repo with live reload
rice ipc show                         # list every IPC target and function
rice ipc call wallpaper set ~/Pictures/Wallpapers/foo.jpg
```

Wallpapers are read from `~/Pictures/Wallpapers` (you can change the folder in Settings → Wallpaper).
State is stored in `~/.local/state/rice/`.

`Dotfiles/` is the separate Dotfiles repo (Hyprland Lua, kitty, starship, and the generated app themes). It is ignored
by this repo and linked into `~/.config` by `Dotfiles/symlink`.

## Layout

```
config/      Theme (M3 roles), Tokens, Motion, Settings, Paths
services/    Audio, Brightness, Net, Media, Notifs, SysStats, Metrics, Wallpapers, Apps, Panels (IPC),
             Hypr, Weather, Lyrics, MediaPalette, Spectrum, Timers, Todo, Dock, Capture, Recording,
             Clipboard, FileSearch, Ecosystem, Idle, NightLight, Polkit
components/  StyledText, Icon, Surface, IconButton, Chip, Tile, Slider, Ring, AppIcon, JsonStore
modules/     bar, island, launcher, sidebar, dashboard, dock, cards, capture, notifications, osd,
             power, lock, polkit, keyboard, background, settings
matugen/     templates + apply.sh for the app theming (written into Dotfiles/)
docs/        keybinds, IPC, files and theming
```
