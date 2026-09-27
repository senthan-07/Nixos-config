pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

// Persistent to-do list ($XDG_STATE_HOME/rice/todo.json).
//   items: [{id, text, done, created, due?, notified?}]   due = ms since epoch
// A deadline can be typed at the end of a task after "@":
//   "Submit report @tomorrow 17:00", "Call mom @2h", "Pay rent @fri", "@2026-10-03 14:30"
// When a deadline passes, a notification is sent once.
// IPC: `rice ipc call todo add "Buy milk @today 18:00"`, `list`, `clearDone`, `setDue <id> <when>`.
Singleton {
    id: root

    readonly property var items: store.get("items", [])
    readonly property bool ready: store.loaded
    readonly property int remaining: items.filter(i => !i.done).length

    // Open tasks by deadline (none last), then finished ones.
    readonly property var sorted: {
        const open = items.filter(i => !i.done).sort((a, b) =>
            (a.due ?? Infinity) - (b.due ?? Infinity) || a.created - b.created);
        return open.concat(items.filter(i => i.done));
    }

    // Ticks every 30 s so "in 20 min" / overdue labels stay current.
    property real now: Date.now()
    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: {
            root.now = Date.now();
            root.checkDue();
        }
    }
    Component.onCompleted: checkDue()

    function newId() {
        return Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36);
    }

    // ---- deadline parsing ------------------------------------------------------
    // Returns ms since epoch, or null. Understands: today, tonight, tomorrow,
    // weekday names, "next week", "2h" / "30m" / "3d", "HH:MM", "5pm",
    // "YYYY-MM-DD", "DD/MM" (with an optional time).
    function parseWhen(input) {
        let s = String(input || "").trim().toLowerCase();
        if (!s) return null;
        const d = new Date();
        d.setSeconds(0, 0);

        const rel = s.match(/^(?:in\s+)?(\d+)\s*(m|min|mins|h|hr|hrs|hours?|d|days?|w|weeks?)$/);
        if (rel) {
            const n = parseInt(rel[1]), u = rel[2][0];
            return Date.now() + n * (u === "m" ? 60e3 : u === "h" ? 3600e3 : u === "d" ? 86400e3 : 604800e3);
        }

        let time = null;      // [h, m]
        const t = s.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$/);
        const isDateOnlyNumber = /^\d{1,2}\/\d{1,2}$/.test(s) || /^\d{4}-\d{2}-\d{2}$/.test(s);
        if (t && !isDateOnlyNumber && (t[2] || t[3] || /\s/.test(s) || /^\d{1,2}:\d{2}$/.test(s) || /^\d{1,2}\s*(am|pm)$/.test(s))) {
            let h = parseInt(t[1]); const m = parseInt(t[2] || "0");
            if (t[3] === "pm" && h < 12) h += 12;
            if (t[3] === "am" && h === 12) h = 0;
            if (h < 24 && m < 60) {
                time = [h, m];
                s = s.slice(0, t.index).trim();
            }
        }

        const days = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        let dayFound = true;
        if (!s || s === "today") {
            // keep date
        } else if (s === "tonight") {
            if (!time) time = [20, 0];
        } else if (s === "tomorrow" || s === "tmr" || s === "tmrw") {
            d.setDate(d.getDate() + 1);
        } else if (s === "next week") {
            d.setDate(d.getDate() + 7);
        } else if (days.includes(s.slice(0, 3))) {
            const target = days.indexOf(s.slice(0, 3));
            let diff = (target - d.getDay() + 7) % 7;
            if (diff === 0) diff = 7;
            d.setDate(d.getDate() + diff);
        } else if (/^\d{4}-\d{2}-\d{2}$/.test(s)) {
            const [y, mo, da] = s.split("-").map(Number);
            d.setFullYear(y, mo - 1, da);
        } else if (/^\d{1,2}\/\d{1,2}$/.test(s)) {
            const [da, mo] = s.split("/").map(Number);
            d.setMonth(mo - 1, da);
            if (d.getTime() < Date.now() - 86400e3) d.setFullYear(d.getFullYear() + 1);
        } else {
            dayFound = false;
        }
        if (!dayFound) return null;

        if (time) d.setHours(time[0], time[1]);
        else if (s === "today" || s === "") d.setHours(23, 59);       // end of today
        else d.setHours(9, 0);                                          // other days: morning
        // A bare time that already passed today means tomorrow.
        if (!s && time && d.getTime() < Date.now()) d.setDate(d.getDate() + 1);
        return d.getTime();
    }

    // "Buy milk @tomorrow 5pm" -> { text: "Buy milk", due }
    function splitDue(text) {
        const t = String(text || "");
        const at = t.lastIndexOf("@");
        if (at > 0) {
            const due = parseWhen(t.slice(at + 1));
            if (due !== null) return { text: t.slice(0, at).trim(), due };
        }
        return { text: t.trim(), due: null };
    }

    // ---- labels ----------------------------------------------------------------
    function isOverdue(item) { return !item.done && item.due && item.due <= now; }

    function dueLabel(due) {
        if (!due) return "";
        const d = new Date(due), n = new Date(now);
        const diff = due - now;
        const hhmm = Qt.formatTime(d, "HH:mm");
        const dayDiff = Math.round((new Date(d).setHours(0, 0, 0, 0) - new Date(n).setHours(0, 0, 0, 0)) / 86400e3);
        if (diff < 0) {
            const ago = -diff;
            return "Overdue · " + (ago < 3600e3 ? `${Math.max(1, Math.round(ago / 60e3))} min`
                : ago < 86400e3 ? `${Math.round(ago / 3600e3)} h` : `${Math.round(ago / 86400e3)} d`);
        }
        if (diff < 3600e3) return `In ${Math.max(1, Math.round(diff / 60e3))} min`;
        const time = hhmm === "23:59" ? "" : " " + hhmm;
        if (dayDiff === 0) return "Today" + time;
        if (dayDiff === 1) return "Tomorrow" + time;
        if (dayDiff < 7) return Qt.formatDate(d, "ddd") + time;
        return Qt.formatDate(d, "d MMM") + time;
    }

    // ---- mutations -------------------------------------------------------------
    function add(text, due) {
        const parsed = splitDue(text);
        if (!parsed.text) return "";
        const id = newId();
        const item = { id, text: parsed.text, done: false, created: Date.now() };
        const when = due ?? parsed.due;
        if (when) item.due = when;
        store.set("items", items.concat([item]));
        return id;
    }

    function patch(id, changes) {
        store.set("items", items.map(i => i.id === id ? Object.assign({}, i, changes) : i));
    }

    function toggle(id) {
        const it = items.find(i => i.id === id);
        if (it) patch(id, { done: !it.done });
    }

    function setText(id, text) {
        const parsed = splitDue(text);
        if (!parsed.text) return remove(id);
        const changes = { text: parsed.text };
        if (parsed.due) { changes.due = parsed.due; changes.notified = false; }
        patch(id, changes);
    }

    function setDue(id, due) {
        patch(id, { due: due || undefined, notified: false });
    }

    function remove(id) {
        store.set("items", items.filter(i => i.id !== id));
    }

    function clearDone() {
        store.set("items", items.filter(i => !i.done));
    }

    // Notify once for each task whose deadline has passed.
    function checkDue() {
        if (!store.loaded) return;
        const due = items.filter(i => !i.done && i.due && i.due <= Date.now() && !i.notified);
        if (!due.length) return;
        for (const i of due)
            Quickshell.execDetached(["notify-send", "-a", "To-do", "-i", "task-due", "-u", "critical",
                "Task due", i.text]);
        const ids = due.map(i => i.id);
        store.set("items", items.map(i => ids.includes(i.id) ? Object.assign({}, i, { notified: true }) : i));
    }

    JsonStore {
        id: store
        name: "todo"
        onLoadedChanged: if (loaded) root.checkDue()
    }

    IpcHandler {
        target: "todo"
        function add(text: string): string { return root.add(text); }
        function list(): string {
            return root.sorted.map(i => `${i.done ? "[x]" : "[ ]"} ${i.text}${i.due ? "  (" + root.dueLabel(i.due) + ")" : ""}  #${i.id}`).join("\n");
        }
        function setDue(id: string, when: string): string {
            const due = root.parseWhen(when);
            if (when && due === null) return `couldn't understand "${when}"`;
            root.setDue(id, due);
            return due ? root.dueLabel(due) : "deadline cleared";
        }
        function remove(id: string): void { root.remove(id); }
        function clearDone(): void { root.clearDone(); }
    }
}
