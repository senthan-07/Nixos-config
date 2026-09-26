pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Application search with launch-frequency ranking.
Singleton {
    id: root

    readonly property var entries: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    property var usage: ({})

    function score(entry, q) {
        const name = entry.name.toLowerCase();
        const extra = [entry.genericName, entry.comment, ...(entry.keywords || [])].join(" ").toLowerCase();
        let s = 0;
        if (name === q) s = 1000;
        else if (name.startsWith(q)) s = 800;
        else if (name.split(/[\s\-_.]/).some(w => w.startsWith(q))) s = 600;
        else if (name.includes(q)) s = 400;
        else if (extra.includes(q)) s = 200;
        else {
            // Subsequence match, e.g. "vsc" -> "Visual Studio Code".
            let i = 0;
            for (const ch of name) if (ch === q[i]) i++;
            if (i === q.length) s = 100;
        }
        return s ? s + Math.min(150, (usage[entry.id] || 0) * 10) : 0;
    }

    function query(text) {
        const q = text.trim().toLowerCase();
        if (!q) {
            return [...entries].sort((a, b) => (usage[b.id] || 0) - (usage[a.id] || 0) || a.name.localeCompare(b.name));
        }
        return entries
            .map(e => ({ e, s: score(e, q) }))
            .filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s)
            .map(x => x.e);
    }

    function launch(entry) {
        const u = Object.assign({}, usage);
        u[entry.id] = (u[entry.id] || 0) + 1;
        usage = u;
        usageFile.setText(JSON.stringify(u));

        if (entry.runInTerminal)
            Quickshell.execDetached([Settings.data.terminal, "-e", ...entry.command]);
        else
            entry.execute();
    }

    FileView {
        id: usageFile
        path: Paths.appUsageFile
        printErrors: false
        onLoaded: {
            try { root.usage = JSON.parse(text()); } catch (e) {}
        }
    }
}
