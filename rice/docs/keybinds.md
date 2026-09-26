# Keybinds

Hyprland binds live in the Dotfiles repo (`rice/Dotfiles/hypr`, linked to `~/.config/hypr`):

- `hypr/Rice/rice.lua`: the rice binds (below)
- `hypr/Inputs/keybind.lua`: your general window-manager binds

`Super` is the main modifier.

**In the shell:** press **Super + /** (or type `!` in the launcher, or click the ⌨ button on its mode rail)
to open **Keys & help**. It's a searchable list of every Hyprland bind, launcher prefix, in-panel key and common
`rice ipc` command. Enter runs a bind, copies a command or opens a doc. Settings → Shortcuts shows the same binds.

## Rice

### Panels

| Keys | Action | IPC |
|---|---|---|
| Super + R | Launcher (apps) | `launcher toggle` |
| Super + C | Launcher: clipboard history | `spotlight clipboard` |
| Super + . | Launcher: emoji | `spotlight emoji` |
| Super + Shift + F | Launcher: file search | `spotlight files` |
| Super + / | Launcher: keys & help (this list, searchable) | `spotlight help` |
| Super + W | Launcher: wallpapers | `launcher wallpapers` |
| Super + N | Right sidebar (quick settings, notifications) | `sidebar toggle` |
| Super + A | Left dashboard (weather / info / drawer) | `dashboard toggle` |
| Super + Shift + A | Dashboard: app drawer | `dashboard openTab drawer` |
| Super + I | Island hub | `island toggle` |
| Super + Shift + M | Island: media + lyrics | `island media` |
| Super + Shift + P | Island: pomodoro / stopwatch | `island timer` |
| Super + Shift + T | Island: tools | `island tools` |
| Super + , | Settings app | `settings open` |
| Super + Esc | Power menu | `power toggle` |
| Super + L | Lock screen | `lock lock` |
| Super + Shift + R | Reload the shell | `shell reload` |

### Desktop and toggles

| Keys | Action | IPC |
|---|---|---|
| Super + D | Dock autohide on/off | `dock toggleAutohide` |
| Super + Shift + E | Edit desktop widgets | `desktop editToggle` |
| Super + Shift + D | Dark / light mode | `theme toggleDark` |
| Super + Shift + N | Do not disturb | `notifs toggleDnd` |
| Super + Shift + B | Night light | `nightlight toggle` |

### Capture

| Keys | Action | IPC |
|---|---|---|
| Print, Super + Shift + X | Screenshot a region | `capture region` |
| Shift + Print | Screenshot the whole screen (no overlay) | `capture screen` |
| Super + Shift + W | Screenshot a window | `capture window` |
| Super + Shift + O | OCR a region → clipboard | `capture ocr` |
| Super + Shift + C | Colour picker → clipboard | `capture pick` |
| Super + Ctrl + R | Record a region (again to stop) | `capture recordRegion` |
| Super + Alt + R | Record the screen (again to stop) | `capture record` |
| Super + Alt + A | Record system audio (again to stop) | `capture recordAudio` |

Screenshots are saved to `~/Pictures/Screenshots` and copied to the clipboard. Recordings go to `~/Videos/Recordings`.

## Hyprland (keybind.lua)

| Keys | Action |
|---|---|
| Super + Return | Terminal (kitty) |
| Super + Q | Close window |
| Super + M | Exit Hyprland |
| Super + E | File manager (nautilus) |
| Super + V | Toggle floating |
| Super + P | Pseudo-tile |
| Super + J | Toggle split (dwindle) |
| Super + Arrows | Move focus |
| Super + 1…0 | Go to workspace 1–10 |
| Super + Shift + 1…0 | Move window to workspace 1–10 |
| Super + S / Super + Shift + S | Toggle / move to the scratchpad (special:magic) |
| Super + scroll | Next / previous workspace |
| Super + left drag / right drag | Move / resize window |
| Volume, mute, mic-mute keys | wpctl (rice shows the OSD) |
| Brightness keys | brightnessctl (rice shows the OSD) |
| Media keys | playerctl |

## Inside the panels

**Launcher**

| Keys | Action |
|---|---|
| Type a prefix | `/` files · `;` clipboard · `.` emoji · `:` wallpapers · `>` commands · `=` calculator (units: `10 km to mi`, currency: `100 usd to inr`) · `?` web search · `!` keys & help |
| Ctrl + 1…6 | Switch mode (apps, files, clipboard, emoji, wallpapers, keys & help) |
| Ctrl + G | List / grid view |
| ↑ ↓ / Tab / Shift + Tab / Ctrl + N / Ctrl + P | Move the selection |
| → | Show an app's actions |
| Enter | Open / run / copy |
| Alt + Enter | Reveal the file in the file manager |
| Ctrl + Enter | Copy the file path |
| Shift + Enter | Copy a clipboard entry and keep the launcher open |
| Shift + Del / Ctrl + Shift + Del | Delete a clipboard entry / clear the history |
| Esc | Close |

**Screen capture overlay**: drag to select, or click a window to snap to it. Enter confirms, arrow keys nudge the selection, Esc cancels.

**Desktop edit mode**: drag a card to move it and use its corner to resize. Tab selects a card, arrow keys move it, Del removes it. Add / Reset / Done are in the toolbar.

**Power menu**: ← → or Tab choose, Enter runs the action, Esc closes.

**Sidebar / dashboard / island hub**: Esc closes (or goes back from a sub-page). Clicking outside also closes them.

**Tiles in the right sidebar**: left-click toggles (Performance cycles saver → balanced → performance); right-click opens the details: Wi-Fi, Bluetooth and Performance pages in the sidebar, the Appearance / Idle / Night light settings pages, or desktop edit mode.
