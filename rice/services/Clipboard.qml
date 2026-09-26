pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history backed by cliphist.
// Capture needs a watcher running in the session:
//   wl-paste --type text --watch cliphist store
//   wl-paste --type image --watch cliphist store
// Entries: { id, line, text, image, binary, format, size, width, height }
Singleton {
    id: root

    property bool available: true       // cliphist found on PATH
    property string state: "idle"       // idle | loading | ready | error
    property string error: ""
    property var entries: []
    property bool busy: copyProc.running || removeProc.running || wipeProc.running

    // Decoded payloads, keyed by entry id.
    property var images: ({})           // id -> absolute file path
    property var texts: ({})            // id -> { text, truncated }
    readonly property int textLimit: 262144

    readonly property string cacheDir: `${Quickshell.cacheDir}/cliphist`

    signal copied(string id)
    signal failed(string message)

    function refresh() {
        if (!available) {
            state = "error";
            return;
        }
        if (listProc.running) return;
        if (!entries.length) state = "loading";
        listProc.running = true;
    }

    function parse(text) {
        const out = [];
        for (const line of text.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab <= 0) continue;
            const id = line.slice(0, tab);
            const preview = line.slice(tab + 1);
            const img = /^\[\[ binary data (.+?) (png|jpe?g|gif|webp|bmp|tiff?|svg\+?x?m?l?) (\d+)x(\d+) \]\]$/i.exec(preview);
            const bin = !img && /^\[\[ binary data (.+?)( \w+)? \]\]$/.exec(preview);
            out.push({
                id: id,
                line: line,
                text: img || bin ? "" : preview,
                image: !!img,
                binary: !!bin,
                format: img ? img[2].toLowerCase() : "",
                size: img ? img[1] : bin ? bin[1] : "",
                width: img ? +img[3] : 0,
                height: img ? +img[4] : 0
            });
        }
        return out;
    }

    function copy(entry) {
        if (!entry || copyProc.running) return false;
        copyProc.entryId = entry.id;
        copyProc.command = ["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", entry.line];
        copyProc.running = true;
        return true;
    }

    function remove(entry) {
        if (!entry || removeProc.running) return false;
        // Optimistic: drop it from the model straight away.
        entries = entries.filter(e => e.id !== entry.id);
        removeProc.command = ["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", entry.line];
        removeProc.running = true;
        return true;
    }

    function wipe() {
        if (wipeProc.running) return;
        entries = [];
        images = {};
        texts = {};
        wipeProc.running = true;
    }

    // --- lazy payload decoding (one process at a time, newest request first)
    property var queue: []

    function loadText(entry) {
        if (!entry || entry.image || entry.binary || texts[entry.id]) return;
        request({ kind: "text", entry: entry });
    }

    function loadImage(entry) {
        if (!entry || !entry.image || images[entry.id]) return;
        request({ kind: "image", entry: entry });
    }

    function request(job) {
        const q = queue.filter(j => !(j.kind === job.kind && j.entry.id === job.entry.id));
        q.unshift(job);
        queue = q.slice(0, 48);
        pump();
    }

    function pump() {
        if (decodeProc.running || !queue.length) return;
        const job = queue[0];
        queue = queue.slice(1);
        decodeProc.job = job;
        if (job.kind === "text") {
            decodeProc.command = ["sh", "-c", `printf "%s" "$1" | cliphist decode | head -c ${textLimit + 1}`, "sh", job.entry.line];
        } else {
            decodeProc.command = ["sh", "-c",
                'mkdir -p "$2" && f="$2/$3.$4" && { [ -s "$f" ] || { printf "%s" "$1" | cliphist decode > "$f.part" && mv "$f.part" "$f"; }; } && printf "%s" "$f"',
                "sh", job.entry.line, cacheDir, job.entry.id, job.entry.format === "jpeg" ? "jpg" : job.entry.format.replace(/\+.*/, "")];
        }
        decodeProc.running = true;
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null && command -v wl-copy >/dev/null"]
        onExited: code => {
            root.available = code === 0;
            if (!root.available) {
                root.state = "error";
                root.error = "cliphist or wl-clipboard is not installed";
            }
        }
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.parse(text);
                root.entries = list;
                // Forget payloads of entries that are gone.
                const alive = {};
                for (const e of list) alive[e.id] = true;
                const t = {};
                for (const k in root.texts) if (alive[k]) t[k] = root.texts[k];
                root.texts = t;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim()
        }
        onExited: code => {
            if (code === 0) {
                root.state = "ready";
                root.error = "";
            } else if (root.error.includes("no such file") || root.error.includes("db")) {
                // Nothing stored yet.
                root.entries = [];
                root.state = "ready";
            } else {
                root.state = "error";
                if (!root.error) root.error = `cliphist exited with ${code}`;
            }
        }
    }

    Process {
        id: decodeProc
        property var job
        stdout: StdioCollector {
            onStreamFinished: {
                const job = decodeProc.job;
                if (!job) return;
                if (job.kind === "text") {
                    const t = Object.assign({}, root.texts);
                    const truncated = text.length > root.textLimit;
                    t[job.entry.id] = { text: truncated ? text.slice(0, root.textLimit) : text, truncated: truncated };
                    root.texts = t;
                } else if (text) {
                    const m = Object.assign({}, root.images);
                    m[job.entry.id] = text;
                    root.images = m;
                }
            }
        }
        onExited: Qt.callLater(root.pump)
    }

    Process {
        id: copyProc
        property string entryId
        stderr: StdioCollector { id: copyErr }
        onExited: code => {
            if (code === 0) {
                root.copied(entryId);
                refreshLater.restart();
            } else {
                root.failed(copyErr.text.trim() || "Copy failed");
            }
        }
    }

    Process {
        id: removeProc
        onExited: refreshLater.restart()
    }

    Process {
        id: wipeProc
        command: ["sh", "-c", 'cliphist wipe; rm -rf "$1"', "sh", root.cacheDir]
        onExited: refreshLater.restart()
    }

    // wl-paste --watch re-stores a copied entry, moving it to the top.
    Timer {
        id: refreshLater
        interval: 350
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "clipboard"
        function refresh(): void { root.refresh(); }
        function wipe(): void { root.wipe(); }
        function count(): int { return root.entries.length; }
    }
}
