# IPC

Everything in rice can be driven from a terminal, a script or a Hyprland bind:

```sh
rice ipc show                          # list every target and function
rice ipc call <target> <function> [args…]
```

`rice` is the wrapper installed by `rice.nix` (`qs -c rice`). When running from the repo with
`qs -p ~/Modules/nixos/rice`, use `qs -p ~/Modules/nixos/rice ipc call …` instead.

| Target | Functions |
|---|---|
| `launcher` | `toggle` `open` `close` `wallpapers` |
| `spotlight` | `open <text>` `mode <apps\|files\|clipboard\|emoji\|wallpapers\|commands\|calc\|web\|help>` `clipboard` `emoji` `files` `calc` `commands` `help` `layout <list\|grid>` `type <text>` `key <name>` |
| `clipboard` | `count` `refresh` `wipe` |
| `sidebar` | `toggle` |
| `dashboard` | `toggle` `open` `close` `openTab <weather\|info>` `current` `isOpen` |
| `island` | `toggle` `open <media\|focus\|tools\|notifications>` `close` `media` `timer` `pomodoro` `notifications` `tools` `tool <id>` `lyrics` `osd <kind>` `enable <bool>` `mode` |
| `settings` | `open` `toggle` `page <Name>` (General, Bar, Appearance, Wallpaper, Network, Bluetooth, Audio, Displays, NightLight, Idle, Dock, DefaultApps, Autostart, Shortcuts, About) |
| `power` | `toggle` |
| `lock` | `lock` `isLocked` |
| `dock` | `toggle` `toggleAutohide` `pin <id>` `unpin <id>` `list` |
| `desktop` | `editToggle` `edit <bool>` `toggle` `show` `hide` `add <type>` `types` `reset` `resetAll` `isEditing` |
| `todo` | `add <text>` `list` `clearDone` |
| `capture` | `region` `window` `screen` `screenshot` `ocr` `pick` `record` `recordRegion` `recordAudio` `recordMic` `stop` `cancel` `setAudio <bool>` `status` |
| `wallpaper` | `set <path>` `random` `get` |
| `avatar` | `set <image>` (copied to `~/.face`) `clear` `pick` (opens the picker) `get` |
| `theme` | `toggleDark` `scheme <scheme-tonal-spot\|scheme-expressive\|scheme-vibrant\|…>` |
| `ecosystem` | `regenerate` `enable <app>` `disable <app>` `toggle <app>` `status` (apps: kitty, gtk, qt, hyprland, btop, cava, foot, fuzzel) |
| `weather` | `refresh` `setCity <name>` (`""` = automatic) `setUnit <C\|F>` `toggleUnit` `summary` |
| `nightlight` | `toggle` `enable` `disable` `setTemperature <kelvin>` `schedule <HH:mm> <HH:mm>` `unschedule` `status` |
| `idle` | `toggle` `enable` `disable` `setLockAfter <s>` `setScreenOffAfter <s>` `setSuspendAfter <s>` `status` |
| `shell` | `reload` |
| `switcher` | `next` `prev` `commit` `cancel` |
| `caffeine` | `toggle` |
| `notifs` | `clear` `toggleDnd` |
| `audio` | `up` `down` `mute` `micMute` |
| `brightness` | `up` `down` `set <percent>` |
| `media` | `playPause` `next` `previous` |

## Examples

```sh
rice ipc call wallpaper set ~/Pictures/Wallpapers/forest.jpg
rice ipc call theme scheme scheme-expressive
rice ipc call weather setCity "Chennai"
rice ipc call settings page Displays
rice ipc call todo add "ship the rice"
rice ipc call ecosystem disable gtk      # stop theming GTK apps
rice ipc call capture status
```
