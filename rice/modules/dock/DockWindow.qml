import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// One dock per screen: a floating, bottom-centred M3 surface with
// magnification, running indicators, drag-to-reorder, window previews,
// context menus and a folder stack. The layer surface is tall enough to host
// its popups; an input mask keeps everything else click-through.
PanelWindow {
    id: win

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Math.round(Math.min((screen ? screen.height : 1080) * 0.8, 700))
    color: "transparent"
    exclusionMode: Dock.autohide ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: Dock.autohide ? 0 : restHeight + margin + Tokens.space.xs
    WlrLayershell.namespace: "rice-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: menuKey !== "" || fanOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---------------------------------------------------------------- metrics
    readonly property real iconSize: Dock.iconSize
    readonly property real magnify: Dock.magnification ? Dock.magnifyScale : 1
    readonly property real maxIcon: Math.ceil(iconSize * magnify)
    readonly property real slotGap: 6
    readonly property real pad: Dock.padding
    readonly property real divWidth: 13
    readonly property real restHeight: iconSize + pad * 2 + 6
    readonly property real margin: Dock.edgeGap
    readonly property real bodyTop: height - margin - restHeight
    readonly property real iconBottom: height - margin - pad - 6
    // Popups sit above the tallest magnified icon.
    readonly property real popupBottom: bodyTop - (maxIcon - iconSize) - Tokens.space.s

    // ------------------------------------------------------------------ slots
    property string dragKey: ""
    property point dragPos: Qt.point(0, 0)
    property int insertion: -1
    property bool removing: false

    readonly property bool dragPinned: dragKey !== "" && Dock.isPinned(dragKey)
    readonly property var appKeys: {
        const keys = Dock.keys.slice();
        if (!dragKey) return keys;
        const from = keys.indexOf(dragKey);
        // A slot being dragged off keeps its delegate (it owns the pointer
        // grab) but collapses to zero width; see `slots`.
        if (!removing && insertion >= 0 && from >= 0) {
            keys.splice(from, 1);
            keys.splice(Math.min(insertion, keys.length), 0, dragKey);
        }
        return keys;
    }
    readonly property int pinnedShown: {
        let n = Dock.pinnedCount;
        if (dragKey && !dragPinned && insertion >= 0 && !removing) n++;
        if (dragKey && dragPinned && removing) n--;
        return n;
    }
    readonly property var slots: {
        const out = [];
        appKeys.forEach((k, i) => {
            // While removing, the collapsed slot still sits among the pinned ones.
            const boundary = removing ? Dock.pinnedCount : pinnedShown;
            if (i === boundary && pinnedShown > 0) out.push({ id: "div:apps", kind: "div" });
            out.push({ id: "app:" + k, kind: removing && k === dragKey ? "gone" : "app", key: k });
        });
        if (Dock.showFolder) {
            if (appKeys.length) out.push({ id: "div:folder", kind: "div" });
            out.push({ id: "folder", kind: "folder" });
        }
        return out;
    }
    readonly property bool empty: slots.length === 0

    function slotWidth(kind) { return kind === "div" ? divWidth : iconSize; }

    readonly property real restLength: {
        let len = pad * 2;
        let first = true;
        for (const s of slots) {
            if (s.kind === "gone") continue;
            len += slotWidth(s.kind) + (first ? 0 : slotGap);
            first = false;
        }
        return Math.max(len, empty ? 180 : 0);
    }
    readonly property real restLeft: (width - restLength) / 2

    // Magnification: a raised-cosine bump centred on the pointer, computed in
    // the resting coordinate system so icons never chase the cursor.
    property real pointerX: -1
    property real amp: magnifying ? 1 : 0
    Behavior on amp { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.standard } }
    readonly property bool magnifying: magnify > 1 && pointerInDock && !dragKey && menuKey === "" && !fanOpen

    readonly property var layout: {
        const radius = 2.6;
        const px = pointerX - restLeft;
        const map = {};
        let rest = pad;
        let cursor = pad;
        // Where the pointer's resting position lands in the magnified row; the
        // row is shifted so that this point stays under the pointer.
        let mapped = px;
        let first = true;
        slots.forEach(s => {
            if (s.kind === "gone") {
                map[s.id] = { x: cursor, size: 0 };
                return;
            }
            const i = first ? 0 : 1;
            first = false;
            if (i) { rest += slotGap; cursor += slotGap; }
            const w = slotWidth(s.kind);
            let size = w;
            if (s.kind === "app" && amp > 0) {
                const d = Math.abs(px - (rest + w / 2)) / (iconSize + slotGap);
                const f = d >= radius ? 0 : (1 + Math.cos(Math.PI * d / radius)) / 2;
                size = w * (1 + (magnify - 1) * amp * f);
            }
            if (px >= rest - (i ? slotGap : 0) && px < rest + w)
                mapped = cursor + (px - rest) * size / w;
            map[s.id] = { x: cursor, size: size };
            rest += w;
            cursor += size;
        });
        const length = Math.max(cursor + pad, empty ? 180 : 0);
        if (px >= rest) mapped = length - (restLength - px);
        let left = amp > 0 ? restLeft + px - mapped : (width - length) / 2;
        left = Math.max(8, Math.min(width - length - 8, left));
        return { map: map, length: length, left: left };
    }
    readonly property real bodyX: layout.left
    // Reflow (model changes, drag) animates; live magnification doesn't.
    readonly property bool reflow: amp === 0

    function slotOf(id) { return layout.map[id] || { x: 0, size: iconSize }; }
    function centerOf(id) { const s = slotOf(id); return bodyX + s.x + s.size / 2; }

    // ------------------------------------------------------------ visibility
    readonly property HyprlandMonitor hyprMonitor: HyprMonitors.forScreen(screen)
    readonly property bool hyprland: !!hyprMonitor && !!hyprMonitor.activeWorkspace
    readonly property bool overlapped: {
        if (!hyprland || !screen) return false;
        const ws = hyprMonitor.activeWorkspace;
        if (ws.hasFullscreen) return true;
        const top = screen.height - margin - restHeight;
        const left = restLeft, right = restLeft + restLength;
        for (const t of ws.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.at || !o.size || o.hidden) continue;
            const x = o.at[0] - hyprMonitor.x, y = o.at[1] - hyprMonitor.y;
            if (y + o.size[1] > top && x < right && x + o.size[0] > left) return true;
        }
        return false;
    }

    readonly property bool busy: pointerInDock || previewKey !== "" || menuKey !== "" || fanOpen || dragKey !== ""
    property bool revealed: false
    readonly property bool wantHide: Dock.autohide && (!Dock.smartHide || !hyprland || overlapped)
    readonly property bool hidden: wantHide && !revealed && !busy
    onBusyChanged: {
        if (busy) { revealed = true; hideTimer.stop(); }
        else hideTimer.restart();
    }

    Timer { id: hideTimer; interval: 600; onTriggered: win.revealed = false }
    Timer { id: revealTimer; interval: 140; onTriggered: { win.revealed = true; hideTimer.restart(); } }

    // Keep Hyprland window geometry fresh for the overlap test. Events cover
    // most changes, but relayouts (e.g. the exclusive zone going away), window
    // drags and resizes send none, so also poll while smart hide is active.
    readonly property bool trackWindows: Dock.autohide && Dock.smartHide && hyprland
    onTrackWindowsChanged: if (trackWindows) hyprRefresh.restart()
    Timer { id: hyprRefresh; interval: 150; onTriggered: Hyprland.refreshToplevels() }
    Timer {
        interval: 500
        repeat: true
        running: win.trackWindows
        onTriggered: Hyprland.refreshToplevels()
    }
    Connections {
        target: Hyprland
        enabled: Dock.autohide && Dock.smartHide
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "fullscreen",
                 "workspace", "workspacev2", "activewindowv2", "moveworkspace", "focusedmon"].indexOf(event.name) >= 0)
                hyprRefresh.restart();
        }
    }

    // ------------------------------------------------------------- popups
    property string hoverKey: ""        // "app:<key>" or "folder" under the pointer
    property string previewKey: ""      // app whose windows are previewed
    property string menuKey: ""         // "app:<key>", "folder" or "dock"
    property real menuAnchor: width / 2
    property bool fanOpen: false
    property var menuRows: []

    function closePopups() {
        previewKey = "";
        menuKey = "";
        fanOpen = false;
        previewTimer.stop();
    }

    function hoverEnter(id) {
        hoverKey = id;
        previewClose.stop();
        if (menuKey !== "" || fanOpen || dragKey) return;
        const key = id.startsWith("app:") ? id.slice(4) : "";
        const running = key && Dock.windowsFor(key).length > 0;
        if (previewKey !== "") {
            if (running) previewKey = key;   // slide straight to the neighbour
            else previewKey = "";
        } else if (running) {
            previewTimer.restart();
        }
    }
    function hoverExit(id) {
        // Enter of the next item can arrive before exit of the previous one.
        if (hoverKey !== id) return;
        hoverKey = "";
        previewTimer.stop();
        if (previewKey !== "") previewClose.restart();
    }

    Timer {
        id: previewTimer
        interval: 450
        onTriggered: {
            const key = win.hoverKey.startsWith("app:") ? win.hoverKey.slice(4) : "";
            if (key && Dock.windowsFor(key).length > 0 && win.menuKey === "" && !win.fanOpen && !win.dragKey)
                win.previewKey = key;
        }
    }
    Timer {
        id: previewClose
        interval: 280
        onTriggered: {
            if (!preview.hovered && win.hoverKey !== "app:" + win.previewKey) win.previewKey = "";
        }
    }
    // Close an empty preview (last window closed).
    Connections {
        target: Dock
        function onGroupsChanged() {
            if (win.previewKey && !Dock.windowsFor(win.previewKey).length) win.previewKey = "";
        }
    }

    function openMenu(id) {
        previewKey = "";
        previewTimer.stop();
        fanOpen = false;
        menuRows = buildMenu(id);
        menuAnchor = id === "dock" ? pointerX : centerOf(id);
        menuKey = id;
    }

    function openSettings() {
        Quickshell.execDetached(["qs", "-p", Quickshell.shellDir, "ipc", "call", "settings", "page", "Dock"]);
    }

    function buildMenu(id) {
        const rows = [];
        if (id === "folder") {
            rows.push({ kind: "header", label: Dock.folderName, icon: "folder-download", sub: Dock.folder });
            rows.push({ kind: "item", icon: "folder_open", label: `Open ${Dock.folderName}`, run: () => Dock.openPath(Dock.folder) });
            rows.push({ kind: "item", icon: "refresh", label: "Refresh", run: () => Dock.refreshFolder() });
            rows.push({ kind: "sep" });
            rows.push({ kind: "item", icon: "visibility_off", label: "Hide folder stack", run: () => Dock.setShowFolder(false) });
            rows.push({ kind: "item", icon: "settings", label: "Dock settings…", run: () => win.openSettings() });
            return rows;
        }
        if (id === "dock") {
            rows.push({ kind: "item", icon: Dock.autohide ? "check_box" : "check_box_outline_blank", label: "Automatically hide", run: () => Dock.setAutohide(!Dock.autohide) });
            rows.push({ kind: "item", icon: Dock.magnification ? "check_box" : "check_box_outline_blank", label: "Magnification", run: () => Dock.setMagnification(!Dock.magnification) });
            rows.push({ kind: "item", icon: Dock.showFolder ? "check_box" : "check_box_outline_blank", label: "Show folder stack", run: () => Dock.setShowFolder(!Dock.showFolder) });
            rows.push({ kind: "sep" });
            rows.push({ kind: "item", icon: "settings", label: "Dock settings…", run: () => win.openSettings() });
            return rows;
        }
        const key = id.slice(4);
        const entry = Dock.entryFor(key);
        const wins = Dock.windowsFor(key);
        const pinned = Dock.isPinned(key);
        rows.push({ kind: "header", label: Dock.nameFor(key), icon: Dock.iconFor(key),
                    sub: wins.length ? `${wins.length} window${wins.length > 1 ? "s" : ""} open` : pinned ? "Kept in dock" : "" });
        if (wins.length > 1) {
            rows.push({ kind: "sep" });
            wins.slice(0, 6).forEach(t => rows.push({ kind: "item", icon: t.activated ? "select_window" : "web_asset",
                                                      label: t.title || Dock.nameFor(key), run: () => t.activate() }));
        }
        const actions = entry && entry.actions ? entry.actions : [];
        if (actions.length) {
            rows.push({ kind: "sep" });
            actions.slice(0, 8).forEach(a => rows.push({ kind: "item", icon: "bolt", appIcon: a.icon || "",
                                                         label: a.name, run: () => Apps.run(a.command) }));
        }
        rows.push({ kind: "sep" });
        if (entry)
            rows.push({ kind: "item", icon: wins.length ? "add" : "open_in_new", label: wins.length ? "New window" : "Open",
                        run: () => Dock.launch(key) });
        if (entry || pinned)
            rows.push(pinned ? { kind: "item", icon: "keep_off", label: "Remove from dock", run: () => Dock.unpin(key) }
                             : { kind: "item", icon: "keep", label: "Keep in dock", run: () => Dock.pin(key) });
        if (wins.length)
            rows.push({ kind: "item", icon: "close", danger: true, label: wins.length > 1 ? `Quit (${wins.length} windows)` : "Quit",
                        run: () => Dock.closeAll(key) });
        return rows;
    }

    // Hyprland drops a focus grab that starts in the same frame the surface
    // changes its keyboard focus and input mask, which closed the menu right
    // after it opened. Arm the grab a moment later instead.
    readonly property bool popupOpen: menuKey !== "" || fanOpen
    property bool grabArmed: false
    onPopupOpenChanged: {
        grabArmed = false;
        if (popupOpen) grabDelay.restart();
    }
    Timer {
        id: grabDelay
        interval: 150
        onTriggered: win.grabArmed = win.popupOpen
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.grabArmed
        onCleared: win.closePopups()
    }

    // --------------------------------------------------------------- drag
    function insertionAt(p) {
        const pinnedOthers = Dock.pinnedKeys.filter(k => k !== dragKey).length;
        const rel = p.x - restLeft - pad - iconSize / 2;
        const idx = Math.round(rel / (iconSize + slotGap));
        if (!dragPinned && idx > pinnedOthers) return -1;      // stays a running app
        return Math.max(0, Math.min(pinnedOthers, idx));
    }
    function dragStart(key, p) {
        closePopups();
        dragKey = key;
        dragMove(p);
    }
    function dragMove(p) {
        dragPos = p;
        removing = dragPinned && p.y < bodyTop - 70;
        insertion = removing ? -1 : insertionAt(p);
    }
    function dragEnd(p) {
        const key = dragKey;
        if (p.x >= 0 && key) {
            if (removing) {
                ghost.poof();
                Dock.unpin(key);
            } else if (insertion >= 0) {
                Dock.movePinned(key, insertion);
            }
        }
        dragKey = "";
        removing = false;
        insertion = -1;
    }

    // ------------------------------------------------------------- input mask
    // While dragging, take the whole surface so the release is never lost.
    mask: Region {
        item: win.dragKey !== "" ? dragArea : win.hidden ? hotStrip : inputArea
        Region { item: preview.visible ? preview : null }
        Region { item: menu.visible ? menu : null }
        Region { item: fan.visible ? fan : null }
    }

    Item {
        id: dragArea
        anchors.fill: parent
    }

    Item {
        id: hotStrip
        x: win.restLeft - 20
        width: win.restLength + 40
        y: win.height - 3
        height: 3
        HoverHandler {
            onHoveredChanged: if (hovered) revealTimer.restart(); else revealTimer.stop()
        }
    }

    // Everything that belongs to the dock body (and nothing else) lives in
    // `stage`, so its HoverHandler tells us whether the pointer is on the dock.
    readonly property bool pointerInDock: stageHover.hovered
        && stageHover.point.position.x >= bodyX - 4 && stageHover.point.position.x <= bodyX + layout.length + 4
        && stageHover.point.position.y >= popupBottom + Tokens.space.s - 2
    onPointerInDockChanged: if (!pointerInDock) hoverKey = ""

    Item {
        id: inputArea
        x: win.bodyX - 4
        width: win.layout.length + 8
        y: win.pointerInDock || win.amp > 0 ? win.popupBottom + Tokens.space.s - 2 : win.bodyTop
        height: win.height - y
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: 1 - hideShift.progress * 0.6
        transform: Translate { id: hideShift; property real progress: win.hidden ? 1 : 0; y: progress * (win.restHeight + win.margin + 24)
            Behavior on progress { Anim { duration: Motion.duration.medium; easing.bezierCurve: win.hidden ? Motion.curve.emphasizedAccel : Motion.curve.emphasizedDecel } }
        }

        HoverHandler {
            id: stageHover
            onPointChanged: if (hovered && !win.dragKey) win.pointerX = point.position.x
        }

        RectangularShadow {
            anchors.fill: body
            radius: body.radius
            blur: 28
            spread: -4
            offset.y: 8
            color: Theme.alpha(Theme.shadow, Theme.dark ? 0.45 : 0.18)
        }

        Rectangle {
            id: body
            x: win.bodyX
            y: win.bodyTop
            width: win.layout.length
            height: win.restHeight
            radius: Math.min(Tokens.radius.xl, height / 2)
            color: Theme.alpha(Theme.surface, 0.88)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.55)
            Behavior on x { enabled: win.reflow; Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }
            Behavior on width { enabled: win.reflow; Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }

            // Right-click on the bare dock: quick options.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: win.openMenu("dock")
            }

            StyledText {
                anchors.centerIn: parent
                visible: win.empty
                text: "Dock is empty"
                color: Theme.surfaceVariantFg
                font.pixelSize: Tokens.font.s
            }
        }

        // Dividers between pinned / running apps and the folder stack.
        Repeater {
            model: win.slots.filter(s => s.kind === "div")
            Rectangle {
                required property var modelData
                readonly property var slot: win.slotOf(modelData.id)
                x: win.bodyX + slot.x + slot.size / 2
                width: 1
                y: win.bodyTop + win.pad + 4
                height: win.restHeight - win.pad * 2 - 8
                color: Theme.alpha(Theme.outlineVariant, 0.9)
                Behavior on x { enabled: win.reflow; Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }
            }
        }

        Repeater {
            model: ScriptModel { values: win.appKeys }

            DockItem {
                id: item
                required property string modelData
                readonly property string slotId: "app:" + modelData
                readonly property var slot: win.slotOf(slotId)

                key: modelData
                size: slot.size
                restSize: win.iconSize
                maxSize: win.maxIcon
                x: win.bodyX + slot.x
                y: win.iconBottom - size
                dragging: win.dragKey === modelData
                highlighted: win.menuKey === slotId
                Behavior on x { enabled: win.reflow; Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }

                onEntered: win.hoverEnter(slotId)
                onExited: win.hoverExit(slotId)
                onActivated: {
                    win.closePopups();
                    Dock.activate(modelData);
                }
                onMiddleClicked: Dock.launch(modelData)
                onContextRequested: win.menuKey === slotId ? win.closePopups() : win.openMenu(slotId)
                onDragStarted: p => win.dragStart(modelData, p)
                onDragMoved: p => win.dragMove(p)
                onDragFinished: p => win.dragEnd(p)
            }
        }

        DockStack {
            id: stack
            readonly property var slot: win.slotOf("folder")
            visible: Dock.showFolder
            open: win.fanOpen
            size: slot.size
            maxSize: win.maxIcon
            x: win.bodyX + slot.x
            y: win.iconBottom - size
            Behavior on x { enabled: win.reflow; Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }
            onEntered: win.hoverEnter("folder")
            onExited: win.hoverExit("folder")
            onActivated: {
                const next = !win.fanOpen;
                win.closePopups();
                win.fanOpen = next;
            }
            onContextRequested: win.openMenu("folder")
        }
    }

    // ----------------------------------------------------------- overlays
    // Tooltip with the app name (hidden while a popup is open).
    Rectangle {
        id: tooltip
        readonly property string target: win.hoverKey
        readonly property bool shown: target !== "" && win.previewKey === "" && win.menuKey === "" && !win.fanOpen && !win.dragKey && !win.hidden
        property string text: ""
        // Remember the last target so the pill fades out where it was.
        property string last: ""
        onTargetChanged: if (target) {
            last = target;
            text = target === "folder" ? Dock.folderName : Dock.nameFor(target.slice(4));
        }
        x: Math.round(Math.max(8, Math.min(win.width - width - 8, (last ? win.centerOf(last) : win.width / 2) - width / 2)))
        y: Math.round(win.iconBottom - (last ? win.slotOf(last).size : win.iconSize) - height - 10)
        width: label.implicitWidth + Tokens.space.l * 2
        height: 30
        radius: height / 2
        color: Theme.inverseSurface
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { duration: Motion.duration.tiny } }
        StyledText {
            id: label
            anchors.centerIn: parent
            text: tooltip.text
            color: Theme.inverseOnSurface
            font.pixelSize: Tokens.font.s
            font.weight: Font.Medium
        }
    }

    DockPreview {
        id: preview
        property string shownKey: ""
        readonly property real anchorX: shownKey ? win.centerOf("app:" + shownKey) : win.width / 2
        open: win.previewKey !== ""
        onOpenChanged: if (open) shownKey = win.previewKey
        Connections {
            target: win
            function onPreviewKeyChanged() { if (win.previewKey) preview.shownKey = win.previewKey; }
        }
        key: shownKey
        maxWidth: win.width - 32
        bridge: win.bodyTop - win.popupBottom
        x: Math.round(Math.max(16, Math.min(win.width - width - 16, anchorX - width / 2)))
        y: win.bodyTop - height
        tailX: anchorX - x
        onHoveredChanged: if (!hovered && win.hoverKey !== "app:" + win.previewKey) previewClose.restart(); else previewClose.stop()
        onDone: win.closePopups()
    }

    DockMenu {
        id: menu
        property real anchorX: win.menuAnchor
        open: win.menuKey !== ""
        rows: win.menuRows
        bridge: win.bodyTop - win.popupBottom
        x: Math.round(Math.max(16, Math.min(win.width - width - 16, anchorX - width / 2)))
        y: win.bodyTop - height
        tailX: anchorX - x
        onDone: win.closePopups()
    }

    DockFan {
        id: fan
        open: win.fanOpen
        maxHeight: win.popupBottom - 40
        x: Math.round(win.centerOf("folder") - anchorX)
        y: win.popupBottom + Tokens.space.s - height
        onDone: win.closePopups()
    }

    // Drag ghost: follows the pointer; turns into a "remove" hint above the dock.
    Item {
        id: ghost
        property bool poofing: false
        visible: win.dragKey !== "" || poofing
        width: win.iconSize * 1.1
        height: width
        x: win.dragPos.x - width / 2
        y: win.dragPos.y - height / 2
        property string key: ""
        Connections {
            target: win
            function onDragKeyChanged() { if (win.dragKey) { ghost.key = win.dragKey; ghost.poofing = false; ghost.opacity = 1; ghost.scale = 1; } }
        }

        function poof() {
            poofing = true;
            poofAnim.restart();
        }
        ParallelAnimation {
            id: poofAnim
            Anim { target: ghost; property: "scale"; to: 1.5; duration: Motion.duration.short }
            Anim { target: ghost; property: "opacity"; to: 0; duration: Motion.duration.short }
            onFinished: ghost.poofing = false
        }

        AppIcon {
            anchors.fill: parent
            size: parent.width
            name: ghost.key ? Dock.iconFor(ghost.key) : ""
            opacity: win.removing ? 0.55 : 1
            Behavior on opacity { Anim { duration: Motion.duration.tiny } }
        }
        Rectangle {
            visible: win.removing
            width: 22; height: 22; radius: 11
            x: parent.width - 16; y: -6
            color: Theme.errorContainer
            Icon { anchors.centerIn: parent; text: "remove"; size: 16; color: Theme.errorContainerFg }
        }
    }
}
