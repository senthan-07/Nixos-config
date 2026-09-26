pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// Ecosystem theming: renders the matugen templates in matugen/config.toml for
// other apps (kitty, GTK, Qt, btop, cava, foot, fuzzel, Hyprland borders) from
// the current wallpaper, then reloads whatever is running.
//
// Persisted in $XDG_STATE_HOME/rice/ecosystem.json:
//   enabled          master switch (default true)
//   apps             { <target>: bool } per-app switches (default on)
//   scheme           matugen scheme type, "" = follow Settings.data.scheme
//   mode             "auto" (follow Settings.data.darkMode) | "dark" | "light"
//   sourceColorIndex 0-4, which dominant wallpaper colour seeds the scheme
//   contrast         -1 .. 1
Singleton {
    id: root

    // Targets shown in settings. `id` matches the prefix of the template names.
    readonly property var apps: [
        { id: "kitty", label: "Kitty", icon: "terminal", description: "Terminal colours, follows dark/light automatically" },
        { id: "gtk", label: "GTK 3 / 4", icon: "web_asset", description: "libadwaita and adw-gtk3 accent and surface colours" },
        { id: "qt", label: "Qt", icon: "widgets", description: "qt5ct / qt6ct colour scheme" },
        { id: "hyprland", label: "Hyprland", icon: "select_window", description: "Active and inactive window borders" },
        { id: "btop", label: "btop", icon: "monitoring", description: "Theme \"rice\" for the system monitor" },
        { id: "cava", label: "cava", icon: "graphic_eq", description: "Audio visualizer gradient" },
        { id: "foot", label: "foot", icon: "terminal", description: "Include rice-colors.ini from foot.ini" },
        { id: "fuzzel", label: "fuzzel", icon: "search", description: "Include rice-colors.ini from fuzzel.ini" }
    ]

    readonly property bool enabled: store.get("enabled", true)
    readonly property string scheme: Settings.data.scheme
    readonly property string modeSetting: store.get("mode", "auto")
    readonly property string mode: modeSetting === "auto" ? (Settings.data.darkMode ? "dark" : "light") : modeSetting
    readonly property int sourceColorIndex: Math.max(0, Math.min(3, Settings.data.sourceColorIndex))
    readonly property real contrast: Math.max(-1, Math.min(1, Settings.data.schemeContrast))

    // Only true inside a Hyprland session; outside it apps are never signalled.
    readonly property bool live: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

    readonly property bool busy: runner.running
    property string error: ""
    property var warnings: []
    property var outputs: []
    property date lastRun
    property bool hasRun: false

    signal finished(bool ok)

    function isEnabled(app) {
        const map = store.get("apps", {});
        return map[app] !== undefined ? !!map[app] : true;
    }

    function setEnabled(app, on) {
        if (isEnabled(app) === !!on) return;
        const map = Object.assign({}, store.get("apps", {}));
        map[app] = !!on;
        store.set("apps", map);
        if (!on) undo(app);
        else regenerate();
    }

    function toggle(app) { setEnabled(app, !isEnabled(app)); }
    function setMasterEnabled(on) { store.set("enabled", !!on); if (on) regenerate(); }
    function setScheme(name) { Settings.data.scheme = name || "scheme-tonal-spot"; Wallpapers.regenerate(); }
    function setMode(m) { store.set("mode", ["dark", "light"].includes(m) ? m : "auto"); regenerate(); }
    function setSourceColorIndex(i) { Settings.data.sourceColorIndex = Math.max(0, Math.min(3, Math.round(i))); Wallpapers.regenerate(); }
    function setContrast(c) { Settings.data.schemeContrast = Math.max(-1, Math.min(1, Number(c) || 0)); Wallpapers.regenerate(); }

    readonly property var enabledTargets: apps.map(a => a.id).filter(id => isEnabled(id))

    // Debounced so a burst of changes (wallpaper + mode) renders once.
    function regenerate() {
        if (!enabled) return;
        debounce.restart();
    }

    function undo(app) {
        Quickshell.execDetached({
            command: ["bash", `${Quickshell.shellDir}/matugen/apply.sh`, "restore", app],
            environment: env()
        });
    }

    // Theme files go into the Dotfiles repo; apply.sh links new app folders
    // into ~/.config.
    function configHome() {
        return Paths.dotfiles;
    }

    function env() {
        return {
            RICE_STATE_DIR: Paths.state,
            RICE_CONFIG_DIR: configHome(),
            RICE_LIVE: live ? "1" : "0"
        };
    }

    // Keeps [config] and every enabled [templates.<target>_*] table.
    function buildConfig(manifest) {
        const on = enabledTargets;
        const kept = [];
        let keep = true;
        for (const line of manifest.split("\n")) {
            if (line.startsWith("[")) {
                const m = line.match(/^\[templates\.([A-Za-z0-9-]+)/);
                keep = !m || on.includes(m[1]);
            }
            // Comments are dropped; they would mention the placeholders.
            if (keep && !/^\s*#/.test(line)) kept.push(line);
        }
        return kept.join("\n")
            .replace(/@TEMPLATES@/g, `${Quickshell.shellDir}/matugen/templates`)
            .replace(/@CONFIG@/g, configHome())
            .replace(/@STATE@/g, Paths.state);
    }

    function run() {
        if (runner.running) {
            pending = true;
            return;
        }
        const manifestText = manifest.text();
        if (!manifestText) {
            error = "matugen/config.toml is missing";
            return;
        }
        const wall = Settings.data.wallpaper;
        const source = wall ? `image:${wall}` : `color:${Theme.role("primary")}`;
        const e = env();
        e.RICE_MATUGEN_TOML = buildConfig(manifestText);
        e.RICE_SOURCE = source;
        e.RICE_SCHEME = scheme;
        e.RICE_MODE = mode;
        e.RICE_INDEX = String(sourceColorIndex);
        e.RICE_CONTRAST = String(contrast);
        e.RICE_TARGETS = enabledTargets.join(" ");
        runner.environment = e;
        runner.running = true;
    }

    property bool pending: false

    Timer {
        id: debounce
        interval: 400
        onTriggered: root.run()
    }

    JsonStore {
        id: store
        name: "ecosystem"
    }

    FileView {
        id: manifest
        path: `${Quickshell.shellDir}/matugen/config.toml`
        blockLoading: true
        printErrors: false
    }

    // First start (nothing rendered yet): theme the apps once.
    FileView {
        path: `${Paths.state}/matugen.toml`
        printErrors: false
        onLoadFailed: root.regenerate()
    }

    // Follow the shell's dark/light switch when mode is "auto".
    Connections {
        target: Settings.data
        function onDarkModeChanged() {
            if (root.modeSetting === "auto") root.regenerate();
        }
    }

    Process {
        id: runner
        command: ["bash", `${Quickshell.shellDir}/matugen/apply.sh`]
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            const lines = out.text.split("\n");
            root.outputs = lines.filter(l => l.startsWith("wrote ")).map(l => l.slice(6));
            root.warnings = lines.filter(l => l.startsWith("warn ")).map(l => l.slice(5));
            root.error = code === 0 ? "" : (root.warnings.length ? root.warnings[root.warnings.length - 1] : `matugen exited with ${code}`);
            if (code !== 0) console.warn("rice: ecosystem theming failed:", root.error);
            root.lastRun = new Date();
            root.hasRun = true;
            root.finished(code === 0);
            if (root.pending) {
                root.pending = false;
                root.run();
            }
        }
    }

    IpcHandler {
        target: "ecosystem"
        function regenerate(): void { root.run(); }
        function enable(app: string): void { root.setEnabled(app, true); }
        function disable(app: string): void { root.setEnabled(app, false); }
        function toggle(app: string): void { root.toggle(app); }
        function status(): string {
            return JSON.stringify({
                enabled: root.enabled, busy: root.busy, error: root.error, mode: root.mode,
                scheme: root.scheme, targets: root.enabledTargets, outputs: root.outputs,
                warnings: root.warnings
            });
        }
    }
}
