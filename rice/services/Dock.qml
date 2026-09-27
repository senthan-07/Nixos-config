pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components

// Dock state: preferences, pinned apps, running windows grouped per app and
// the "recent files" folder shown as a stack at the end of the dock.
//
// Keys identify one dock slot. For apps with a desktop file the key is the
// desktop id (e.g. "firefox"); windows without one use their Wayland app id.
Singleton {
    id: root

    // ---- preferences (persisted in $XDG_STATE_HOME/rice/dock.json) ----
    readonly property bool enabled: store.get("enabled", true)
    readonly property bool autohide: store.get("autohide", false)
    // With autohide on: only hide while a window overlaps the dock (Hyprland only).
    readonly property bool smartHide: store.get("smartHide", true)
    readonly property int iconSize: store.get("iconSize", 48)
    readonly property bool magnification: store.get("magnification", true)
    readonly property real magnifyScale: store.get("magnifyScale", 1.6)
    readonly property int padding: store.get("padding", 12)        // around the icons, inside the dock
    readonly property int edgeGap: store.get("edgeGap", 14)        // between the dock and the screen edge
    readonly property bool runningOnly: store.get("runningOnly", false)
    readonly property bool showPreviews: store.get("showPreviews", true)
    readonly property bool showFolder: store.get("showFolder", true)
    readonly property string folder: store.get("folder", "") || defaultFolder
    readonly property var pinned: store.get("pinned", defaultPinned)

    function setEnabled(b) { store.set("enabled", !!b); }
    function setAutohide(b) { store.set("autohide", !!b); }
    function setSmartHide(b) { store.set("smartHide", !!b); }
    function setIconSize(px) { store.set("iconSize", Math.round(Math.max(32, Math.min(80, px)))); }
    function setMagnification(b) { store.set("magnification", !!b); }
    function setMagnifyScale(s) { store.set("magnifyScale", Math.max(1.1, Math.min(2, s))); }
    function setPadding(px) { store.set("padding", Math.round(Math.max(4, Math.min(32, px)))); }
    function setEdgeGap(px) { store.set("edgeGap", Math.round(Math.max(0, Math.min(64, px)))); }
    function setRunningOnly(b) { store.set("runningOnly", !!b); }
    function setShowPreviews(b) { store.set("showPreviews", !!b); }
    function setShowFolder(b) { store.set("showFolder", !!b); }
    function setFolder(path) { store.set("folder", String(path || "")); refreshFolder(); }

    // ---- pinned apps ----
    readonly property var defaultPinned: {
        const apps = DesktopEntries.applications.values; // re-evaluate once entries load
        const wanted = [Settings.data.terminal, "kitty", "firefox", "zen", "zen-beta", "chromium", "google-chrome",
            "org.gnome.Nautilus", "thunar", "nemo", "code", "codium", "obsidian", "spotify", "discord", "vesktop"];
        const out = [];
        for (const id of wanted) {
            const e = id ? DesktopEntries.byId(id) : null;
            if (e && out.indexOf(e.id) < 0) out.push(e.id);
            if (out.length >= 5) break;
        }
        return out;
    }

    function resolveId(id) {
        const s = String(id || "").replace(/\.desktop$/, "");
        if (!s) return "";
        const e = DesktopEntries.byId(s) || DesktopEntries.heuristicLookup(s);
        return e ? e.id : s;
    }

    function isPinned(key) { return pinned.indexOf(key) >= 0; }

    function pin(id, index) {
        const key = resolveId(id);
        if (!key) return false;
        const next = pinned.filter(k => k !== key);
        const at = index === undefined || index < 0 ? next.length : Math.min(index, next.length);
        next.splice(at, 0, key);
        store.set("pinned", next);
        return true;
    }

    function unpin(id) {
        const key = resolveId(id);
        const next = pinned.filter(k => k !== key && k !== id);
        if (next.length === pinned.length) return false;
        store.set("pinned", next);
        return true;
    }

    function movePinned(key, index) {
        const from = pinned.indexOf(key);
        if (from < 0) return pin(key, index);
        const next = pinned.slice();
        next.splice(from, 1);
        next.splice(Math.max(0, Math.min(index, next.length)), 0, key);
        if (next.join("\n") !== pinned.join("\n")) store.set("pinned", next);
        return true;
    }

    // ---- running windows ----
    readonly property var toplevels: ToplevelManager.toplevels.values

    function keyForAppId(appId) {
        const id = String(appId || "");
        if (!id) return "unknown";
        const e = DesktopEntries.heuristicLookup(id);
        return e ? e.id : id;
    }

    // key -> [Toplevel], in stable (open) order.
    readonly property var groups: {
        DesktopEntries.applications.values;
        const g = {};
        for (const t of toplevels) {
            if (!t) continue;
            const k = keyForAppId(t.appId);
            (g[k] = g[k] || []).push(t);
        }
        return g;
    }

    // Running (unpinned) keys keep the order in which they first appeared.
    property var runningOrder: []
    onGroupsChanged: {
        const live = Object.keys(groups);
        const next = runningOrder.filter(k => live.indexOf(k) >= 0);
        for (const k of live) if (next.indexOf(k) < 0) next.push(k);
        runningOrder = next;
        // A launch is "done" once the app maps a window.
        const l = Object.assign({}, launching);
        let changed = false;
        for (const k in l) if (groups[k]) { delete l[k]; changed = true; }
        if (changed) launching = l;
    }

    readonly property var pinnedKeys: pinned.filter(k => !runningOnly || !!groups[k])
    readonly property var runningKeys: runningOrder.filter(k => pinned.indexOf(k) < 0)
    // All app slots, pinned first.
    readonly property var keys: pinnedKeys.concat(runningKeys)
    readonly property int pinnedCount: pinnedKeys.length

    function windowsFor(key) { return groups[key] || []; }

    function entryFor(key) {
        DesktopEntries.applications.values;
        return DesktopEntries.byId(key) || DesktopEntries.heuristicLookup(key) || null;
    }

    function nameFor(key) {
        const e = entryFor(key);
        if (e && e.name) return e.name;
        const w = windowsFor(key)[0];
        return w && w.title ? w.title : key;
    }

    function iconFor(key) {
        const e = entryFor(key);
        return e && e.icon ? e.icon : key;
    }

    // Most-recently focused toplevels first.
    property var recent: []
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            const t = ToplevelManager.activeToplevel;
            if (!t) return;
            root.recent = [t].concat(root.recent.filter(x => x && x !== t && root.toplevels.indexOf(x) >= 0)).slice(0, 64);
        }
    }

    function isFocused(key) {
        return windowsFor(key).some(t => t.activated);
    }

    // Click behaviour: launch when not running, focus when in the background,
    // cycle through the app's windows when it already has focus.
    function activate(key) {
        const wins = windowsFor(key);
        if (!wins.length) return launch(key);
        const current = wins.findIndex(t => t.activated);
        if (current >= 0) {
            if (wins.length > 1) wins[(current + 1) % wins.length].activate();
            return true;
        }
        const byRecency = wins.slice().sort((a, b) => rank(a) - rank(b));
        byRecency[0].activate();
        return true;
    }

    function rank(t) {
        const i = recent.indexOf(t);
        return i < 0 ? 1e6 : i;
    }

    property var launching: ({})   // key -> timestamp
    signal launched(string key)

    function launch(key) {
        const e = entryFor(key);
        if (!e) return false;
        Apps.launch(e);
        const l = Object.assign({}, launching);
        l[key] = Date.now();
        launching = l;
        launchTimeout.restart();
        launched(key);
        return true;
    }

    function runAction(action) {
        if (action) Apps.run(action.command);
    }

    function closeAll(key) {
        for (const t of windowsFor(key).slice()) t.close();
    }

    Timer {
        id: launchTimeout
        interval: 10000
        onTriggered: root.launching = ({})
    }

    // ---- folder stack (Downloads by default) ----
    readonly property string defaultFolder: {
        const x = Quickshell.env("XDG_DOWNLOAD_DIR");
        return x ? x : `${Paths.home}/Downloads`;
    }
    readonly property string folderName: {
        const p = String(folder).replace(/\/+$/, "");
        return p.slice(p.lastIndexOf("/") + 1) || p;
    }
    property var files: []          // [{name, path, dir, mtime, size}] newest first
    property int fileTotal: 0
    property string folderError: ""
    property bool folderLoading: false
    readonly property int maxFiles: 12

    function refreshFolder() {
        if (!showFolder) return;
        folderLoading = true;
        lister.running = false;
        lister.running = true;
    }

    function openPath(path) {
        Quickshell.execDetached(["xdg-open", String(path)]);
    }

    Process {
        id: lister
        // Tab separated: mtime, type (d/f/l), size, name. Hidden files skipped.
        command: ["sh", "-c",
            'd="$1"; [ -d "$d" ] || { echo "!missing"; exit 0; }; ' +
            'find "$d" -mindepth 1 -maxdepth 1 ! -name ".*" -printf "%T@\\t%y\\t%s\\t%f\\n" 2>/dev/null ' +
            '| sort -rn -t "\t" -k1,1 | awk -v max="$2" \'NR<=max{print} END{print "#" NR}\'',
            "sh", root.folder, String(root.maxFiles)]
        stdout: StdioCollector {
            onStreamFinished: root.parseListing(text)
        }
        onExited: code => {
            root.folderLoading = false;
            if (code !== 0) root.folderError = "Couldn't read the folder";
        }
    }

    function parseListing(text) {
        const out = [];
        let total = 0;
        let error = "";
        for (const line of text.split("\n")) {
            if (!line) continue;
            if (line === "!missing") { error = "Folder not found"; continue; }
            if (line[0] === "#") { total = parseInt(line.slice(1)) || 0; continue; }
            const p = line.split("\t");
            if (p.length < 4) continue;
            const name = p.slice(3).join("\t");
            out.push({
                name: name,
                path: `${folder}/${name}`,
                dir: p[1] === "d",
                mtime: parseFloat(p[0]) * 1000,
                size: parseInt(p[2]) || 0
            });
        }
        folderError = error;
        files = out;
        fileTotal = total;
    }

    Timer {
        interval: 30000
        running: root.enabled && root.showFolder
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshFolder()
    }
    onFolderChanged: refreshFolder()

    // ---- persistence + IPC ----
    JsonStore {
        id: store
        name: "dock"
    }

    IpcHandler {
        target: "dock"
        function toggle(): void { root.setEnabled(!root.enabled); }
        function toggleAutohide(): void { root.setAutohide(!root.autohide); }
        function pin(id: string): void { root.pin(id); }
        function unpin(id: string): void { root.unpin(id); }
        function list(): string { return JSON.stringify({ pinned: root.pinned, running: root.runningKeys }); }
    }
}
