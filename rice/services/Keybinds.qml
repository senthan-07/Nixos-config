pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/settings/widgets/binds.js" as Binds

// Hyprland keybinds for the launcher's "Keys & help" mode.
// Parsed from the Hyprland config (Lua or hyprlang) and, inside a running
// Hyprland, merged with `hyprctl -j binds` for the live set.
Singleton {
    id: root

    readonly property bool hyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "") !== ""
    property var fileRows: []
    property var liveRows: []
    property bool loaded: false
    property bool loading: false

    readonly property var rows: liveRows.length ? liveRows : fileRows
    readonly property string source: liveRows.length ? "live" : "config"
    readonly property var categories: Binds.categories()

    function combo(r) {
        return Binds.combo(r.mods, r.key);
    }

    function iconFor(category) {
        const c = categories.find(c => c.name === category);
        return c ? c.icon : "keyboard";
    }

    // Grouped [{ name, icon, items }] filtered by a search query.
    function groups(query) {
        return Binds.group(rows, query);
    }

    function reload() {
        if (loading) return;
        loading = true;
        files.running = true;
    }

    Process {
        id: files
        command: ["sh", "-c",
            "d=\"${XDG_CONFIG_HOME:-$HOME/.config}/hypr\"; "
            + "[ -d \"$d\" ] || d=\"${RICE_DOTFILES:-$HOME/Modules/nixos/rice/Dotfiles}/hypr\"; "
            + "[ -d \"$d\" ] || exit 0; "
            + "find -L \"$d\" -maxdepth 3 -type f \\( -name '*.lua' -o -name '*.conf' \\) 2>/dev/null | sort | "
            + "while IFS= read -r f; do grep -qE 'hl\\.bind|^[[:space:]]*bind[a-z]*[[:space:]]*=' \"$f\" 2>/dev/null || continue; "
            + "printf '\\n@@FILE %s\\n' \"$f\"; cat \"$f\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const chunk of text.split("\n@@FILE ").slice(1)) {
                    const nl = chunk.indexOf("\n");
                    list.push({ path: chunk.slice(0, nl), text: chunk.slice(nl + 1) });
                }
                try {
                    root.fileRows = Binds.parseFiles(list);
                } catch (e) {
                    console.warn("rice: could not parse keybinds:", e);
                    root.fileRows = [];
                }
                if (root.hyprland) {
                    live.running = true;
                } else {
                    root.loaded = true;
                    root.loading = false;
                }
            }
        }
    }

    Process {
        id: live
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = Binds.parseLive(text, root.fileRows);
                if (rows) root.liveRows = rows;
                root.loaded = true;
                root.loading = false;
            }
        }
        onExited: code => {
            if (code !== 0) {
                root.loaded = true;
                root.loading = false;
            }
        }
    }
}
