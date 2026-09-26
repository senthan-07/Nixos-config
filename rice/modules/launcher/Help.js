// Static content for the launcher's "Keys & help" mode. Hyprland binds come
// from services/Keybinds.qml; this file covers everything that isn't a bind.
.pragma library

// Launcher prefixes (typed at the start of the search in Apps mode).
var prefixes = [
    { key: "/", mode: "files", title: "Search files", subtitle: "Home folder; Alt+Enter shows the file in its folder" },
    { key: ";", mode: "clipboard", title: "Clipboard history", subtitle: "Text and images copied while cliphist runs" },
    { key: ".", mode: "emoji", title: "Emoji picker", subtitle: "Enter copies the emoji" },
    { key: ":", mode: "wallpapers", title: "Wallpapers", subtitle: "Pick one; colours follow the wallpaper" },
    { key: ">", mode: "commands", title: "Commands", subtitle: "Built-in actions or any shell command" },
    { key: "=", mode: "calc", title: "Calculator", subtitle: "Math, units (10 km to mi) and currency (100 usd to inr)" },
    { key: "?", mode: "web", title: "Web search", subtitle: "yt, w, gh, nix, maps or ddg picks an engine" },
    { key: "!", mode: "help", title: "Keys & help", subtitle: "This list" }
];

// Keys that work inside rice's panels (not Hyprland binds).
var panelKeys = [
    { area: "Launcher", keys: "Ctrl + 1…6", title: "Switch launcher mode" },
    { area: "Launcher", keys: "Ctrl + G", title: "App list / grid" },
    { area: "Launcher", keys: "↑ ↓ · Tab · Ctrl + N / P", title: "Move the selection" },
    { area: "Launcher", keys: "→", title: "Show an app's actions" },
    { area: "Launcher", keys: "Alt + Enter", title: "Reveal a file in its folder" },
    { area: "Launcher", keys: "Ctrl + Enter", title: "Copy a file's path" },
    { area: "Launcher", keys: "Shift + Enter", title: "Copy a clipboard entry and stay open" },
    { area: "Launcher", keys: "Shift + Del", title: "Delete a clipboard entry" },
    { area: "Launcher", keys: "Ctrl + Shift + Del", title: "Clear clipboard history" },
    { area: "Capture", keys: "Drag · click a window", title: "Select a region or snap to a window" },
    { area: "Capture", keys: "Enter · arrows · Esc", title: "Confirm, nudge the selection, cancel" },
    { area: "Desktop edit", keys: "Tab · arrows · Del", title: "Select, move and remove widgets" },
    { area: "Power menu", keys: "← → · Enter · Esc", title: "Choose, run, close" },
    { area: "Panels", keys: "Esc", title: "Close the sidebar, dashboard, island or launcher" },
    { area: "Sidebar", keys: "Click / right-click a tile", title: "Toggle it / open its details" },
    { area: "Bar", keys: "Click the clock", title: "Open the island hub" },
    { area: "Bar", keys: "Click the status icons", title: "Open the quick-settings sidebar" },
    { area: "Bar", keys: "Scroll on status icons", title: "Change volume" },
    { area: "Bar", keys: "Scroll on workspaces", title: "Switch workspace" }
];

// Handy IPC commands (Enter copies the command).
var ipc = [
    { cmd: "rice ipc show", title: "List every IPC target and function" },
    { cmd: "rice ipc call wallpaper set <path>", title: "Set a wallpaper" },
    { cmd: "rice ipc call wallpaper random", title: "Random wallpaper" },
    { cmd: "rice ipc call theme scheme scheme-expressive", title: "Change the matugen colour scheme" },
    { cmd: "rice ipc call theme toggleDark", title: "Dark / light mode" },
    { cmd: "rice ipc call settings page Displays", title: "Open a settings page" },
    { cmd: "rice ipc call weather setCity Chennai", title: "Set the weather city (\"\" = automatic)" },
    { cmd: "rice ipc call todo add \"buy milk\"", title: "Add a to-do" },
    { cmd: "rice ipc call ecosystem disable gtk", title: "Stop theming an app (kitty gtk qt hyprland btop cava foot fuzzel)" },
    { cmd: "rice ipc call capture status", title: "Recording / capture state" },
    { cmd: "rice ipc call desktop add clock", title: "Add a desktop widget" },
    { cmd: "rice ipc call idle setLockAfter 300", title: "Lock after N seconds idle" },
    { cmd: "rice ipc call nightlight schedule 20:00 07:00", title: "Schedule the night light" }
];

// Docs shipped with the shell (relative to Quickshell.shellDir).
var docs = [
    { file: "docs/keybinds.md", title: "Keybinds", subtitle: "All binds and in-panel keys" },
    { file: "docs/ipc.md", title: "IPC reference", subtitle: "Every rice ipc target and function" },
    { file: "docs/files-and-theming.md", title: "Files, Dotfiles and theming", subtitle: "What rice writes where" },
    { file: "README.md", title: "rice README", subtitle: "Features overview" }
];
