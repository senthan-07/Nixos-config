import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Right-hand control centre: quick toggles, sliders, media, calendar and
// notification history. Wi-Fi and Bluetooth open as sub-pages.
PanelWindow {
    id: root

    property string page: "main"

    screen: Quickshell.screens[0]
    visible: Panels.sidebar || panel.x < width
    anchors { top: true; bottom: true; right: true }
    margins { top: Tokens.space.s; bottom: Tokens.space.s; right: Tokens.space.s }
    implicitWidth: Tokens.sidebarWidth
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "rice-sidebar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Panels.sidebar ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onVisibleChanged: if (!visible) page = "main"

    DelayedFocusGrab {
        windows: [root]
        want: Panels.sidebar
        onCleared: Panels.dismiss("sidebar")
    }

    Rectangle {
        id: panel
        width: parent.width
        height: parent.height
        x: Panels.sidebar ? 0 : width + Tokens.space.m
        radius: Tokens.radius.xl
        color: Theme.surface
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.5)
        clip: true

        Behavior on x {
            Anim {
                duration: Panels.sidebar ? Motion.duration.long : Motion.duration.short
                easing.bezierCurve: Panels.sidebar ? Motion.curve.emphasizedDecel : Motion.curve.emphasizedAccel
            }
        }

        focus: true
        Keys.onEscapePressed: root.page !== "main" ? root.page = "main" : Panels.sidebar = false

        Flickable {
            anchors.fill: parent
            anchors.margins: Tokens.space.l
            contentWidth: width
            contentHeight: pages.height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Item {
                id: pages
                width: parent.parent.width
                height: root.page === "main" ? main.implicitHeight
                    : root.page === "wifi" ? wifi.implicitHeight
                    : root.page === "performance" ? performance.implicitHeight : bluetooth.implicitHeight

                ColumnLayout {
                    id: main
                    width: parent.width
                    spacing: Tokens.space.m
                    visible: root.page === "main"

                    Header {}
                    Toggles { onOpenPage: name => root.page = name }
                    Sliders {}
                    MediaCard {}
                }

                WifiPage {
                    id: wifi
                    width: parent.width
                    visible: root.page === "wifi"
                    onBack: root.page = "main"
                }

                PerformancePage {
                    id: performance
                    width: parent.width
                    visible: root.page === "performance"
                    onBack: root.page = "main"
                }

                BluetoothPage {
                    id: bluetooth
                    width: parent.width
                    visible: root.page === "bluetooth"
                    onBack: root.page = "main"
                }
            }
        }
    }
}
