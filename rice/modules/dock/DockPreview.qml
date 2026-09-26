import QtQuick
import qs.config
import qs.components
import qs.services

// Hover preview for a running app: one card per window with a live
// thumbnail (or a compact title list when thumbnails are off).
DockBubble {
    id: root

    property string key
    property real maxWidth: 1200
    readonly property var windows: key ? Dock.windowsFor(key) : []
    readonly property bool thumbs: Dock.showPreviews
    readonly property int count: windows.length
    readonly property real gap: Tokens.space.xs
    readonly property real cardWidth: thumbs
        ? Math.max(120, Math.min(240, (maxWidth - padding * 2 - gap * (count - 1)) / Math.max(1, count)))
        : 280
    readonly property real cardHeight: thumbs ? 36 + (cardWidth - Tokens.space.s * 2) / 1.6 + Tokens.space.s : 36

    signal done()

    contentWidth: thumbs ? count * cardWidth + Math.max(0, count - 1) * gap : cardWidth
    contentHeight: thumbs ? cardHeight : count * cardHeight + Math.max(0, count - 1) * gap
    width: implicitWidth
    height: implicitHeight
    padding: Tokens.space.xs + 2

    Behavior on contentWidth { enabled: root.progress > 0.99; Anim { duration: Motion.duration.short } }

    Grid {
        columns: root.thumbs ? Math.max(1, root.count) : 1
        spacing: root.gap

        Repeater {
            model: root.windows
            DockWindowCard {
                required property var modelData
                toplevel: modelData
                appKey: root.key
                thumbnails: root.thumbs
                live: root.open
                width: root.cardWidth
                height: root.cardHeight
                onPicked: { modelData.activate(); root.done(); }
                onCloseRequested: modelData.close()
            }
        }
    }
}
