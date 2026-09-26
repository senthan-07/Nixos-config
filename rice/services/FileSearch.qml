pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// File and folder search under $HOME using fd (preferred), plocate or find.
// results: [{ path, name, parent, dir, ext, kind }]
Singleton {
    id: root

    property string query: ""
    property var results: []
    property string state: "idle"       // idle | loading | ready | error | unavailable
    property string error: ""
    property string backend: ""         // fd | plocate | find
    property bool limited: false
    readonly property string home: Paths.home
    readonly property int maxResults: 60

    property int generation: 0

    function search(text) {
        query = String(text || "");
        generation++;
        debounce.stop();
        if (proc.running) proc.signal(15);
        if (!query.trim()) {
            results = [];
            state = "idle";
            return;
        }
        state = "loading";
        debounce.restart();
    }

    function cancel() {
        generation++;
        debounce.stop();
        if (proc.running) proc.signal(15);
        query = "";
        results = [];
        state = "idle";
    }

    function escapeRegex(s) {
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    function start() {
        if (!backend) {
            // Wait for the probe; it calls start() again.
            return;
        }
        if (proc.running) {
            // The previous search is still shutting down.
            debounce.restart();
            return;
        }
        const words = query.trim().split(/\s+/).filter(Boolean);
        if (!words.length) return;
        let cmd;
        if (backend === "fd") {
            cmd = ["fd", "--color=never", "--absolute-path", "--ignore-case",
                "--exclude", ".git", "--exclude", "node_modules", "--exclude", ".cache",
                "--exclude", ".local/share/Trash", "--exclude", "__pycache__",
                "--max-results", "400", "--", words.map(escapeRegex).join(".*"), home];
        } else if (backend === "plocate") {
            cmd = ["sh", "-c", 'plocate -i -l 2000 -- "$@" | grep -v "/\\." | head -n 400', "sh", home + "/", ...words];
        } else {
            cmd = ["sh", "-c", 'find "$1" -maxdepth 6 -not -path "*/.*" -iname "*$2*" 2>/dev/null | head -n 400', "sh", home, words.join("*")];
        }
        proc.gen = generation;
        proc.command = cmd;
        proc.running = true;
    }

    function kindFor(name, dir) {
        if (dir) return "folder";
        const ext = name.includes(".") ? name.slice(name.lastIndexOf(".") + 1).toLowerCase() : "";
        const groups = {
            image: "png jpg jpeg gif webp bmp svg tiff tif heic avif ico xcf psd raw cr2 nef",
            video: "mp4 mkv webm avi mov flv wmv m4v mpg mpeg",
            audio: "mp3 flac ogg opus wav m4a aac wma mid midi",
            pdf: "pdf",
            doc: "doc docx odt rtf txt md org tex epub mobi",
            sheet: "xls xlsx ods csv tsv",
            slides: "ppt pptx odp key",
            archive: "zip tar gz tgz xz bz2 zst 7z rar iso deb rpm",
            code: "qml js ts jsx tsx py rs go c h cpp hpp cc java kt swift rb php lua nix sh bash zsh fish html css scss json yaml yml toml ini conf xml sql",
            exec: "appimage exe bin run"
        };
        for (const k in groups) if (groups[k].split(" ").includes(ext)) return k;
        return "file";
    }

    function rank(path, words) {
        const dir = path.endsWith("/");
        const clean = dir ? path.slice(0, -1) : path;
        const name = clean.slice(clean.lastIndexOf("/") + 1);
        const lname = name.toLowerCase();
        const q = words.join(" ").toLowerCase();
        let s = 0;
        if (lname === q) s += 1000;
        else if (lname.startsWith(words[0])) s += 700;
        else if (words.every(w => lname.includes(w))) s += 500;
        else s += 100;
        const depth = clean.split("/").length;
        s -= depth * 6 + name.length * 0.5;
        if (dir) s += 25;
        return {
            s: s,
            e: {
                path: clean,
                name: name,
                parent: clean.slice(0, clean.lastIndexOf("/")) || "/",
                dir: dir,
                kind: kindFor(name, dir)
            }
        };
    }

    function prettyPath(p) {
        return p.startsWith(home) ? "~" + p.slice(home.length) : p;
    }

    // --- actions
    function open(entry) {
        Quickshell.execDetached(["xdg-open", entry.path]);
    }

    function reveal(entry) {
        // Ask the file manager to select the item; fall back to opening its folder.
        Quickshell.execDetached(["sh", "-c",
            'gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 ' +
            '--method org.freedesktop.FileManager1.ShowItems "[\'file://$1\']" "" >/dev/null 2>&1 || xdg-open "$2"',
            "sh", encodeURI(entry.path), entry.dir ? entry.path : entry.parent]);
    }

    function copyPath(entry) {
        Quickshell.execDetached(["wl-copy", "--", entry.path]);
    }

    Timer {
        id: debounce
        interval: 140
        onTriggered: root.start()
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v fd >/dev/null && echo fd || { command -v plocate >/dev/null && echo plocate; } || echo find"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.backend = text.trim() || "find";
                if (root.state === "loading") root.start();
            }
        }
    }

    Process {
        id: proc
        property int gen: -1
        stdout: StdioCollector {
            onStreamFinished: {
                if (proc.gen !== root.generation) return;
                const words = root.query.trim().toLowerCase().split(/\s+/).filter(Boolean);
                const lines = text.split("\n").filter(l => l && l.startsWith(root.home + "/"));
                const ranked = lines.map(l => root.rank(l, words)).sort((a, b) => b.s - a.s);
                root.limited = ranked.length > root.maxResults;
                root.results = ranked.slice(0, root.maxResults).map(x => x.e);
                root.state = "ready";
                root.error = "";
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (proc.gen === root.generation && text.trim()) root.error = text.trim().split("\n")[0];
            }
        }
        onExited: code => {
            // fd exits 1 when a directory is unreadable but still prints results.
            if (proc.gen === root.generation && code > 1 && !root.results.length) root.state = "error";
        }
    }
}
