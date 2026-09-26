import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components

RowLayout {
    id: root

    readonly property Toplevel toplevel: ToplevelManager.activeToplevel
    readonly property var entry: toplevel ? DesktopEntries.heuristicLookup(toplevel.appId) : null

    spacing: Tokens.space.s

    AppIcon {
        size: 18
        name: root.entry?.icon ?? root.toplevel?.appId ?? ""
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -2

        StyledText {
            Layout.fillWidth: true
            text: root.entry?.name ?? root.toplevel?.appId ?? ""
            font.pixelSize: Tokens.font.xs
            color: Theme.surfaceVariantFg
        }
        StyledText {
            Layout.fillWidth: true
            text: root.toplevel?.title ?? ""
            font.weight: Font.Medium
        }
    }
}
