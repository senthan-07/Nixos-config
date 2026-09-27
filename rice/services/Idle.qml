pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components

// Idle policy: lock, then turn the screens off, then (optionally) suspend.
// Every stage is a separate ext-idle-notify monitor, so they time out
// independently and all reset on input. Paused while caffeine is on
// (Panels.caffeine), which also holds an idle inhibitor from the bar.
// Also locks the screen before the system goes to sleep (logind PrepareForSleep).
//
// Persisted in $XDG_STATE_HOME/rice/idle.json. Times are seconds, 0 = never.
Singleton {
    id: root

    readonly property bool enabled: store.get("enabled", true)
    readonly property int lockAfter: store.get("lockAfter", 300)
    readonly property int screenOffAfter: store.get("screenOffAfter", 600)
    readonly property int suspendAfter: store.get("suspendAfter", 0)
    readonly property bool lockBeforeSleep: store.get("lockBeforeSleep", true)

    readonly property bool paused: Panels.caffeine
    readonly property bool screensOff: screenOff.isIdle && screenOff.enabled
    readonly property bool idle: lock.isIdle || screenOff.isIdle || suspend.isIdle
    // Hyprland-only side effects (dpms, sleep inhibitor) are skipped elsewhere.
    readonly property bool live: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

    // Presets offered by settings UIs, in seconds.
    readonly property var presets: [0, 60, 120, 180, 300, 600, 900, 1800, 3600]

    function setEnabled(on) { store.set("enabled", !!on); }
    function setLockAfter(s) { store.set("lockAfter", clamp(s)); }
    function setScreenOffAfter(s) { store.set("screenOffAfter", clamp(s)); }
    function setSuspendAfter(s) { store.set("suspendAfter", clamp(s)); }
    function setLockBeforeSleep(on) { store.set("lockBeforeSleep", !!on); }

    function clamp(s) {
        const n = Math.round(Number(s) || 0);
        return Math.max(0, Math.min(86400, n));
    }

    // "5 min", "1 h", "Never" for settings rows.
    function label(s) {
        if (!s) return "Never";
        if (s < 60) return `${s} s`;
        if (s < 3600) return `${Math.round(s / 60)} min`;
        const h = s / 3600;
        return `${Number.isInteger(h) ? h : h.toFixed(1)} h`;
    }

    function lockNow() {
        console.info("rice idle: locking");
        if (Panels.locked) return;
        Panels.closeAll();
        Panels.locked = true;
    }

    function setDpms(on) {
        if (!live) return;
        const state = on ? "on" : "off";
        // Lua config first, then the classic dispatcher as a fallback.
        Quickshell.execDetached(["sh", "-c",
            `[ "$(hyprctl dispatch 'hl.dsp.dpms({ action = "${state}" })' 2>&1)" = ok ] || hyprctl dispatch dpms ${state}`]);
    }

    function suspendNow() {
        if (!live) return;
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    // Quickshell applies an IdleMonitor's timeout when it starts watching, so a
    // changed timeout only takes effect after re-arming: briefly disable all
    // monitors whenever any timing changes.
    property bool rearming: false
    function rearm() {
        rearming = true;
        Qt.callLater(() => rearming = false);
    }
    onLockAfterChanged: rearm()
    onScreenOffAfterChanged: rearm()
    onSuspendAfterChanged: rearm()

    function monitorOn(seconds) {
        return root.enabled && !root.paused && !root.rearming && seconds > 0;
    }

    JsonStore {
        id: store
        name: "idle"
    }

    IdleMonitor {
        id: lock
        enabled: root.monitorOn(root.lockAfter)
        timeout: Math.max(1, root.lockAfter)
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lockNow()
    }

    IdleMonitor {
        id: screenOff
        enabled: root.monitorOn(root.screenOffAfter)
        timeout: Math.max(1, root.screenOffAfter)
        respectInhibitors: true
        onIsIdleChanged: {
            console.info(`rice idle: screen ${isIdle ? "off" : "on"}`);
            root.setDpms(!isIdle);
        }
    }

    IdleMonitor {
        id: suspend
        enabled: root.monitorOn(root.suspendAfter)
        timeout: Math.max(1, root.suspendAfter)
        respectInhibitors: true
        onIsIdleChanged: {
            if (!isIdle) return;
            // Lock first so the machine never wakes up unlocked.
            console.info("rice idle: suspending");
            root.lockNow();
            root.suspendNow();
        }
    }

    // Caffeine switched on while the screens were off: bring them back.
    onPausedChanged: if (paused) setDpms(true)

    // ---- lock before sleep -------------------------------------------------
    // A logind "delay" inhibitor gives us up to InhibitDelayMaxSec to lock when
    // PrepareForSleep(true) arrives; it is released once the lock is up and
    // taken again after resume.
    readonly property bool sleepHookActive: live && lockBeforeSleep
    onSleepHookActiveChanged: inhibitor.running = sleepHookActive

    Process {
        id: sleepWatch
        running: root.sleepHookActive
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
            "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                if (!line.includes("PrepareForSleep")) return;
                if (line.includes("true")) {
                    root.lockNow();
                    release.restart();
                } else {
                    inhibitor.running = root.sleepHookActive;
                }
            }
        }
        onExited: if (root.sleepHookActive) rewatch.restart()
    }

    Timer {
        id: rewatch
        interval: 5000
        onTriggered: sleepWatch.running = root.sleepHookActive
    }

    Process {
        id: inhibitor
        running: root.sleepHookActive
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=rice",
            "--why=Lock the screen before sleeping", "sleep", "infinity"]
    }

    // Give the lock surface a moment to map before letting the system sleep.
    Timer {
        id: release
        interval: 600
        onTriggered: inhibitor.running = false
    }

    IpcHandler {
        target: "idle"
        function enable(): void { root.setEnabled(true); }
        function disable(): void { root.setEnabled(false); }
        function toggle(): void { root.setEnabled(!root.enabled); }
        function setLockAfter(seconds: int): void { root.setLockAfter(seconds); }
        function setScreenOffAfter(seconds: int): void { root.setScreenOffAfter(seconds); }
        function setSuspendAfter(seconds: int): void { root.setSuspendAfter(seconds); }
        function status(): string {
            return JSON.stringify({
                enabled: root.enabled, paused: root.paused, idle: root.idle,
                lockAfter: root.lockAfter, screenOffAfter: root.screenOffAfter,
                suspendAfter: root.suspendAfter, lockBeforeSleep: root.lockBeforeSleep
            });
        }
    }
}
