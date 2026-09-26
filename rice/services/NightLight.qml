pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// Night light through hyprsunset. Either always on while `enabled`, or, with
// `scheduled`, only between `from` and `to` (local "HH:mm", may cross midnight).
// Temperature changes are sent to the running hyprsunset over hyprctl, so
// dragging a slider doesn't restart it. If hyprsunset is already running
// (started by the user) we drive that instance instead of spawning our own.
//
// Persisted in $XDG_STATE_HOME/rice/nightlight.json.
Singleton {
    id: root

    readonly property bool enabled: store.get("enabled", false)
    readonly property int temperature: store.get("temperature", 4000)
    readonly property bool scheduled: store.get("scheduled", false)
    readonly property string from: store.get("from", "20:00")
    readonly property string to: store.get("to", "07:00")

    readonly property int minTemperature: 1500
    readonly property int maxTemperature: 6500

    readonly property bool inWindow: {
        const now = clock.date;
        const m = now.getHours() * 60 + now.getMinutes();
        const a = minutes(from), b = minutes(to);
        if (a === b) return true;
        return a < b ? (m >= a && m < b) : (m >= a || m < b);
    }
    // Whether the screen should be tinted right now.
    readonly property bool active: enabled && (!scheduled || inWindow)
    readonly property bool live: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    property bool external: false
    property string error: ""

    function toggle() { store.set("enabled", !enabled); }
    function setEnabled(on) { store.set("enabled", !!on); }
    function setTemperature(k) {
        store.set("temperature", Math.round(Math.max(minTemperature, Math.min(maxTemperature, Number(k) || 4000))));
    }
    function setSchedule(on, fromTime, toTime) {
        const next = Object.assign({}, store.data);
        next.scheduled = !!on;
        if (valid(fromTime)) next.from = normalize(fromTime);
        if (valid(toTime)) next.to = normalize(toTime);
        for (const k in next) if (store.data[k] !== next[k]) store.set(k, next[k]);
    }

    function valid(t) { return /^([01]?\d|2[0-3]):[0-5]\d$/.test(String(t || "")); }
    function normalize(t) {
        const [h, m] = String(t).split(":");
        return `${h.padStart(2, "0")}:${m}`;
    }
    function minutes(t) {
        if (!valid(t)) return 0;
        const [h, m] = t.split(":").map(Number);
        return h * 60 + m;
    }

    // Warm tint preview for UIs (approximate blackbody colour of `k`).
    function kelvinColor(k) {
        const t = k / 100;
        const r = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592);
        const g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -0.0755148492);
        const b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
        const c = v => Math.max(0, Math.min(255, v)) / 255;
        return Qt.rgba(c(r), c(g), c(b), 1);
    }

    function apply() {
        if (!live) return;
        if (active) {
            if (sunset.running || external)
                Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(temperature)]);
            else
                probe.running = true;
        } else {
            if (sunset.running) sunset.running = false;
            if (external) Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
        }
    }

    onActiveChanged: apply()
    onTemperatureChanged: pushTemp.restart()
    Component.onCompleted: if (active) apply()
    Component.onDestruction: if (sunset.running) sunset.running = false

    Timer {
        id: pushTemp
        interval: 120
        onTriggered: if (root.active) root.apply()
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    JsonStore {
        id: store
        name: "nightlight"
    }

    // Is someone else's hyprsunset already running?
    Process {
        id: probe
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: code => {
            root.external = code === 0;
            if (!root.active) return;
            if (root.external)
                Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(root.temperature)]);
            else
                sunset.running = true;
        }
    }

    Process {
        id: sunset
        command: ["hyprsunset", "-t", String(root.temperature)]
        stderr: StdioCollector {
            id: sunsetErr
        }
        onRunningChanged: if (running) root.error = ""
        onExited: code => {
            if (root.active && code !== 0) {
                root.error = sunsetErr.text.trim().split("\n").pop() || `hyprsunset exited with ${code}`;
                console.warn("rice: night light:", root.error);
            }
        }
    }

    IpcHandler {
        target: "nightlight"
        function toggle(): void { root.toggle(); }
        function enable(): void { root.setEnabled(true); }
        function disable(): void { root.setEnabled(false); }
        function setTemperature(kelvin: int): void { root.setTemperature(kelvin); }
        function schedule(from: string, to: string): void { root.setSchedule(true, from, to); }
        function unschedule(): void { root.setSchedule(false, "", ""); }
        function status(): string {
            return JSON.stringify({
                enabled: root.enabled, active: root.active, temperature: root.temperature,
                scheduled: root.scheduled, from: root.from, to: root.to, error: root.error
            });
        }
    }
}
