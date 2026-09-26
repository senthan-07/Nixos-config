import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

RowLayout {
    Layout.fillWidth: true
    spacing: Tokens.space.m

    readonly property string user: Quickshell.env("USER") || "user"

    Rectangle {
        implicitWidth: 48
        implicitHeight: 48
        radius: Tokens.radius.l
        color: Theme.tertiaryContainer
        StyledText {
            anchors.centerIn: parent
            text: parent.parent.user.charAt(0).toUpperCase()
            font.pixelSize: Tokens.font.xxl
            font.weight: Font.Bold
            color: Theme.tertiaryContainerFg
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 0
        StyledText {
            Layout.fillWidth: true
            text: parent.parent.user
            font.pixelSize: Tokens.font.l
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.fillWidth: true
            text: `up ${SysStats.uptime}  ·  ${SysStats.memUsedGiB.toFixed(1)}/${SysStats.memTotalGiB.toFixed(0)} GiB  ·  disk ${Math.round(SysStats.disk * 100)}%`
            font.pixelSize: Tokens.font.s
            color: Theme.surfaceVariantFg
        }
    }

    IconButton {
        icon: "settings"
        filled: true
        onClicked: Panels.openSettings("")
    }
    IconButton {
        icon: "wallpaper"
        filled: true
        onClicked: Panels.openLauncher(":")
    }
    IconButton {
        icon: "lock"
        filled: true
        onClicked: { Panels.closeAll(); Panels.locked = true; }
    }
    IconButton {
        icon: "power_settings_new"
        filled: true
        onClicked: Panels.toggle("power")
    }
}
