import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Small persisted key/value store for a module: $XDG_STATE_HOME/rice/<name>.json
//   JsonStore { id: store; name: "dock" }
//   store.get("pinned", [])   store.set("pinned", [...])
// `data` is replaced on every write, so bindings on store.data re-evaluate.
// The root is a QtObject (not an Item) so `data` can't collide with Item.data.
QtObject {
    id: root

    required property string name
    property var data: ({})
    readonly property bool loaded: file.loaded

    function get(key, fallback) {
        return data[key] !== undefined ? data[key] : fallback;
    }

    function set(key, value) {
        const next = Object.assign({}, data);
        next[key] = value;
        data = next;
        file.setText(JSON.stringify(next, null, 2));
    }

    property FileView file: FileView {
        path: `${Paths.state}/${root.name}.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text()) || {};
                // Drop keys written by the old Item-based store (FileView internals).
                for (const k of ["objectName", "__path", "path", "blockWrites", "blockLoading", "atomicWrites", "watchChanges", "printErrors", "preload", "blockAllReads", "adapter", "loaded"])
                    delete parsed[k];
                root.data = parsed;
            } catch (e) {
                root.data = {};
            }
        }
    }
}
