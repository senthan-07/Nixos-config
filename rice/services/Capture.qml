pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import qs.components

// Screenshot / OCR / colour-picker / screen-recording front-end.
//
// A capture "session" shows the region selector overlay (modules/capture) on
// every screen. The overlay freezes each output with a ScreencopyView, lets the
// user pick a region / window / screen and then hands the result back here:
//   - screenshot: the overlay crops the frozen frame into a PNG -> finishImage()
//   - ocr:        same, into a temp file -> tesseract -> clipboard
//   - pick:       the overlay reads the pixel -> finishPick()
//   - record:     finishRecord() -> Recording.startScreen()
//
// IPC: `qs -c rice ipc call capture <fn>` (see the IpcHandler at the bottom).
Singleton {
    id: root

    // ---- session state (read by the overlay) ----
    property bool active: false
    // "screenshot" | "ocr" | "pick" | "record"
    property string action: "screenshot"
    // "region" | "window" | "screen"
    property string mode: "region"
    // Screen (name) that owns the current selection, and the one the pointer is on.
    property string selScreen: ""
    property string pointerScreen: ""
    // Screen that receives exclusive keyboard focus when the overlay opens.
    property string focusScreen: ""
    // Visible Hyprland windows in global logical coordinates:
    // [{ x, y, w, h, title, appClass, floating, focus, monitor }]
    property var windows: []
    property bool windowsLoaded: false
    // Bumped every time a session starts so overlays can reset.
    property int session: 0
    // Overlay windows stay mapped while fading out.
    readonly property bool overlayShown: active || closing.running

    // ---- preferences ----
    readonly property bool recordAudio: store.get("recordAudio", false)
    readonly property string lastMode: store.get("mode", "region")
    readonly property string ocrLang: store.get("ocrLang", "eng")

    // ---- environment ----
    property var tools: ({})
    readonly property string screenshotDir: Quickshell.env("RICE_SCREENSHOT_DIR") || `${Paths.picturesDir}/Screenshots`
    readonly property string recordingDir: Quickshell.env("RICE_RECORDING_DIR")
        || `${Quickshell.env("XDG_VIDEOS_DIR") || Paths.home + "/Videos"}/Recordings`
    readonly property string tempDir: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/rice-capture`
    readonly property string hyprctl: Quickshell.env("RICE_HYPRCTL") || "hyprctl"
    readonly property bool hyprAvailable: !!Quickshell.env("RICE_HYPRCTL") || !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

    readonly property string focusedOutput: Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || ""

    function has(tool) {
        return tools[tool] === true;
    }

    // ------------------------------------------------------------ sessions

    function begin(action, mode) {
        if (action === "record" && Recording.active) {
            Recording.stop();
            return;
        }
        if (action === "ocr" && !has("tesseract") && toolsLoaded) {
            notifyError("Text recognition unavailable", "Install <b>tesseract</b> to copy text from the screen.");
            return;
        }
        if (closing.running) {
            // The previous overlay is still fading out; start once it is gone
            // so the new session gets a fresh frozen frame.
            pendingBegin = [action, mode];
            return;
        }
        root.action = action || "screenshot";
        root.mode = mode || root.lastMode;
        if (root.active) return;

        selScreen = "";
        focusScreen = focusedOutput;
        pointerScreen = focusedOutput;
        refreshWindows();
        refreshTools();
        ensureDirs();
        session++;
        active = true;
    }

    function cancel() {
        if (!active) return;
        active = false;
        closing.restart();
    }

    function setMode(m) {
        mode = m;
        if (m !== lastMode) store.set("mode", m);
    }

    function setAction(a) {
        if (a === "ocr" && toolsLoaded && !has("tesseract")) {
            notifyError("Text recognition unavailable", "Install <b>tesseract</b> to copy text from the screen.");
            return;
        }
        action = a;
    }

    function setAudio(on) {
        store.set("recordAudio", !!on);
    }

    // Close the overlay after a successful selection.
    function finish() {
        active = false;
        closing.restart();
    }

    // Called by the overlay with a PNG it cropped from the frozen frame.
    function finishImage(kind, path, width, height) {
        if (kind === "ocr")
            runOcr(path);
        else
            screenshotSaved(path, width, height);
    }

    // Fallback when the overlay could not freeze the output: grab with grim
    // after the overlay is gone. `g` is { x, y, w, h } in global logical px.
    function grimCapture(kind, g) {
        if (!has("grim")) {
            notifyError("Screenshot failed", "Screen capture is unavailable and <b>grim</b> is not installed.");
            return;
        }
        const path = kind === "ocr" ? `${tempDir}/ocr-${Date.now()}.png` : nextScreenshotPath();
        grimProc.kind = kind;
        grimProc.path = path;
        grimProc.size = [g.w, g.h];
        grimProc.command = ["grim", "-g", `${Math.round(g.x)},${Math.round(g.y)} ${Math.round(g.w)}x${Math.round(g.h)}`, path];
        grimDelay.restart();
    }

    function finishRecord(g, screenName, fullScreen) {
        pendingRecord = { geometry: `${Math.round(g.x)},${Math.round(g.y)} ${Math.round(g.w)}x${Math.round(g.h)}`,
            output: fullScreen ? screenName : "", size: [Math.round(g.w), Math.round(g.h)], audio: recordAudio };
        finish();
        // Let the overlay fade out and unmap before the recorder starts.
        recordDelay.restart();
    }

    function finishPick(hex, swatchPath) {
        copyText(hex);
        notify({
            app: "Colour picker",
            summary: hex.toUpperCase(),
            body: "Copied to the clipboard",
            icon: swatchPath || "",
            image: swatchPath || "",
            transient: true
        });
    }

    // Full screenshot of one output without the overlay (PrintScreen).
    function captureOutput(name) {
        if (!has("grim") && toolsLoaded) {
            notifyError("Screenshot failed", "<b>grim</b> is not installed.");
            return;
        }
        ensureDirs();
        const target = name || focusedOutput;
        const scr = Quickshell.screens.find(s => s.name === target);
        const path = nextScreenshotPath();
        grimProc.kind = "screenshot";
        grimProc.path = path;
        grimProc.size = scr ? [Math.round(scr.width * scr.devicePixelRatio), Math.round(scr.height * scr.devicePixelRatio)] : [0, 0];
        grimProc.command = target ? ["grim", "-o", target, path] : ["grim", path];
        grimDelay.restart();
    }

    // ------------------------------------------------------------ results

    property int shotCounter: 0
    property string lastShotStamp: ""
    function nextScreenshotPath() {
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        shotCounter = stamp === lastShotStamp ? shotCounter + 1 : 0;
        lastShotStamp = stamp;
        return `${screenshotDir}/Screenshot_${stamp}${shotCounter ? "_" + shotCounter : ""}.png`;
    }

    function screenshotSaved(path, width, height) {
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", path]);
        const actions = [["default", "Open"], ["open", "Open"]];
        if (has("satty") || has("swappy")) actions.push(["edit", "Edit"]);
        actions.push(["folder", "Show in folder"]);
        notify({
            app: "Screenshot",
            summary: "Screenshot saved",
            body: `${width} × ${height} · copied to the clipboard`,
            icon: path,
            image: path,
            file: path,
            actions: actions
        });
    }

    function runOcr(path) {
        if (!has("tesseract")) {
            notifyError("Text recognition unavailable", "Install <b>tesseract</b> to copy text from the screen.");
            return;
        }
        ocrProc.path = path;
        ocrProc.command = ["sh", "-c", 'tesseract "$1" stdout -l "$2" 2>/dev/null; rc=$?; rm -f "$1"; exit $rc', "sh", path, ocrLang];
        ocrProc.running = true;
    }

    function copyText(text) {
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", text]);
    }

    function escapeHtml(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // ------------------------------------------------------------ notifications

    // opts: { app, summary, body, icon, image, file, urgency, transient,
    //         actions: [[id, label]] }  — ids open/default/edit/folder act on `file`.
    function notify(opts) {
        if (!has("notify-send") && toolsLoaded) {
            console.warn("rice capture:", opts.summary, opts.body);
            return;
        }
        const args = ["-a", opts.app || "Capture"];
        if (opts.icon) args.push("-i", opts.icon);
        if (opts.image) args.push("-h", `string:image-path:${opts.image}`);
        if (opts.urgency) args.push("-u", opts.urgency);
        if (opts.transient) args.push("-e");
        for (const a of opts.actions || []) args.push("-A", `${a[0]}=${a[1]}`);
        args.push(opts.summary || "", opts.body || "");

        const editor = has("satty") ? 'satty --filename "$f" --output-filename "$f" --copy-command wl-copy --early-exit'
            : has("swappy") ? 'swappy -f "$f" -o "$f"' : 'xdg-open "$f"';
        const script = `f="$1"; shift
act=$(notify-send "$@") || exit 0
case "$act" in
  default|open) xdg-open "$f" ;;
  edit) ${editor} ;;
  folder) xdg-open "$(dirname "$f")" ;;
esac`;
        Quickshell.execDetached(["sh", "-c", script, "sh", opts.file || "", ...args]);
    }

    function notifyError(summary, body) {
        notify({ app: "Capture", summary: summary, body: body, urgency: "critical" });
    }

    // ------------------------------------------------------------ helpers

    function ensureDirs() {
        mkdirProc.command = ["mkdir", "-p", screenshotDir, recordingDir, tempDir];
        mkdirProc.running = true;
    }

    property bool toolsLoaded: false
    function refreshTools() {
        if (!toolsProc.running) toolsProc.running = true;
    }

    function refreshWindows() {
        windowsLoaded = false;
        if (!hyprAvailable) {
            windows = [];
            windowsLoaded = true;
            return;
        }
        clientsProc.running = false;
        clientsProc.running = true;
    }

    function parseWindows(text) {
        const parts = text.split("\u001e");
        let monitors = [], clients = [];
        try {
            monitors = JSON.parse(parts[0]);
            clients = JSON.parse(parts[1]);
        } catch (e) {
            console.warn("rice capture: could not parse hyprctl output");
            return [];
        }
        const visible = new Set();
        for (const m of monitors) {
            if (m.activeWorkspace) visible.add(m.activeWorkspace.id);
            if (m.specialWorkspace && m.specialWorkspace.id) visible.add(m.specialWorkspace.id);
        }
        const out = [];
        for (const c of clients) {
            if (!c || c.hidden || c.mapped === false || !c.at || !c.size) continue;
            if (!visible.has(c.workspace?.id)) continue;
            if (c.size[0] < 2 || c.size[1] < 2) continue;
            out.push({
                x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1],
                title: c.title || "", appClass: c.class || c.initialClass || "",
                floating: !!c.floating, fullscreen: !!c.fullscreen,
                focus: c.focusHistoryID ?? 99, monitor: c.monitor
            });
        }
        // Topmost first: fullscreen, then floating, then most recently focused.
        out.sort((a, b) => (b.fullscreen - a.fullscreen) || (b.floating - a.floating) || (a.focus - b.focus));
        return out;
    }

    // Topmost window containing a global point, or null.
    function windowAt(gx, gy) {
        for (const w of windows)
            if (gx >= w.x && gx < w.x + w.w && gy >= w.y && gy < w.y + w.h)
                return w;
        return null;
    }

    property var pendingRecord: null

    JsonStore {
        id: store
        name: "capture"
    }

    property var pendingBegin: null

    Timer {
        id: closing
        interval: Motion.duration.short + 60
        onTriggered: {
            const p = root.pendingBegin;
            root.pendingBegin = null;
            if (p) Qt.callLater(() => root.begin(p[0], p[1]));
        }
    }

    Timer {
        id: recordDelay
        interval: 350
        onTriggered: {
            const r = root.pendingRecord;
            root.pendingRecord = null;
            if (r) Recording.startScreen(r);
        }
    }

    Timer {
        id: grimDelay
        interval: root.overlayShown ? 350 : 10
        onTriggered: grimProc.running = true
    }

    Process {
        id: grimProc
        property string kind
        property string path
        property var size: [0, 0]
        stderr: StdioCollector { id: grimErr }
        onExited: code => {
            if (code !== 0) {
                root.notifyError("Screenshot failed", root.escapeHtml(grimErr.text.trim() || `grim exited with ${code}`));
                return;
            }
            root.finishImage(kind, path, size[0], size[1]);
        }
    }

    Process {
        id: ocrProc
        property string path
        stdout: StdioCollector { id: ocrOut }
        onExited: code => {
            const text = ocrOut.text.replace(/\f/g, "").trim();
            if (code !== 0) {
                root.notifyError("Text recognition failed", `tesseract exited with ${code}. Is the <b>${root.ocrLang}</b> language installed?`);
            } else if (!text) {
                root.notify({ app: "Text recognition", summary: "No text found", body: "Try selecting a larger or sharper area.", transient: true });
            } else {
                root.copyText(text);
                const preview = text.length > 160 ? text.slice(0, 160) + "…" : text;
                const words = text.split(/\s+/).filter(w => w).length;
                root.notify({ app: "Text recognition", summary: `Copied ${words} word${words === 1 ? "" : "s"}`, body: root.escapeHtml(preview), transient: true });
            }
        }
    }

    Process {
        id: mkdirProc
    }

    Process {
        id: toolsProc
        command: ["sh", "-c", "for b in grim wl-copy notify-send tesseract satty swappy wf-recorder gpu-screen-recorder pw-record pactl wpctl xdg-open hyprctl; do command -v \"$b\" >/dev/null 2>&1 && echo \"$b\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = {};
                for (const l of text.split("\n")) if (l.trim()) t[l.trim()] = true;
                root.tools = t;
                root.toolsLoaded = true;
            }
        }
    }

    Process {
        id: clientsProc
        command: ["sh", "-c", '"$1" -j monitors && printf "\\036" && "$1" -j clients', "sh", root.hyprctl]
        stdout: StdioCollector {
            onStreamFinished: {
                root.windows = text.includes("\u001e") ? root.parseWindows(text) : [];
                root.windowsLoaded = true;
            }
        }
        onExited: code => { if (code !== 0) { root.windows = []; root.windowsLoaded = true; } }
    }

    Component.onCompleted: {
        refreshTools();
        ensureDirs();
    }

    IpcHandler {
        target: "capture"

        // Interactive selector in the last used mode.
        function screenshot(): void { root.begin("screenshot", ""); }
        function region(): void { root.begin("screenshot", "region"); }
        function window(): void { root.begin("screenshot", "window"); }
        // Instant capture of the focused output, no selector.
        function screen(): void { root.captureOutput(""); }
        function ocr(): void { root.begin("ocr", "region"); }
        function pick(): void { root.begin("pick", "region"); }
        // Toggle a full-screen recording of the focused output.
        function record(): void {
            if (Recording.active) Recording.stop();
            else Recording.startScreen({ output: root.focusedOutput, audio: root.recordAudio });
        }
        function recordRegion(): void { root.begin("record", "region"); }
        function recordAudio(): void { Recording.active ? Recording.stop() : Recording.startAudio("system"); }
        function recordMic(): void { Recording.active ? Recording.stop() : Recording.startAudio("mic"); }
        function stop(): void {
            if (root.active) root.cancel();
            if (Recording.active) Recording.stop();
        }
        function cancel(): void { root.cancel(); }
        function setAudio(on: bool): void { root.setAudio(on); }
        function status(): string {
            return JSON.stringify({ selecting: root.active, action: root.action, mode: root.mode,
                recording: Recording.state, kind: Recording.kind, elapsed: Math.round(Recording.elapsed / 1000),
                output: Recording.outputPath });
        }
    }
}
