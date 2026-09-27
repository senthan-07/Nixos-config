import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings app ("control centre"): navigation rail + one page at a time.
// Pages are files in ./pages; see `registry` for the fixed list.
FloatingWindow {
    id: root

    // State lives in Panels so any module can open a page
    // (`rice ipc call settings page <Name>` or Panels.openSettings(name)).
    readonly property bool open: Panels.settings
    readonly property string current: Panels.settingsPage

    readonly property var registry: [
        { name: "General", icon: "tune" },
        { name: "Bar", icon: "toolbar" },
        { name: "Appearance", icon: "palette" },
        { name: "Wallpaper", icon: "wallpaper" },
        { name: "Network", icon: "wifi" },
        { name: "Bluetooth", icon: "bluetooth" },
        { name: "Audio", icon: "volume_up" },
        { name: "Displays", icon: "monitor" },
        { name: "NightLight", icon: "nightlight", label: "Night light" },
        { name: "Idle", icon: "bedtime", label: "Idle & power" },
        { name: "Dock", icon: "dock_to_bottom" },
        { name: "DefaultApps", icon: "apps", label: "Default apps" },
        { name: "Autostart", icon: "rocket_launch" },
        { name: "Shortcuts", icon: "keyboard" },
        { name: "About", icon: "info" }
    ]

    visible: open
    title: "Rice Settings"
    implicitWidth: 1080
    implicitHeight: 720
    // Resizable by dragging its edges (Hyprland resize_on_border); keep the
    // nav rail and a usable page area on screen.
    minimumSize: Qt.size(760, 480)
    color: Theme.surface

    onVisibleChanged: if (!visible) { Panels.settings = false; Avatar.picking = false; }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Navigation rail
        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 232
            color: Theme.surfaceLow

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.space.m
                spacing: 2

                StyledText {
                    Layout.margins: Tokens.space.m
                    text: "Settings"
                    font.pixelSize: Tokens.font.xl
                    font.weight: Font.DemiBold
                }

                // Scrolls when the window is shorter than the page list.
                ListView {
                    id: nav
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.registry
                    currentIndex: root.registry.findIndex(p => p.name === root.current)
                    highlightFollowsCurrentItem: false
                    // Keep the selected page visible when it changes (IPC, search).
                    onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

                    ScrollBar.vertical: ScrollBar {
                        policy: nav.contentHeight > nav.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    }

                    delegate: Surface {
                        id: navItem
                        required property var modelData
                        readonly property bool active: root.current === modelData.name

                        width: nav.width
                        implicitHeight: 44
                        radius: height / 2
                        interactive: true
                        base: active ? Theme.secondaryContainer : Theme.alpha(Theme.surfaceLow, 0)
                        content: active ? Theme.secondaryContainerFg : Theme.surfaceVariantFg
                        onClicked: Panels.settingsPage = modelData.name

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.space.l
                            spacing: Tokens.space.m
                            Icon {
                                text: navItem.modelData.icon
                                fill: navItem.active ? 1 : 0
                                color: navItem.content
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: navItem.modelData.label ?? navItem.modelData.name
                                font.weight: navItem.active ? Font.DemiBold : Font.Normal
                                color: navItem.content
                            }
                        }
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: `pages/${root.current}Page.qml`
            asynchronous: false
        }
    }

    // Profile picture picker (Avatar.pick()), over everything.
    AvatarPicker { anchors.fill: parent }
}
