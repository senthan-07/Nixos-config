import QtQuick
import Quickshell
import qs.config

// XDG autostart entries (~/.config/autostart/*.desktop plus read-only system entries
// from $XDG_CONFIG_DIRS/autostart). RICE_AUTOSTART_DIR overrides the user directory
// (the test harness points it at a temp dir).
Item {
    id: root

    readonly property string overrideDir: Quickshell.env("RICE_AUTOSTART_DIR") ?? ""
    readonly property string dir: overrideDir || `${Paths.dotfiles}/autostart`   // linked to ~/.config/autostart
    readonly property var systemDirs: (Quickshell.env("XDG_CONFIG_DIRS") || "/etc/xdg").split(":").filter(d => d).map(d => `${d}/autostart`)

    property bool loading: true
    property string error: ""
    property var entries: []      // user: [{ file, path, name, exec, icon, comment, enabled, raw }]
    property var system: []       // system entries not overridden by a user file

    // ---- parsing ----
    function parse(path, text) {
        const e = { path, file: path.split("/").pop(), raw: text, name: "", exec: "", icon: "", comment: "",
                    hidden: false, gnomeEnabled: true, onlyShowIn: "", valid: true };
        let inMain = false;
        for (const line of text.split("\n")) {
            const t = line.trim();
            if (t.startsWith("[")) { inMain = t === "[Desktop Entry]"; continue; }
            if (!inMain || t.startsWith("#")) continue;
            const i = t.indexOf("=");
            if (i < 0) continue;
            const k = t.slice(0, i).trim(), v = t.slice(i + 1).trim();
            if (k === "Name") e.name = v;
            else if (k === "Exec") e.exec = v;
            else if (k === "Icon") e.icon = v;
            else if (k === "Comment") e.comment = v;
            else if (k === "Hidden") e.hidden = v === "true";
            else if (k === "X-GNOME-Autostart-enabled") e.gnomeEnabled = v !== "false";
            else if (k === "OnlyShowIn") e.onlyShowIn = v;
        }
        e.enabled = !e.hidden && e.gnomeEnabled;
        e.valid = e.exec !== "" || e.hidden;
        if (!e.name) e.name = e.file.replace(/\.desktop$/, "");
        return e;
    }

    // Set/replace keys inside the [Desktop Entry] group, keeping everything else.
    function withKeys(text, keys) {
        const lines = text.split("\n");
        let start = lines.findIndex(l => l.trim() === "[Desktop Entry]");
        if (start < 0) { lines.unshift("[Desktop Entry]"); start = 0; }
        let end = lines.findIndex((l, i) => i > start && l.trim().startsWith("["));
        if (end < 0) end = lines.length;
        for (const k in keys) {
            const idx = lines.findIndex((l, i) => i > start && i < end && l.split("=")[0].trim() === k);
            if (keys[k] === null) {
                if (idx >= 0) { lines.splice(idx, 1); end--; }
            } else if (idx >= 0) {
                lines[idx] = `${k}=${keys[k]}`;
            } else {
                // insert before trailing blank lines of the group
                let at = end;
                while (at - 1 > start && lines[at - 1].trim() === "") at--;
                lines.splice(at, 0, `${k}=${keys[k]}`);
                end++;
            }
        }
        return lines.join("\n");
    }

    // ---- file IO ----
    function refresh() {
        loading = true;
        listQ.start(["sh", "-c", 'for d in "$@"; do for f in "$d"/*.desktop; do [ -f "$f" ] || continue; printf "\\036%s\\n" "$f"; cat "$f"; done; done', "sh", dir, ...systemDirs]);
    }

    function write(path, text) {
        if (Exec.dryRun && !overrideDir) { Exec.run(["write", path]); return; }
        writeQ.start(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "sh", path, text.endsWith("\n") ? text : text + "\n"]);
    }
    function removeFile(path) {
        if (Exec.dryRun && !overrideDir) { Exec.run(["rm", path]); return; }
        writeQ.start(["rm", "-f", "--", path]);
    }

    // ---- actions ----
    function setEnabled(e, on) {
        if (e.system) {
            const userPath = `${dir}/${e.file}`;
            if (on) removeFile(userPath);   // drop the override
            else write(userPath, withKeys(e.raw, { Hidden: "true" }));
        } else {
            write(e.path, withKeys(e.raw, { Hidden: on ? null : "true", "X-GNOME-Autostart-enabled": on ? null : "false" }));
        }
    }
    function remove(e) { removeFile(e.path); }

    function slug(s) { return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "entry"; }
    function uniquePath(base) {
        let name = `${base}.desktop`, n = 2;
        while (entries.some(x => x.file === name)) name = `${base}-${n++}.desktop`;
        return `${dir}/${name}`;
    }
    function addApplication(app) {
        const lines = ["[Desktop Entry]", "Type=Application", `Name=${app.name}`, `Exec=${app.execString}`];
        if (app.icon) lines.push(`Icon=${app.icon}`);
        if (app.comment) lines.push(`Comment=${app.comment}`);
        if (app.runInTerminal) lines.push("Terminal=true");
        lines.push("X-GNOME-Autostart-enabled=true");
        write(uniquePath(slug(app.id.replace(/\.desktop$/, ""))), lines.join("\n"));
    }
    function addCommand(name, command) {
        const lines = ["[Desktop Entry]", "Type=Application", `Name=${name}`, `Exec=${command}`,
                       "Icon=utilities-terminal", "Comment=Added from Rice Settings", "X-GNOME-Autostart-enabled=true"];
        write(uniquePath(`rice-${slug(name)}`), lines.join("\n"));
    }

    Component.onCompleted: refresh()

    Query {
        id: listQ
        onFinished: (out, code) => {
            root.loading = false;
            const user = [], sys = [];
            for (const chunk of out.split("\u001e")) {
                if (!chunk.trim()) continue;
                const nl = chunk.indexOf("\n");
                const path = chunk.slice(0, nl < 0 ? chunk.length : nl);
                const e = root.parse(path, nl < 0 ? "" : chunk.slice(nl + 1));
                if (path.startsWith(root.dir + "/")) user.push(e);
                else sys.push(Object.assign(e, { system: true }));
            }
            const userFiles = user.map(e => e.file);
            // A user file with the same name overrides (usually hides) the system one.
            root.system = sys.filter((e, i) => !userFiles.includes(e.file) && sys.findIndex(x => x.file === e.file) === i)
                .concat(sys.filter(e => userFiles.includes(e.file) && user.find(u => u.file === e.file)?.hidden)
                    .map(e => Object.assign({}, e, { enabled: false, overridden: true })))
                .sort((a, b) => a.name.localeCompare(b.name));
            root.entries = user.filter(u => !(u.hidden && sys.some(s => s.file === u.file)))
                .sort((a, b) => a.name.localeCompare(b.name));
        }
    }

    Query {
        id: writeQ
        onFinished: (out, code) => {
            root.error = code === 0 ? "" : `Couldn't update autostart: ${out.trim()}`;
            root.refresh();
        }
    }
}
