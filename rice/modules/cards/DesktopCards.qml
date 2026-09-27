pragma Singleton

import QtQuick
import Quickshell
import qs.services
import Quickshell.Io
import Quickshell.Hyprland
import qs.components
import "CardCatalog.js" as Catalog

// State of the desktop widget canvases: per-screen layouts (persisted in
// $XDG_STATE_HOME/rice/desktop-cards.json), visibility and edit mode.
//
//   qs -c rice ipc call desktop editToggle
//   qs -c rice ipc call desktop toggle          show / hide all widgets
//   qs -c rice ipc call desktop add weather     add a card on the focused screen
//   qs -c rice ipc call desktop reset           restore the default layout
Singleton {
    id: root

    readonly property bool enabled: store.get("enabled", true)
    property bool editing: false
    // Screen whose canvas takes the keyboard while editing.
    property string editScreen: ""
    // Canvases register their grid size here: {screenName: {cols, rows}}.
    property var grids: ({})

    readonly property var catalog: Catalog.cards

    function focusedScreen() {
        const m = Hyprland.focusedMonitor;
        if (m && Quickshell.screens.some(s => s.name === m.name)) return m.name;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    // Edit mode happens on the desktop layer (below windows), so jump to an
    // empty workspace while editing and come back when done.
    property string returnWorkspace: ""

    function setEditing(on) {
        if (on === editing) return;
        if (on && !enabled) store.set("enabled", true);
        if (on) {
            editScreen = focusedScreen();
            const ws = Hyprland.focusedMonitor?.activeWorkspace;
            const hasWindows = (ws?.toplevels?.values?.length ?? 0) > 0;
            returnWorkspace = hasWindows ? String(ws.id) : "";
            if (hasWindows) Hypr.focusWorkspace("empty");
        } else if (returnWorkspace !== "") {
            Hypr.focusWorkspace(returnWorkspace);
            returnWorkspace = "";
        }
        editing = on;
    }

    function setEnabled(on) {
        if (!on) editing = false;
        store.set("enabled", on);
    }

    function registerGrid(screen, cols, rows) {
        const g = Object.assign({}, grids);
        g[screen] = { cols, rows };
        grids = g;
    }

    function hasLayout(screen) {
        return !!(store.get("layouts", {})[screen]);
    }

    // Stored layout for a screen, or the default for its grid size.
    function layoutFor(screen, cols, rows) {
        const saved = store.get("layouts", {})[screen];
        if (Array.isArray(saved)) return saved;
        return Catalog.defaultLayout(cols, rows, CardStyle.weatherAvailable);
    }

    function save(screen, cards) {
        const all = Object.assign({}, store.get("layouts", {}));
        all[screen] = cards.map(c => ({ id: c.id, type: c.type, x: c.x, y: c.y, w: c.w, h: c.h }));
        store.set("layouts", all);
    }

    function reset(screen) {
        const all = Object.assign({}, store.get("layouts", {}));
        if (screen) delete all[screen];
        store.set("layouts", screen ? all : {});
    }

    // Adds a card of `type` at the first free spot; returns the new id or "".
    function add(screen, type) {
        const def = Catalog.find(type);
        const g = grids[screen];
        if (!def || !g || (def.needs === "weather" && !CardStyle.weatherAvailable)) return "";
        const cards = layoutFor(screen, g.cols, g.rows).slice();
        const spot = Catalog.freeSpot(def.w, def.h, cards, g.cols, g.rows)
            || Catalog.freeSpot(def.min[0], def.min[1], cards, g.cols, g.rows);
        if (!spot) return "";
        const fits = Catalog.fits({ x: spot.x, y: spot.y, w: def.w, h: def.h }, cards, null, g.cols, g.rows);
        const id = "c" + Date.now().toString(36);
        cards.push({ id, type, x: spot.x, y: spot.y, w: fits ? def.w : def.min[0], h: fits ? def.h : def.min[1] });
        save(screen, cards);
        return id;
    }

    function remove(screen, id) {
        const g = grids[screen];
        if (!g) return;
        save(screen, layoutFor(screen, g.cols, g.rows).filter(c => c.id !== id));
    }

    function update(screen, id, rect) {
        const g = grids[screen];
        if (!g) return;
        save(screen, layoutFor(screen, g.cols, g.rows).map(c => c.id === id ? Object.assign({}, c, rect) : c));
    }

    JsonStore {
        id: store
        name: "desktop-cards"
        // JsonStore's FileView child lands in its `data` property (Item's
        // default property) until the file loads; start from an empty object.
        Component.onCompleted: if (data && typeof data.reload === "function") data = ({})
    }

    IpcHandler {
        target: "desktop"
        function editToggle(): void { root.setEditing(!root.editing); }
        function edit(on: bool): void { root.setEditing(on); }
        function toggle(): void { root.setEnabled(!root.enabled); }
        function show(): void { root.setEnabled(true); }
        function hide(): void { root.setEnabled(false); }
        function isEditing(): bool { return root.editing; }
        function add(type: string): string {
            const id = root.add(root.focusedScreen(), type);
            return id ? id : `could not add "${type}" (unknown type or no free space)`;
        }
        function reset(): void { root.reset(root.focusedScreen()); }
        function resetAll(): void { root.reset(""); }
        function types(): string { return Catalog.cards.map(c => `${c.type}\t${c.name}`).join("\n"); }
    }
}
