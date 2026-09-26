import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Centered icon + message for empty, loading and error states.
ColumnLayout {
    id: root

    property string icon: "info"
    property string text
    property bool busy: false

    spacing: Tokens.space.xs

    Icon {
        id: glyph
        Layout.alignment: Qt.AlignHCenter
        text: root.busy ? "progress_activity" : root.icon
        size: 28
        color: Theme.alpha(Theme.surfaceVariantFg, 0.8)
        RotationAnimation on rotation {
            running: root.busy && root.visible
            from: 0; to: 360
            duration: 1100
            loops: Animation.Infinite
            onRunningChanged: if (!running) glyph.rotation = 0
        }
    }
    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: root.parent ? root.parent.width - Tokens.space.l : 200
        text: root.text
        color: Theme.surfaceVariantFg
        font.pixelSize: Tokens.font.s
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}
