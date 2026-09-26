import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.modules.island

PanelWindow {
    id: root

    screen: Quickshell.screens[0]
    visible: Notifs.popups.length > 0 && !Panels.sidebar && !Panels.locked && !IslandState.replacesNotifications
    anchors { top: true; right: true }
    margins { top: Tokens.space.s; right: Tokens.space.m }
    implicitWidth: Tokens.notificationWidth
    implicitHeight: Math.max(1, column.implicitHeight)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "rice-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Tokens.space.s

        Repeater {
            model: Notifs.popups

            NotificationCard {
                id: card
                required property var modelData
                notification: modelData
                popup: true
                Layout.fillWidth: true

                opacity: 0
                transform: Translate { id: shift; x: 40 }
                Component.onCompleted: enter.start()

                ParallelAnimation {
                    id: enter
                    NumberAnimation { target: card; property: "opacity"; to: 1; duration: Motion.duration.short }
                    NumberAnimation {
                        target: shift; property: "x"; to: 0; duration: Motion.duration.medium
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.emphasizedDecel
                    }
                }

                Timer {
                    running: !card.hovered && !card.critical
                    interval: card.modelData.expireTimeout > 0 ? card.modelData.expireTimeout : 6000
                    onTriggered: Notifs.hide(card.modelData)
                }
            }
        }
    }
}
