pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Audio visualiser backed by `cava` in raw ASCII mode. Consumers call
// acquire(token) while they are on screen and release(token) afterwards; cava
// only runs while at least one consumer is visible and the active player is
// playing. `values` holds `bars` levels in 0..1.
//
// If cava is missing or cannot open an audio input, `live` stays false and
// `values` falls back to a gentle synthetic motion while music plays, so the
// UI never shows frozen bars.
Singleton {
    id: root

    property int bars: 16
    property int framerate: 60
    // cava input method: "pipewire", "pulse", "alsa", "fifo"...
    property string method: "pipewire"
    property string inputSource: "auto"

    property var _owners: ({})
    readonly property int consumers: Object.keys(_owners).length
    readonly property bool playing: Media.active?.isPlaying ?? false
    readonly property bool wanted: consumers > 0 && playing

    property var values: zeros()
    property bool live: false          // real data is flowing from cava
    property bool failed: false        // cava exited with an error; stop retrying until playback restarts
    property int _lastFrame: 0

    readonly property string configPath: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/rice-cava-${bars}.conf`

    function zeros() {
        const a = [];
        for (let i = 0; i < bars; i++) a.push(0);
        return a;
    }

    function acquire(token) {
        if (!token || _owners[token]) return;
        const next = Object.assign({}, _owners);
        next[token] = true;
        _owners = next;
    }

    function release(token) {
        if (!token || !_owners[token]) return;
        const next = Object.assign({}, _owners);
        delete next[token];
        _owners = next;
    }

    function config() {
        return [
            "[general]", `bars = ${bars}`, `framerate = ${framerate}`, "autosens = 1", "sleep_timer = 0",
            "[input]", `method = ${method}`, `source = ${inputSource}`,
            "[output]", "method = raw", "channels = mono", "mono_option = average",
            "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 1000",
            "bar_delimiter = 59", "frame_delimiter = 10",
            "[smoothing]", "noise_reduction = 70", ""
        ].join("\n");
    }

    onPlayingChanged: if (playing) failed = false
    onWantedChanged: if (!wanted) { live = false; values = zeros(); }
    onBarsChanged: values = zeros()

    Process {
        id: cava
        running: root.wanted && !root.failed
        command: ["sh", "-c", 'printf "%s" "$1" > "$2" && exec cava -p "$2"', "sh", root.config(), root.configPath]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";");
                const out = new Array(root.bars);
                for (let i = 0; i < root.bars; i++) {
                    const n = parseInt(parts[i]);
                    out[i] = isFinite(n) ? Math.min(1, n / 1000) : 0;
                }
                root.values = out;
                root.live = true;
                root._lastFrame = Date.now();
            }
        }
        onExited: code => {
            root.live = false;
            if (root.wanted && code !== 0) {
                console.info(`rice: cava exited (${code}); using synthetic spectrum`);
                root.failed = true;
            }
        }
    }

    // Synthetic fallback: layered sines, smoothed so it looks organic.
    Timer {
        interval: 50
        repeat: true
        running: root.wanted && !root.live
        onTriggered: {
            const t = Date.now() / 1000;
            const out = new Array(root.bars);
            for (let i = 0; i < root.bars; i++) {
                const f = i / Math.max(1, root.bars - 1);
                const beat = Math.pow(Math.max(0, Math.sin(t * 7.5)), 6) * (1 - f) * 0.5;
                const v = 0.22 + 0.2 * Math.sin(t * (2.1 + f * 3.3) + i * 1.7)
                    + 0.14 * Math.sin(t * (5.3 - f * 2) + i * 0.6) + beat;
                const prev = root.values[i] ?? 0;
                out[i] = prev + (Math.max(0.04, Math.min(1, v)) - prev) * 0.45;
            }
            root.values = out;
        }
    }
}
