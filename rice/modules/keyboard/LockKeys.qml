pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Caps Lock / Num Lock state from the keyboard LEDs in sysfs. Any keyboard
// with its LED lit counts. A single bash loop polls with builtins only (no
// fork per tick) and prints a line only when something changed.
Singleton {
    id: root

    property bool available: false
    property bool capsLock: false
    property bool numLock: false
    // False until the first reading, so the OSD doesn't fire at startup.
    property bool ready: false

    signal toggled(string key, bool on)

    readonly property string script: `
        shopt -s nullglob
        exec 9<> <(:)
        prev=
        while :; do
            c=0; n=0; any=0
            for f in /sys/class/leds/*::capslock/brightness; do any=1; read -r v < "$f" && [ "\${v:-0}" != 0 ] && c=1; done
            for f in /sys/class/leds/*::numlock/brightness; do any=1; read -r v < "$f" && [ "\${v:-0}" != 0 ] && n=1; done
            s="$any $c $n"
            [ "$s" != "$prev" ] && { echo "$s"; prev=$s; }
            read -r -t 0.25 -u 9
        done`

    Process {
        id: poll
        running: true
        command: ["bash", "-c", root.script]
        stdout: SplitParser {
            onRead: line => {
                const [any, caps, num] = line.trim().split(" ").map(v => v === "1");
                root.available = any;
                if (root.ready && caps !== root.capsLock) root.toggled("caps", caps);
                if (root.ready && num !== root.numLock) root.toggled("num", num);
                root.capsLock = caps;
                root.numLock = num;
                root.ready = true;
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 3000
        onTriggered: poll.running = true
    }
}
