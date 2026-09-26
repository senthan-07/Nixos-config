import QtQuick
import qs.config
import qs.components
import qs.services

// macOS-style "fan" for the folder stack: the newest files rise from the
// stack along a gentle arc, labels on the left, "Open folder" on top.
// Place it so that `anchorX` (icon column) sits over the stack.
Item {
    id: root

    property bool open: false
    property real maxHeight: 520
    property int current: -1
    readonly property real step: 54
    readonly property real iconSize: 42
    readonly property real anchorX: width - 40
    readonly property var files: Dock.files.slice(0, Math.max(1, Math.floor((maxHeight - step) / step)))
    readonly property int hidden: Math.max(0, Dock.fileTotal - files.length)
    // Entries from bottom (newest file) to top ("open folder").
    readonly property var entries: {
        const out = files.map(f => ({ kind: "file", file: f }));
        if (!files.length)
            out.push({ kind: "empty" });
        out.push({ kind: "open" });
        return out;
    }
    readonly property bool hovered: hover.hovered
    property real progress: open ? 1 : 0

    signal done()

    width: 420
    height: entries.length * step + 12
    visible: open || progress > 0.001
    Behavior on progress { Anim { duration: root.open ? Motion.duration.long : Motion.duration.short; easing.bezierCurve: root.open ? Motion.curve.emphasizedDecel : Motion.curve.emphasizedAccel } }

    onOpenChanged: if (open) { current = -1; Qt.callLater(() => root.forceActiveFocus()); Dock.refreshFolder(); }

    function trigger(i) {
        const e = entries[i];
        if (!e || e.kind === "empty") return;
        Dock.openPath(e.kind === "open" ? Dock.folder : e.file.path);
        root.done();
    }
    function move(delta) {
        const n = entries.length;
        let i = current < 0 ? (delta > 0 ? 0 : n - 1) : current + delta;
        i = Math.max(0, Math.min(n - 1, i));
        if (entries[i].kind === "empty") i = Math.max(0, Math.min(n - 1, i + delta));
        current = i;
    }

    focus: open
    Keys.onUpPressed: move(1)
    Keys.onDownPressed: move(-1)
    Keys.onReturnPressed: trigger(current)
    Keys.onEnterPressed: trigger(current)
    Keys.onEscapePressed: done()

    HoverHandler { id: hover }

    Repeater {
        model: root.entries

        Item {
            id: tile
            required property var modelData
            required property int index
            readonly property int n: root.entries.length
            // Staggered progress: lower tiles leave the stack first.
            readonly property real p: Math.max(0, Math.min(1, root.progress * (1 + 0.06 * n) - 0.06 * index))
            readonly property real finalCx: root.anchorX + 0.6 * index * index
            readonly property real finalCy: root.height - root.step * (index + 0.5) - 6
            readonly property bool active: root.current === index || mouse.containsMouse
            readonly property bool isOpen: modelData.kind === "open"
            readonly property bool isEmpty: modelData.kind === "empty"

            width: root.width
            height: root.step
            x: (finalCx - root.anchorX) * p
            y: finalCy - height / 2 + (root.height - finalCy) * (1 - p)
            opacity: Math.min(1, p * 1.5)
            z: n - index
            transform: Rotation {
                origin.x: root.anchorX
                origin.y: tile.height / 2
                angle: (tile.index * 0.8) * tile.p
            }

            // Label pill, right-aligned against the icon.
            Rectangle {
                id: pill
                x: root.anchorX - root.iconSize / 2 - Tokens.space.s - width
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(root.anchorX - root.iconSize / 2 - Tokens.space.s, label.implicitWidth + Tokens.space.l * 2)
                height: 28
                radius: height / 2
                color: tile.active ? Theme.secondaryContainer : Theme.alpha(Theme.surfaceContainer, 0.94)
                border.width: 1
                border.color: Theme.alpha(Theme.outlineVariant, 0.6)
                opacity: Math.max(0, (tile.p - 0.4) / 0.6)
                Behavior on color { ColorAnim {} }

                StyledText {
                    id: label
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - Tokens.space.l * 2)
                    text: tile.isOpen ? (root.hidden > 0 ? `Open ${Dock.folderName}  ·  ${root.hidden} more` : `Open ${Dock.folderName}`)
                        : tile.isEmpty ? (Dock.folderError || (Dock.folderLoading ? "Loading…" : "Nothing here yet"))
                        : tile.modelData.file.name
                    font.pixelSize: Tokens.font.s
                    font.weight: tile.isOpen ? Font.DemiBold : Font.Normal
                    color: tile.active ? Theme.secondaryContainerFg : tile.isEmpty ? Theme.surfaceVariantFg : Theme.surfaceFg
                }
            }

            Item {
                width: root.iconSize
                height: root.iconSize
                x: root.anchorX - width / 2
                anchors.verticalCenter: parent.verticalCenter
                scale: (0.6 + 0.4 * tile.p) * (tile.active && !tile.isEmpty ? 1.08 : 1)
                Behavior on scale { enabled: tile.p >= 1; Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.springFast } }
                visible: !tile.isEmpty

                DockFileGlyph {
                    anchors.fill: parent
                    visible: !tile.isOpen
                    size: root.iconSize
                    file: tile.isOpen ? null : tile.modelData.file
                }
                Rectangle {
                    anchors.fill: parent
                    visible: tile.isOpen
                    radius: width / 2
                    color: tile.active ? Theme.primary : Theme.primaryContainer
                    Icon {
                        anchors.centerIn: parent
                        text: "open_in_new"
                        size: 20
                        color: tile.active ? Theme.primaryFg : Theme.primaryContainerFg
                    }
                }
            }

            MouseArea {
                id: mouse
                x: pill.x
                width: root.anchorX + root.iconSize / 2 - x
                height: parent.height
                enabled: !tile.isEmpty && tile.p > 0.9
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: root.current = tile.index
                onClicked: m => {
                    if (m.button === Qt.RightButton && !tile.isOpen) {
                        // Reveal: open the containing folder instead.
                        Dock.openPath(Dock.folder);
                        root.done();
                    } else {
                        root.trigger(tile.index);
                    }
                }
            }
        }
    }
}
