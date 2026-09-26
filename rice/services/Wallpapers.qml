pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Wallpaper selection and matugen-driven colour extraction. After the shell's
// own colours are generated, Ecosystem renders the app templates (kitty, GTK,
// Qt, Hyprland borders, ...) from the same wallpaper and settings.
Singleton {
    id: root

    readonly property string current: Settings.data.wallpaper
    property var list: []

    function set(path) {
        path = Paths.stripFileUrl(path);
        if (!path) return;
        Settings.data.wallpaper = path;
        regenerate();
    }

    function random() {
        if (list.length) set(list[Math.floor(Math.random() * list.length)]);
    }

    readonly property string folder: Settings.data.wallpaperDir || Paths.wallpaperDir
    onFolderChanged: rescan()

    // matugen fails when the image has fewer colours than the requested
    // source index; retry once with index 0.
    property int attemptIndex: 0

    function regenerate(index) {
        if (!Settings.data.wallpaper) return;
        attemptIndex = index === undefined ? Ecosystem.sourceColorIndex : index;
        matugen.command = ["matugen", "image", Settings.data.wallpaper,
            "--json", "hex", "--dry-run", "-q",
            "--source-color-index", String(attemptIndex),
            "--contrast", String(Ecosystem.contrast),
            "-m", Ecosystem.mode,
            "-t", Ecosystem.scheme];
        matugen.running = true;
    }

    function rescan() {
        finder.running = true;
    }

    Component.onCompleted: rescan()

    Process {
        id: matugen
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    Theme.applyMatugen(JSON.parse(text));
                } catch (e) {
                    if (root.attemptIndex > 0) {
                        root.regenerate(0);
                        return;
                    }
                    console.warn("rice: matugen output could not be parsed", e);
                    return;
                }
                // Colours are in: now theme the rest of the desktop.
                Ecosystem.regenerate();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("rice: matugen:", text.trim())
        }
    }

    Process {
        id: finder
        command: ["find", "-L", root.folder, "-maxdepth", "2", "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: root.list = text.split("\n").filter(l => l).sort()
        }
    }

    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { root.set(path); }
        function random(): void { root.random(); }
        function get(): string { return root.current; }
    }
}
