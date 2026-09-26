pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen / audio recording state machine.
//
//   idle ──start──▶ starting ──(recorder alive)──▶ recording ──stop()──▶ stopping ──▶ idle
//                      │                              │                                ▲
//                      └──────(recorder died)─────────┴──────────▶ error ──(4 s)───────┘
//
// Screen: wf-recorder (preferred) or gpu-screen-recorder, optionally with the
// default sink's monitor as audio. Audio only: pw-record (system output or mic).
// Every recorder is stopped with SIGINT so it can finalise the container.
Singleton {
    id: root

    property string state: "idle"
    // "screen" | "audio"
    property string kind: "screen"
    // audio source for kind === "audio": "system" | "mic"
    property string source: "system"
    property bool withAudio: false
    property string backend: ""
    // Human readable target, e.g. "HEADLESS-1" or "1280 × 720 region".
    property string target: ""
    property string outputPath: ""
    property string error: ""
    property double startedAt: 0
    property double now: Date.now()

    readonly property bool active: state === "starting" || state === "recording" || state === "stopping"
    readonly property bool isRecording: state === "recording"
    readonly property double elapsed: startedAt > 0 && active ? Math.max(0, now - startedAt) : 0
    readonly property string elapsedText: format(elapsed)

    property bool stopRequested: false

    function format(ms) {
        const s = Math.floor(ms / 1000);
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
        const pad = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${pad(m)}:${pad(sec)}` : `${pad(m)}:${pad(sec)}`;
    }

    function stamp() {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
    }

    // opts: { geometry: "x,y WxH" (global logical), output: name, size: [w, h], audio: bool }
    // A non-empty `output` records the whole output, otherwise `geometry`.
    function startScreen(opts) {
        if (active) return false;
        const o = opts || {};
        kind = "screen";
        const wf = Capture.has("wf-recorder"), gsr = Capture.has("gpu-screen-recorder");
        if (!wf && !gsr) {
            fail("Install <b>wf-recorder</b> (or gpu-screen-recorder) to record the screen.");
            return false;
        }
        kind = "screen";
        withAudio = !!o.audio;
        backend = wf ? "wf-recorder" : "gpu-screen-recorder";
        target = o.output ? o.output : `${o.size?.[0] ?? "?"} × ${o.size?.[1] ?? "?"} region`;
        outputPath = `${Capture.recordingDir}/Recording_${stamp()}.mp4`;

        // Region in gpu-screen-recorder syntax: WxH+X+Y
        let gsrRegion = "";
        const m = /^(-?\d+),(-?\d+) (\d+)x(\d+)$/.exec(o.geometry || "");
        if (m) gsrRegion = `${m[3]}x${m[4]}+${m[1]}+${m[2]}`;

        const script = `out="$1"; geo="$2"; mon="$3"; audio="$4"; backend="$5"; region="$6"
mkdir -p "$(dirname "$out")" || exit 1
sink=""
if [ "$audio" = 1 ]; then
  sink=$(pactl get-default-sink 2>/dev/null)
  [ -z "$sink" ] && sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | sed -n 's/.*node\\.name = "\\(.*\\)".*/\\1/p' | head -n1)
fi
if [ "$backend" = wf-recorder ]; then
  set -- wf-recorder -y -f "$out"
  if [ -n "$mon" ]; then set -- "$@" -o "$mon"; else set -- "$@" -g "$geo"; fi
  if [ "$audio" = 1 ]; then
    if [ -n "$sink" ]; then set -- "$@" --audio="$sink.monitor"; else set -- "$@" --audio; fi
  fi
else
  if [ -n "$mon" ]; then set -- gpu-screen-recorder -w "$mon"; else set -- gpu-screen-recorder -w region -region "$region"; fi
  set -- "$@" -f 60 -o "$out"
  [ "$audio" = 1 ] && set -- "$@" -a default_output
fi
exec "$@"`;
        launch(["sh", "-c", script, "sh", outputPath, o.geometry || "", o.output || "", withAudio ? "1" : "0", backend, gsrRegion]);
        return true;
    }

    // source: "system" (what you hear) | "mic"
    function startAudio(src) {
        if (active) return false;
        kind = "audio";
        if (!Capture.has("pw-record")) {
            fail("Install <b>pipewire</b> (pw-record) to record audio.");
            return false;
        }
        kind = "audio";
        source = src === "mic" ? "mic" : "system";
        withAudio = true;
        backend = "pw-record";
        target = source === "mic" ? "Microphone" : "System audio";
        outputPath = `${Capture.recordingDir}/${source === "mic" ? "Voice" : "Audio"}_${stamp()}.flac`;
        const script = `out="$1"; mkdir -p "$(dirname "$out")" || exit 1
if [ "$2" = system ]; then exec pw-record -P '{ stream.capture.sink = true }' "$out"; else exec pw-record "$out"; fi`;
        launch(["sh", "-c", script, "sh", outputPath, source]);
        return true;
    }

    function stop() {
        if (state === "starting") {
            stopRequested = true;
            return;
        }
        if (state !== "recording") return;
        state = "stopping";
        proc.signal(2);   // SIGINT: let the recorder finalise the file
        killTimer.restart();
    }

    function toggle() {
        if (active) stop();
        else startScreen({ output: Capture.focusedOutput, audio: Capture.recordAudio });
    }

    function launch(cmd) {
        error = "";
        stopRequested = false;
        stderrTail = [];
        stderrErrors = [];
        startedAt = 0;
        state = "starting";
        proc.command = cmd;
        proc.running = true;
    }

    function fail(msg) {
        error = msg;
        state = "error";
        errorReset.restart();
        Capture.notifyError(kind === "audio" ? "Audio recording failed" : "Screen recording failed", msg);
    }

    property var stderrTail: []
    property var stderrErrors: []

    // The most relevant recorder output for an error message.
    function errorDetail() {
        const lines = stderrErrors.length ? stderrErrors.slice(-2) : stderrTail.slice(-2);
        return lines.map(l => Capture.escapeHtml(l.length > 140 ? l.slice(0, 140) + "…" : l)).join("<br>");
    }

    Process {
        id: proc
        onStarted: armTimer.restart()
        stderr: SplitParser {
            onRead: line => {
                const t = line.trim();
                if (!t) return;
                // wf-recorder/ffmpeg print progress with carriage returns; keep a short tail.
                const last = t.split("\r").pop();
                root.stderrTail = [...root.stderrTail.slice(-5), last];
                if (/error|fail|unable|cannot|could not|denied|invalid|no such/i.test(last))
                    root.stderrErrors = [...root.stderrErrors.slice(-3), last];
            }
        }
        onExited: code => {
            armTimer.stop();
            killTimer.stop();
            const wasStopping = root.state === "stopping";
            const wasRecording = root.state === "recording";
            if (root.state === "starting") {
                const detail = root.errorDetail();
                root.fail(`${root.backend} exited immediately (code ${code}).${detail ? "<br>" + detail : ""}`);
                return;
            }
            if (wasStopping || wasRecording) {
                verify.duration = root.elapsed;
                verify.unexpected = wasRecording;
                verify.detail = root.errorDetail();
                verify.exitCode = code;
                root.state = "stopping";
                // A valid file is more than a bare container header; drop broken leftovers.
                verify.command = ["sh", "-c", 's=$(stat -c %s "$1" 2>/dev/null || echo 0); [ "$s" -gt 512 ] && exit 0; rm -f "$1"; exit 1', "sh", root.outputPath];
                verify.running = true;
            }
        }
    }

    // A recorder that survives this long is considered started.
    Timer {
        id: armTimer
        interval: 600
        onTriggered: {
            if (!proc.running) return;
            root.startedAt = Date.now() - interval;
            root.state = "recording";
            if (root.stopRequested) root.stop();
        }
    }

    // Escalate if the recorder ignores SIGINT.
    Timer {
        id: killTimer
        interval: 8000
        onTriggered: if (proc.running) proc.signal(15)
    }

    Process {
        id: verify
        property double duration: 0
        property bool unexpected: false
        property string detail
        property int exitCode: 0
        onExited: code => {
            const path = root.outputPath;
            if (code !== 0) {
                root.fail(unexpected
                    ? `${root.backend} stopped unexpectedly (code ${exitCode}).${detail ? "<br>" + detail : ""}`
                    : `The recording could not be saved to ${Capture.escapeHtml(path)}.`);
                return;
            }
            if (unexpected)
                console.warn("rice recording:", root.backend, "exited on its own with code", exitCode);
            root.state = "idle";
            root.startedAt = 0;
            const isAudio = root.kind === "audio";
            Capture.notify({
                app: isAudio ? "Audio recorder" : "Screen recorder",
                summary: isAudio ? "Audio recording saved" : "Screen recording saved",
                body: `${root.format(duration)} · ${Capture.escapeHtml(path.split("/").pop())}`,
                file: path,
                actions: [["default", "Open"], ["open", "Open"], ["folder", "Show in folder"]]
            });
        }
    }

    Timer {
        id: errorReset
        interval: 4000
        onTriggered: if (root.state === "error") root.state = "idle"
    }

    Timer {
        interval: 250
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }
}
