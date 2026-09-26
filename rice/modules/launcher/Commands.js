// Built-in launcher commands. Execution lives in Launcher.qml (runCommand);
// this file only describes what can be searched.
.pragma library

// confirm: true asks for a second Enter before running.
var list = [
    { id: "lock", title: "Lock screen", subtitle: "Lock the session", icon: "lock", keywords: "lock screen secure away" },
    { id: "logout", title: "Log out", subtitle: "Exit Hyprland", icon: "logout", keywords: "logout log out exit quit session hyprland", confirm: true },
    { id: "suspend", title: "Suspend", subtitle: "Sleep the computer", icon: "bedtime", keywords: "suspend sleep" },
    { id: "reboot", title: "Restart", subtitle: "Reboot the computer", icon: "restart_alt", keywords: "reboot restart", confirm: true },
    { id: "poweroff", title: "Shut down", subtitle: "Power off the computer", icon: "power_settings_new", keywords: "shutdown shut down power off poweroff halt", confirm: true },
    { id: "power", title: "Power menu", subtitle: "Session options", icon: "power", keywords: "power menu session" },
    { id: "settings", title: "Settings", subtitle: "Open rice settings", icon: "settings", keywords: "settings preferences config options" },
    { id: "wallpapers", title: "Wallpapers", subtitle: "Pick a wallpaper", icon: "image", keywords: "wallpaper background picture theme" },
    { id: "randomWallpaper", title: "Random wallpaper", subtitle: "Shuffle the background", icon: "shuffle", keywords: "random wallpaper shuffle background" },
    { id: "darkMode", title: "Toggle dark mode", subtitle: "Switch between light and dark", icon: "dark_mode", keywords: "dark light mode theme toggle" },
    { id: "dnd", title: "Do not disturb", subtitle: "Silence notification popups", icon: "do_not_disturb_on", keywords: "dnd do not disturb notifications silence" },
    { id: "caffeine", title: "Caffeine", subtitle: "Keep the screen awake", icon: "coffee", keywords: "caffeine awake idle inhibit" },
    { id: "sidebar", title: "Quick settings", subtitle: "Open the sidebar", icon: "tune", keywords: "sidebar quick settings control center notifications" },
    { id: "clipboard", title: "Clipboard history", subtitle: "Browse copied items", icon: "content_paste", keywords: "clipboard history paste copy cliphist" },
    { id: "clearClipboard", title: "Clear clipboard history", subtitle: "Delete every cliphist entry", icon: "delete_sweep", keywords: "clear wipe clipboard history", confirm: true },
    { id: "emoji", title: "Emoji", subtitle: "Pick and copy an emoji", icon: "mood", keywords: "emoji emoticon smiley picker" },
    { id: "files", title: "Files", subtitle: "Search files in your home folder", icon: "draft", keywords: "files search find documents" },
    { id: "calculator", title: "Calculator", subtitle: "Math, units and currency", icon: "calculate", keywords: "calculator math convert units currency" },
    { id: "web", title: "Web search", subtitle: "Search the web", icon: "travel_explore", keywords: "web search internet browser google" },
    { id: "keybinds", title: "Keybinds & help", subtitle: "Every shortcut, launcher prefix and rice command", icon: "keyboard", keywords: "keybinds shortcuts keys hotkeys bindings help cheat sheet docs" },
    { id: "layout", title: "Toggle app grid", subtitle: "Switch the app list and grid", icon: "grid_view", keywords: "grid list layout view apps" },
    { id: "reload", title: "Reload shell", subtitle: "Restart rice", icon: "refresh", keywords: "reload restart shell quickshell rice" }
];

function score(cmd, q) {
    if (!q) return 1;
    const title = cmd.title.toLowerCase();
    if (title === q) return 100;
    if (title.startsWith(q)) return 80;
    if (title.split(" ").some(w => w.startsWith(q))) return 60;
    const words = q.split(/\s+/).filter(Boolean);
    const hay = `${title} ${cmd.keywords}`;
    if (words.every(w => hay.includes(w))) return 40;
    return 0;
}

function search(q, limit) {
    q = String(q || "").trim().toLowerCase();
    return list.map(c => ({ c: c, s: score(c, q) }))
        .filter(x => x.s > 0)
        .sort((a, b) => b.s - a.s)
        .slice(0, limit || list.length)
        .map(x => x.c);
}

// Web search engines. The first entry is the default; a leading keyword
// ("yt cats") picks another one.
var engines = [
    { key: "g", name: "Google", icon: "travel_explore", url: "https://www.google.com/search?q=%s" },
    { key: "ddg", name: "DuckDuckGo", icon: "search", url: "https://duckduckgo.com/?q=%s" },
    { key: "yt", name: "YouTube", icon: "smart_display", url: "https://www.youtube.com/results?search_query=%s" },
    { key: "w", name: "Wikipedia", icon: "menu_book", url: "https://en.wikipedia.org/w/index.php?search=%s" },
    { key: "gh", name: "GitHub", icon: "code", url: "https://github.com/search?q=%s&type=repositories" },
    { key: "nix", name: "NixOS packages", icon: "deployed_code", url: "https://search.nixos.org/packages?channel=unstable&query=%s" },
    { key: "nixopt", name: "NixOS options", icon: "settings_applications", url: "https://search.nixos.org/options?channel=unstable&query=%s" },
    { key: "maps", name: "Maps", icon: "map", url: "https://www.openstreetmap.org/search?query=%s" }
];

function engineUrl(engine, text) {
    return engine.url.replace("%s", encodeURIComponent(text));
}
