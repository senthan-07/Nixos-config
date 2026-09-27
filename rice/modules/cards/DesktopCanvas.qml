import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services
import "CardCatalog.js" as Catalog

// Desktop widget layer for one screen: sits above the wallpaper and below
// windows (WlrLayer.Bottom) and hosts cards on a snapping grid. In edit mode
// (`qs -c rice ipc call desktop editToggle`) it moves to the Top layer so it
// can be edited over windows, shows the grid and an add/reset/done toolbar.
//
// Keyboard in edit mode: Tab / Shift+Tab select a card, arrows move it,
// Delete removes, A opens the card picker, Esc finishes.
//
//   DesktopCanvas { screen: modelData }
PanelWindow {
    id: root

    readonly property string screenName: screen ? screen.name : ""
    readonly property bool editing: DesktopCards.editing
    readonly property bool keyScreen: editing && DesktopCards.editScreen === screenName

    // Pause card animations while windows cover this output's desktop.
    readonly property bool desktopVisible: {
        const mon = HyprMonitors.forScreen(screen);
        const ws = mon ? mon.activeWorkspace : null;
        if (!ws) return true;
        if (ws.hasFullscreen) return false;
        return ws.toplevels.values.length === 0;
    }
    readonly property bool animate: editing || desktopVisible

    readonly property int cols: Math.max(1, Math.floor((width - 2 * CardStyle.edge + CardStyle.gap) / CardStyle.pitch))
    readonly property int rows: Math.max(1, Math.floor((height - 2 * CardStyle.edge + CardStyle.gap) / CardStyle.pitch))
    readonly property real originX: Math.round((width - CardStyle.span(cols)) / 2)
    readonly property real originY: Math.round((height - CardStyle.span(rows)) / 2)
    readonly property bool sized: width > 0 && height > 0

    // Stored (or default) layout, clamped into the current grid.
    readonly property var layout: {
        if (!sized) return [];
        return DesktopCards.layoutFor(screenName, cols, rows).map(c => {
            const w = Math.min(c.w, cols), h = Math.min(c.h, rows);
            return { id: c.id, type: c.type, w, h,
                     x: Math.max(0, Math.min(cols - w, c.x)), y: Math.max(0, Math.min(rows - h, c.y)) };
        });
    }

    property string selectedId: ""
    property var previewRect: null      // {x, y, w, h, valid} in cells while dragging/resizing
    property bool pickerOpen: false
    property string toast: ""

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    visible: DesktopCards.enabled
    WlrLayershell.namespace: "rice-desktop"
    // Always below windows: Hyprland delivered no pointer input to the Top /
    // Overlay surfaces edit mode used before. Edit mode instead switches to an
    // empty workspace (DesktopCards.setEditing) so nothing covers the widgets.
    WlrLayershell.layer: WlrLayer.Bottom
    // Keyboard for edit mode goes to the toolbar window below (a surface
    // mapped with exclusive focus); the canvas only takes clicks-to-focus
    // for cards with inputs (to-do).
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Outside edit mode only the cards take input; the rest clicks through.
    // In edit mode the whole surface takes input. Use an explicit full region:
    // switching the mask to null left the (now empty) card region active, so
    // no clicks reached the widgets.
    mask: editing ? fullMask : cardMask
    Region {
        id: fullMask
        item: fullArea
    }
    Item {
        id: fullArea
        anchors.fill: parent
    }
    Region {
        id: cardMask
        regions: regionVariants.instances
    }
    Variants {
        id: regionVariants
        model: root.editing ? [] : root.layout.filter(c => c.type !== "weather" || CardStyle.weatherAvailable)
        Region {
            required property var modelData
            x: root.originX + modelData.x * CardStyle.pitch
            y: root.originY + modelData.y * CardStyle.pitch
            width: CardStyle.span(modelData.w)
            height: CardStyle.span(modelData.h)
        }
    }

    onColsChanged: registerGrid()
    onRowsChanged: registerGrid()
    onScreenNameChanged: registerGrid()
    onLayoutChanged: sync()
    onEditingChanged: if (!editing) { selectedId = ""; pickerOpen = false; clearPreview(); }

    function registerGrid() {
        if (sized && screenName) DesktopCards.registerGrid(screenName, cols, rows);
    }

    // ---- layout model -------------------------------------------------------

    // Diff the layout into the ListModel so delegates (and their running
    // animations) survive edits instead of being recreated.
    function sync() {
        const next = layout;
        const byId = {};
        for (const c of next) byId[c.id] = c;
        for (let i = cards.count - 1; i >= 0; i--) {
            const id = cards.get(i).cardId;
            const c = byId[id];
            if (!c) { cards.remove(i); continue; }
            if (cards.get(i).type !== c.type) cards.setProperty(i, "type", c.type);
            cards.setProperty(i, "gx", c.x);
            cards.setProperty(i, "gy", c.y);
            cards.setProperty(i, "gw", c.w);
            cards.setProperty(i, "gh", c.h);
            delete byId[id];
        }
        for (const c of next)
            if (byId[c.id]) cards.append({ cardId: c.id, type: c.type, gx: c.x, gy: c.y, gw: c.w, gh: c.h });
        if (selectedId && !next.some(c => c.id === selectedId)) selectedId = "";
    }

    ListModel { id: cards }

    function cellX(px) { return Math.max(0, Math.min(cols - 1, Math.round((px - originX) / CardStyle.pitch))); }
    function cellY(py) { return Math.max(0, Math.min(rows - 1, Math.round((py - originY) / CardStyle.pitch))); }

    function select(id) {
        selectedId = id;
        pickerOpen = false;
    }

    function preview(id, x, y, w, h) {
        const r = { x, y, w, h };
        r.valid = Catalog.fits(r, layout, id, cols, rows);
        previewRect = r;
    }

    function clearPreview() {
        previewRect = null;
    }

    // Validates and stores a new rect; with `radius` > 0 a blocked drop
    // lands on the nearest free spot instead. Returns whether it moved.
    function commit(id, rect, radius) {
        let r = Catalog.fits(rect, layout, id, cols, rows) ? rect
            : radius > 0 ? Catalog.nearestFree(rect, layout, id, cols, rows, radius) : null;
        if (!r) {
            flash("No room there");
            return false;
        }
        DesktopCards.update(screenName, id, { x: r.x, y: r.y, w: r.w, h: r.h });
        return true;
    }

    function removeCard(id) {
        DesktopCards.remove(screenName, id);
        if (selectedId === id) selectedId = "";
    }

    function addCard(type) {
        const id = DesktopCards.add(screenName, type);
        pickerOpen = false;
        if (id) selectedId = id;
        else flash("No free space for this card");
    }

    function flash(text) {
        toast = text;
        toastTimer.restart();
    }

    Timer { id: toastTimer; interval: 2200; onTriggered: root.toast = "" }

    function cycle(step) {
        if (layout.length === 0) return;
        const ordered = layout.slice().sort((a, b) => a.y - b.y || a.x - b.x);
        const i = ordered.findIndex(c => c.id === selectedId);
        selectedId = ordered[(i + step + ordered.length) % ordered.length].id;
    }

    function nudge(dx, dy, resize) {
        const c = layout.find(c => c.id === selectedId);
        if (!c) { cycle(1); return; }
        const def = Catalog.find(c.type) || { min: [1, 1], max: [12, 12] };
        if (resize) {
            let w = Math.max(def.min[0], Math.min(def.max[0], c.w + dx));
            let h = Math.max(def.min[1], Math.min(def.max[1], c.h + dy));
            if (def.square) w = h = (dx !== 0 ? w : h);
            commit(c.id, { x: c.x, y: c.y, w, h }, 0);
        } else {
            commit(c.id, { x: c.x + dx, y: c.y + dy, w: c.w, h: c.h }, 0);
        }
    }

    // ---- visuals ------------------------------------------------------------

    // Edit-mode scrim; clicking empty space deselects / closes the picker.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.scrim, 0.32)
        opacity: root.editing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { duration: Motion.duration.medium } }
        MouseArea {
            anchors.fill: parent
            enabled: root.editing
            onClicked: { root.selectedId = ""; root.pickerOpen = false; }
        }
    }

    GridOverlay {
        anchors.fill: parent
        cols: root.cols
        rows: root.rows
        originX: root.originX
        originY: root.originY
        opacity: root.editing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { duration: Motion.duration.medium } }
    }

    // Drop target.
    Rectangle {
        readonly property var r: root.previewRect
        visible: r !== null
        x: r ? root.originX + r.x * CardStyle.pitch : 0
        y: r ? root.originY + r.y * CardStyle.pitch : 0
        width: r ? CardStyle.span(r.w) : 0
        height: r ? CardStyle.span(r.h) : 0
        radius: Tokens.radius.xl
        color: Theme.alpha(r && r.valid ? Theme.primary : Theme.error, 0.16)
        border.width: 2
        border.color: Theme.alpha(r && r.valid ? Theme.primary : Theme.error, 0.85)
        Behavior on x { Anim { duration: Motion.duration.short } }
        Behavior on y { Anim { duration: Motion.duration.short } }
        Behavior on width { Anim { duration: Motion.duration.short } }
        Behavior on height { Anim { duration: Motion.duration.short } }
        Behavior on color { ColorAnim {} }
    }

    Repeater {
        model: cards
        DesktopCard { canvas: root }
    }

    // Edit toolbar, card picker and keyboard handling, drawn on this surface.
    Loader {
        anchors.fill: parent
        z: 20
        active: root.editing
        sourceComponent: Item {
            id: editBar

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()

                Keys.onPressed: e => {
                    if (!root.editing) return;
                    const shift = e.modifiers & Qt.ShiftModifier;
                    switch (e.key) {
                    case Qt.Key_Escape:
                        if (root.pickerOpen) root.pickerOpen = false;
                        else if (root.selectedId) root.selectedId = "";
                        else DesktopCards.setEditing(false);
                        break;
                    case Qt.Key_Tab: root.cycle(1); break;
                    case Qt.Key_Backtab: root.cycle(-1); break;
                    case Qt.Key_Left: root.nudge(-1, 0, false); break;
                    case Qt.Key_Right: root.nudge(1, 0, false); break;
                    case Qt.Key_Up: root.nudge(0, -1, false); break;
                    case Qt.Key_Down: root.nudge(0, 1, false); break;
                    case Qt.Key_Delete:
                    case Qt.Key_Backspace:
                        if (root.selectedId) root.removeCard(root.selectedId);
                        break;
                    case Qt.Key_A: root.pickerOpen = !root.pickerOpen; break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        DesktopCards.setEditing(false);
                        break;
                    default:
                        return;
                    }
                    e.accepted = true;
                }
            }

            Rectangle {
                id: toolbar
                anchors.horizontalCenter: parent.horizontalCenter
                y: Tokens.space.l
                // Slide in via a transform so the input mask (which tracks the
                // item's geometry) stays put.
                property bool shown: false
                Component.onCompleted: shown = true
                transform: Translate {
                    y: toolbar.shown ? 0 : -toolbar.height - Tokens.space.l * 2
                    Behavior on y { Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.emphasizedDecel } }
                }
                implicitWidth: bar.implicitWidth + Tokens.space.s * 2
                implicitHeight: 52
                radius: height / 2
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Theme.alpha(Theme.outlineVariant, 0.6)
                z: 20

                RowLayout {
                    id: bar
                    anchors.centerIn: parent
                    spacing: Tokens.space.s

                    Icon { Layout.leftMargin: Tokens.space.m; text: "dashboard_customize"; size: 20; color: Theme.primary }
                    ColumnLayout {
                        spacing: -2
                        StyledText { text: "Edit desktop"; font.weight: Font.Bold }
                        StyledText {
                            text: "Drag to move · × to remove · Tab / arrows / Del"
                            color: Theme.surfaceVariantFg
                            font.pixelSize: Tokens.font.xs
                        }
                    }
                    Item { implicitWidth: Tokens.space.s }
                    ToolButton { icon: "add"; label: "Add"; primary: root.pickerOpen; onClicked: root.pickerOpen = !root.pickerOpen }
                    ToolButton { icon: "restart_alt"; label: "Reset"; onClicked: { DesktopCards.reset(root.screenName); root.flash("Layout reset"); } }
                    ToolButton { icon: "check"; label: "Done"; primary: true; onClicked: DesktopCards.setEditing(false) }
                }
            }

            Rectangle {
                id: picker
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: toolbar.bottom
                anchors.topMargin: Tokens.space.s
                width: Math.min(parent.width - Tokens.space.xl * 2, 560)
                implicitHeight: pickerGrid.implicitHeight + Tokens.space.l * 2
                radius: Tokens.radius.xl
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Theme.alpha(Theme.outlineVariant, 0.6)
                z: 20
                opacity: root.pickerOpen && root.editing ? 1 : 0
                scale: root.pickerOpen && root.editing ? 1 : 0.94
                transformOrigin: Item.Top
                visible: opacity > 0
                Behavior on opacity { Anim { duration: Motion.duration.short } }
                Behavior on scale { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }

                GridLayout {
                    id: pickerGrid
                    anchors.fill: parent
                    anchors.margins: Tokens.space.l
                    columns: 3
                    rowSpacing: Tokens.space.s
                    columnSpacing: Tokens.space.s

                    Repeater {
                        model: DesktopCards.catalog.filter(d => d.needs !== "weather" || CardStyle.weatherAvailable)

                        Surface {
                            id: entry
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 56
                            radius: Tokens.radius.l
                            interactive: true
                            base: Theme.surfaceHigh
                            onClicked: root.addCard(modelData.type)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.space.s
                                anchors.rightMargin: Tokens.space.m
                                spacing: Tokens.space.s
                                Rectangle {
                                    implicitWidth: 38; implicitHeight: 38; radius: Tokens.radius.m
                                    color: Theme.secondaryContainer
                                    Icon { anchors.centerIn: parent; text: entry.modelData.icon; size: 20; fill: 1; color: Theme.secondaryContainerFg }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -2
                                    StyledText { Layout.fillWidth: true; text: entry.modelData.name; font.weight: Font.DemiBold }
                                    StyledText {
                                        text: `${entry.modelData.w} × ${entry.modelData.h}`
                                        color: Theme.surfaceVariantFg
                                        font.pixelSize: Tokens.font.xs
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Toast.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.space.xl
        implicitWidth: toastText.implicitWidth + Tokens.space.l * 2
        implicitHeight: 40
        radius: 20
        color: Theme.inverseSurface
        z: 30
        opacity: root.toast !== "" && root.editing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { duration: Motion.duration.short } }
        StyledText {
            id: toastText
            anchors.centerIn: parent
            text: root.toast
            color: Theme.inverseOnSurface
        }
    }

    component ToolButton: Surface {
        id: tb
        property string icon
        property string label
        property bool primary: false
        implicitWidth: tbRow.implicitWidth + Tokens.space.l * 2
        implicitHeight: 40
        radius: 20
        interactive: true
        base: primary ? Theme.primary : Theme.surfaceHigh
        content: primary ? Theme.primaryFg : Theme.surfaceFg
        RowLayout {
            id: tbRow
            anchors.centerIn: parent
            spacing: Tokens.space.xs
            Icon { text: tb.icon; size: 18; color: tb.content }
            StyledText { text: tb.label; color: tb.content; font.weight: Font.DemiBold }
        }
    }
}
