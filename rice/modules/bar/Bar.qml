import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.config
import qs.components
import qs.services
import qs.modules.capture
import qs.modules.dashboard
import qs.modules.island

PanelWindow {
    id: root

    readonly property bool floating: Settings.data.floatingBar
    readonly property bool bottom: Settings.data.barPosition === "bottom"
    readonly property int gap: floating ? Tokens.bar.gap : 0

    anchors { top: !bottom; bottom: bottom; left: true; right: true }
    implicitHeight: Tokens.bar.height + gap
    exclusiveZone: implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "rice-bar"
    WlrLayershell.layer: WlrLayer.Top

    IdleInhibitor {
        window: root
        enabled: Panels.caffeine && root.screen === Quickshell.screens[0]
    }

    Rectangle {
        id: body
        anchors.fill: parent
        anchors.topMargin: root.bottom ? 0 : root.gap
        anchors.bottomMargin: root.bottom ? root.gap : 0
        anchors.leftMargin: root.gap * 2
        anchors.rightMargin: root.gap * 2
        radius: root.floating ? Tokens.radius.l : 0
        color: Theme.alpha(Theme.surface, Settings.data.surfaceOpacity)
        border.width: root.floating ? 1 : 0
        border.color: Theme.alpha(Theme.outlineVariant, 0.5)

        Behavior on radius { Anim {} }

        // Left: launcher, workspaces, active window.
        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.space.xs + 1
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.space.s

            // Launcher button: NixOS snowflake (nixos-icons), tinted to the theme.
            IconButton {
                id: launcherButton
                readonly property string snowflake: Quickshell.iconPath("nix-snowflake-white", true)
                size: Tokens.bar.chipHeight
                icon: snowflake ? "" : "ac_unit"          // Material fallback if the icon is missing
                iconSize: 18
                toggled: Panels.launcher
                base: toggled ? Theme.primary : Theme.primaryContainer
                content: toggled ? Theme.primaryFg : Theme.primaryContainerFg
                onClicked: Panels.toggle("launcher")

                IconImage {
                    anchors.centerIn: parent
                    visible: launcherButton.snowflake !== ""
                    implicitSize: 18
                    source: launcherButton.snowflake
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1
                        colorizationColor: launcherButton.content
                    }
                }
            }

            Workspaces { screen: root.screen }

            ActiveWindow {
                visible: Settings.data.barShowWindowTitle && toplevel !== null && toplevel.activated
                Layout.maximumWidth: Math.max(0, body.width / 2 - center.width / 2 - x - Tokens.space.xl)
            }
        }

        // Centre: clock.
        Chip {
            id: center
            anchors.centerIn: parent
            interactive: true
            base: IslandState.expanded ? Theme.secondaryContainer : Theme.surfaceContainer
            // The island hangs right under the clock; the sidebar lives on the status chip.
            onClicked: IslandState.toggle("")

            StyledText {
                text: Time.time
                font.weight: Font.Bold
                font.pixelSize: Tokens.font.l
                font.features: { "tnum": 1 }
            }
            Rectangle { implicitWidth: 4; implicitHeight: 4; radius: 2; color: Theme.outline }
            StyledText {
                text: Time.date
                color: Theme.surfaceVariantFg
            }
        }

        // Right: media, resources, tray, status, power.
        RowLayout {
            id: rightRow
            anchors.right: parent.right
            anchors.rightMargin: Tokens.space.xs + 1
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.space.s

            WeatherChip { id: weather }
            MediaChip {
                id: media
                // Whatever room is left between the clock and the other right-hand chips.
                readonly property real others: (weather.visible ? weather.implicitWidth : 0)
                    + (resources.visible ? resources.implicitWidth : 0)
                    + (tray.visible ? tray.implicitWidth : 0)
                    + (recording.visible ? recording.implicitWidth : 0)
                    + status.implicitWidth + Tokens.bar.chipHeight + rightRow.spacing * 6
                visible: Settings.data.barShowMedia && player !== null && Layout.maximumWidth > 80
                Layout.maximumWidth: Math.min(320, Math.max(0, body.width / 2 - center.width / 2 - others - Tokens.space.xl))
            }
            Resources { id: resources; visible: Settings.data.barShowResources }
            Tray { id: tray; bar: root; visible: Settings.data.barShowTray && SystemTray.items.values.length > 0 }
            RecordingChip { id: recording }
            StatusChip { id: status }

            IconButton {
                size: Tokens.bar.chipHeight
                icon: "power_settings_new"
                iconSize: 18
                base: Theme.errorContainer
                content: Theme.errorContainerFg
                onClicked: Panels.toggle("power")
            }
        }
    }
}
