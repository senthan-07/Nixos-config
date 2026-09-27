pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// State machine for the dynamic island plus its IPC target ("island").
//
// Priority of what the pill shows (highest first):
//   hub (expanded, user-opened) > osd (volume/brightness change)
//   > notification preview > media (playing) > timer (pomodoro) > idle
Singleton {
    id: root

    // ---- Preferences (persisted in $XDG_STATE_HOME/rice/island.json) ----
    readonly property bool enabled: store.get("enabled", true)
    readonly property bool showOsd: store.get("osd", true)
    readonly property bool showNotifications: store.get("notifications", true)
    readonly property bool showMedia: store.get("media", true)
    readonly property bool compactLyrics: store.get("compactLyrics", false)
    // "brief": pop up for a few seconds on track changes / play / pause.
    // "always": stay while something is playing.
    readonly property string mediaStyle: store.get("mediaStyle", "brief")

    function setEnabled(v) { store.set("enabled", !!v); }
    function setShowOsd(v) { store.set("osd", !!v); }
    function setShowNotifications(v) { store.set("notifications", !!v); }
    function setShowMedia(v) { store.set("media", !!v); }
    function setCompactLyrics(v) { store.set("compactLyrics", !!v); }
    function setMediaStyle(v) { store.set("mediaStyle", v === "always" ? "always" : "brief"); }

    // True while the island is taking over the plain OSD / notification popups,
    // so modules/osd and modules/notifications can stay hidden.
    // (Not while the hub is open or the session is locked: the island can't
    // show them then, so the regular popups should.)
    readonly property bool replacesOsd: enabled && showOsd && mode !== "hub" && !Panels.locked
    readonly property bool replacesNotifications: enabled && showNotifications && mode !== "hub" && !Panels.locked

    // ---- Screen --------------------------------------------------------
    readonly property string screenName: Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? ""

    // ---- Hub -----------------------------------------------------------
    property bool expanded: false
    property string tab: "media"          // "media" | "focus" | "tools" | "notifications"
    readonly property var tabs: ["media", "focus", "tools", "notifications"]

    function open(which) {
        if (!enabled || Panels.locked) return;
        if (which && tabs.includes(which)) tab = which;
        else if (!expanded) tab = Media.active ? "media" : "focus";
        Panels.closeAll();
        expanded = true;
    }

    function close() { expanded = false; }

    function toggle(which) {
        if (expanded && (!which || which === tab)) close();
        else open(which);
    }

    function cycleTab(step) {
        tab = tabs[(tabs.indexOf(tab) + step + tabs.length) % tabs.length];
    }

    // ---- OSD -----------------------------------------------------------
    property string osdKind: ""           // "volume" | "brightness" | "mic"
    readonly property bool osdActive: osdKind !== "" && showOsd

    function showOsdFor(kind) {
        if (!enabled || !showOsd) return;
        osdKind = kind;
        osdTimer.restart();
    }

    function holdOsd() { osdTimer.restart(); }

    Timer {
        id: osdTimer
        interval: 1600
        onTriggered: root.osdKind = ""
    }

    Connections {
        target: Audio
        function onChanged() { root.showOsdFor("volume"); }
    }

    Connections {
        target: Brightness
        function onChanged() { root.showOsdFor("brightness"); }
    }

    // ---- Notifications -------------------------------------------------
    readonly property var notification: enabled && showNotifications && !Notifs.dnd && Notifs.popups.length > 0 ? Notifs.popups[0] : null
    readonly property int pendingNotifications: Notifs.popups.length

    // ---- Media ---------------------------------------------------------
    readonly property var player: Media.active
    property bool mediaRecent: false      // keeps the pill briefly after pausing
    property bool mediaFlash: false       // "brief" style: shown for a few seconds
    readonly property bool mediaActive: showMedia && player !== null && (mediaStyle === "always"
        ? ((player?.isPlaying ?? false) || mediaRecent)
        : mediaFlash)

    function flashMedia() {
        mediaFlash = true;
        mediaFlashTimer.restart();
    }

    onPlayerChanged: if (player?.isPlaying) flashMedia()

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onIsPlayingChanged() {
            if (!root.player.isPlaying) { root.mediaRecent = true; mediaGrace.restart(); }
            root.flashMedia();
        }
        function onTrackTitleChanged() { if (root.player.trackTitle) root.flashMedia(); }
    }

    Timer {
        id: mediaFlashTimer
        interval: 5000
        onTriggered: root.mediaFlash = false
    }

    Timer {
        id: mediaGrace
        interval: 4000
        onTriggered: root.mediaRecent = false
    }

    // ---- Timers --------------------------------------------------------
    readonly property bool timerActive: Timers.pomodoroRunning

    // ---- Resulting mode ------------------------------------------------
    readonly property string mode: !enabled || Panels.locked ? "idle"
        : expanded ? "hub"
        : osdActive ? "osd"
        : notification ? "notification"
        : mediaActive ? "media"
        : timerActive ? "timer"
        : "idle"

    onModeChanged: if (mode !== "hub" && expanded) expanded = false

    Connections {
        target: Panels
        function onLauncherChanged() { if (Panels.launcher) root.close(); }
        function onSidebarChanged() { if (Panels.sidebar) root.close(); }
        function onPowerChanged() { if (Panels.power) root.close(); }
        function onLockedChanged() { if (Panels.locked) root.close(); }
    }

    // ---- Tools ---------------------------------------------------------
    // Each tool runs a shell command. Commands that talk to the shell use
    // `qs -p <this config> ipc call ...` so they work both for the installed
    // `rice` config and a dev checkout.
    readonly property string ipcPrefix: `qs -p '${Quickshell.shellDir}' ipc call`
    readonly property var tools: [
        { id: "screenshot", icon: "screenshot_monitor", label: "Screenshot", hint: "Focused screen", cmd: `${ipcPrefix} capture screen` },
        { id: "region", icon: "screenshot_region", label: "Region", hint: "Select an area", cmd: `${ipcPrefix} capture region` },
        { id: "record", icon: "screen_record", label: "Record", hint: "Start / stop", cmd: `${ipcPrefix} capture record` },
        { id: "picker", icon: "colorize", label: "Colour", hint: "Pick from screen", cmd: `${ipcPrefix} capture pick` },
        { id: "ocr", icon: "document_scanner", label: "Text", hint: "Copy text (OCR)", cmd: `${ipcPrefix} capture ocr` },
        { id: "clipboard", icon: "content_paste", label: "Clipboard", hint: "History", cmd: `${ipcPrefix} launcher clipboard` }
    ]

    function runTool(id) {
        const t = tools.find(x => x.id === id);
        if (!t) return false;
        close();
        // Let the island collapse before a screenshot is taken.
        Quickshell.execDetached(["sh", "-c", `sleep 0.3; ${t.cmd}`]);
        return true;
    }

    JsonStore {
        id: store
        name: "island"
    }

    IpcHandler {
        target: "island"

        function toggle(): void { root.toggle(""); }
        function open(tab: string): void { root.open(tab); }
        function notifications(): void { root.toggle("notifications"); }
        function close(): void { root.close(); }
        function media(): void { root.toggle("media"); }
        function timer(): void { root.toggle("focus"); }
        function tools(): void { root.toggle("tools"); }
        function tool(id: string): string { return root.runTool(id) ? "ok" : "unknown tool"; }
        function pomodoro(): void { Timers.toggle(); }
        function lyrics(): void { root.setCompactLyrics(!root.compactLyrics); }
        function mediaStyle(style: string): void { root.setMediaStyle(style); }   // brief | always
        function osd(kind: string): void { root.showOsdFor(kind || "volume"); }
        function enable(on: bool): void { root.setEnabled(on); }
        function mode(): string { return root.mode; }
    }
}
