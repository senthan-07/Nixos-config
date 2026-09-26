pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backlight level of the first /sys/class/backlight device. Changes are
// written through brightnessctl (logind) and read back from sysfs.
Singleton {
    id: root

    property string device: ""
    property int max: 0
    property real value: 0
    readonly property bool available: device !== "" && max > 0

    signal changed()

    function set(v) {
        if (!available) return;
        const pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        Quickshell.execDetached(["brightnessctl", "-q", "set", `${pct}%`]);
        value = pct / 100;
        changed();
    }

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -e \"$d/brightness\" ] && echo \"$d\" && cat \"$d/max_brightness\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length >= 2) {
                    root.device = lines[0];
                    root.max = parseInt(lines[1]);
                }
            }
        }
    }

    FileView {
        id: current
        path: root.device ? `${root.device}/brightness` : ""
        onLoaded: {
            const next = parseInt(text()) / root.max;
            if (Math.abs(next - root.value) > 0.005) {
                const wasSet = root.value > 0;
                root.value = next;
                if (wasSet) root.changed();
            }
        }
    }

    // sysfs does not emit inotify events, so poll cheaply.
    Timer {
        running: root.available
        repeat: true
        interval: 1000
        onTriggered: current.reload()
    }

    IpcHandler {
        target: "brightness"
        function up(): void { root.set(root.value + 0.05); }
        function down(): void { root.set(root.value - 0.05); }
        function set(percent: int): void { root.set(percent / 100); }
    }
}
