import QtQuick
import Quickshell
import qs.config

// Default applications via xdg-mime. Reads the current handler for each role and
// collects candidate .desktop files by their MimeType= lines (read-only scan of the
// XDG application dirs). Writes only through Exec (skipped in dry-run).
Item {
    id: root

    readonly property var roles: [
        { id: "browser", group: "Internet", title: "Web browser", icon: "language",
          mimes: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"] },
        { id: "mail", group: "Internet", title: "Email", icon: "mail", mimes: ["x-scheme-handler/mailto"] },
        { id: "files", group: "Utilities", title: "File manager", icon: "folder", mimes: ["inode/directory"] },
        { id: "terminal", group: "Utilities", title: "Terminal", icon: "terminal", mimes: [] },
        { id: "text", group: "Documents", title: "Text editor", icon: "edit_note",
          mimes: ["text/plain", "text/markdown", "application/x-shellscript"] },
        { id: "pdf", group: "Documents", title: "PDF reader", icon: "picture_as_pdf", mimes: ["application/pdf"] },
        { id: "image", group: "Multimedia", title: "Image viewer", icon: "image",
          mimes: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/svg+xml", "image/avif"] },
        { id: "video", group: "Multimedia", title: "Video player", icon: "smart_display",
          mimes: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo", "video/mpeg"] },
        { id: "audio", group: "Multimedia", title: "Music player", icon: "music_note",
          mimes: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4", "audio/aac", "audio/opus"] }
    ]

    property bool loading: true
    property bool available: true
    property string error: ""
    property var current: ({})        // role id -> desktop id ("" when unset)
    property var handlers: []         // [{ id, mimes: [] }]
    property int pendingQueries: 0

    function entryFor(id) {
        if (!id) return null;
        return DesktopEntries.byId(id.replace(/\.desktop$/, "")) ?? DesktopEntries.byId(id) ?? null;
    }

    // Options for the dropdown: [{ value, label, sublabel, appIcon }]
    function candidates(role) {
        if (role.id === "terminal") {
            return DesktopEntries.applications.values
                .filter(e => (e.categories ?? []).includes("TerminalEmulator"))
                .map(e => ({ value: e.id, label: e.name, sublabel: e.command?.[0] ?? "", appIcon: e.icon || "utilities-terminal" }))
                .sort((a, b) => a.label.localeCompare(b.label));
        }
        const primary = role.mimes[0];
        const seen = {};
        const out = [];
        for (const h of handlers) {
            if (seen[h.id] || !role.mimes.some(m => h.mimes.includes(m))) continue;
            seen[h.id] = true;
            const e = entryFor(h.id);
            if (!e && h.hidden) continue;
            out.push({ value: h.id, label: e?.name ?? h.id.replace(/\.desktop$/, ""), sublabel: h.mimes.includes(primary) ? "" : "Partial support",
                       appIcon: e?.icon || "application-x-executable", rank: h.mimes.includes(primary) ? 0 : 1 });
        }
        const cur = current[role.id];
        if (cur && !seen[cur]) {
            const e = entryFor(cur);
            out.push({ value: cur, label: e?.name ?? cur, sublabel: "Current default", appIcon: e?.icon || "", rank: 0 });
        }
        // Same display name from different .desktop files (flatpak + native, …): show the id.
        for (const o of out) {
            if (out.filter(x => x.label === o.label).length > 1)
                o.sublabel = [o.sublabel, o.value.replace(/\.desktop$/, "")].filter(s => s).join(" · ");
        }
        return out.sort((a, b) => a.rank - b.rank || a.label.localeCompare(b.label));
    }

    function currentTerminalId() {
        const cmd = Settings.data.terminal;
        const e = DesktopEntries.applications.values.find(x => (x.categories ?? []).includes("TerminalEmulator")
            && ((x.command?.[0] ?? "").split("/").pop() === cmd || x.id === cmd));
        return e?.id ?? "";
    }

    function setDefault(role, id) {
        if (role.id === "terminal") {
            const e = DesktopEntries.byId(id);
            const cmd = (e?.command?.[0] ?? id).split("/").pop();
            if (Exec.allow(`terminal ${cmd}`)) Settings.data.terminal = cmd;
            else { const c = Object.assign({}, current); c.terminal = id; current = c; }
            return;
        }
        const desktop = id.endsWith(".desktop") ? id : `${id}.desktop`;
        Exec.run(["xdg-mime", "default", desktop, ...role.mimes]);
        const c = Object.assign({}, current);
        c[role.id] = desktop;
        current = c;
        settle.restart();
    }

    function refresh() {
        loading = true;
        const mimes = roles.filter(r => r.mimes.length).map(r => `${r.id}=${r.mimes[0]}`);
        currentQ.start(["sh", "-c", 'for p in "$@"; do r=${p%%=*}; m=${p#*=}; printf "%s\\t%s\\n" "$r" "$(xdg-mime query default "$m" 2>/dev/null)"; done', "sh", ...mimes]);
        scanQ.start(["sh", "-c", `
            IFS=:
            for d in "\${XDG_DATA_HOME:-$HOME/.local/share}" \${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
                a="$d/applications"; [ -d "$a" ] || continue
                find -L "$a" -name '*.desktop' 2>/dev/null | while IFS= read -r f; do
                    m=$(grep -m1 '^MimeType=' "$f" | cut -d= -f2-)
                    [ -n "$m" ] || continue
                    h=$(grep -m1 -E '^(NoDisplay|Hidden)=true' "$f")
                    printf '%s\\t%s\\t%s\\n' "$(printf %s "\${f#$a/}" | tr / -)" "$m" "$h"
                done
            done`]);
    }

    Component.onCompleted: refresh()
    Timer { id: settle; interval: 800; onTriggered: if (!Exec.dryRun) root.refresh() }

    Query {
        id: currentQ
        onFinished: (out, code) => {
            if (code !== 0) {
                root.available = false;
                root.error = "xdg-mime is not installed (package xdg-utils)";
            }
            const c = {};
            for (const line of out.split("\n")) {
                const [r, id] = line.split("\t");
                if (r) c[r] = (id ?? "").trim();
            }
            c.terminal = root.currentTerminalId();
            root.current = c;
            root.loading = scanQ.busy;
        }
    }

    Query {
        id: scanQ
        onFinished: (out, code) => {
            const seen = {};
            const list = [];
            for (const line of out.split("\n")) {
                const [id, mimes, hidden] = line.split("\t");
                if (!id || seen[id]) continue;   // earlier XDG dirs take precedence
                seen[id] = true;
                list.push({ id, mimes: (mimes ?? "").split(";").filter(m => m), hidden: !!hidden });
            }
            root.handlers = list;
            root.loading = currentQ.busy;
        }
    }
}
