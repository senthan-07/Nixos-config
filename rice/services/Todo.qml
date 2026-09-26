pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

// Persistent to-do list ($XDG_STATE_HOME/rice/todo.json).
//   items: [{id, text, done, created}]
// IPC: `qs -c rice ipc call todo add "Buy milk"`, `list`, `clearDone`.
Singleton {
    id: root

    readonly property var items: store.get("items", [])
    readonly property bool ready: store.loaded
    readonly property int remaining: items.filter(i => !i.done).length

    function newId() {
        return Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36);
    }

    function add(text) {
        const t = String(text || "").trim();
        if (!t) return "";
        const id = newId();
        store.set("items", items.concat([{ id, text: t, done: false, created: Date.now() }]));
        return id;
    }

    function toggle(id) {
        store.set("items", items.map(i => i.id === id ? Object.assign({}, i, { done: !i.done }) : i));
    }

    function setText(id, text) {
        const t = String(text || "").trim();
        if (!t) return remove(id);
        store.set("items", items.map(i => i.id === id ? Object.assign({}, i, { text: t }) : i));
    }

    function remove(id) {
        store.set("items", items.filter(i => i.id !== id));
    }

    function clearDone() {
        store.set("items", items.filter(i => !i.done));
    }

    JsonStore {
        id: store
        name: "todo"
        // JsonStore's FileView child lands in its `data` property (Item's
        // default property) until the file loads; start from an empty object.
        Component.onCompleted: if (data && typeof data.reload === "function") data = ({})
    }

    IpcHandler {
        target: "todo"
        function add(text: string): string { return root.add(text); }
        function list(): string { return root.items.map(i => `${i.done ? "[x]" : "[ ]"} ${i.text}`).join("\n"); }
        function clearDone(): void { root.clearDone(); }
    }
}
