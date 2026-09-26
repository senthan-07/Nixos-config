import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services

// Newest popup notification inside the island. Click runs the default
// action, right/middle click dismisses, hovering pauses the timeout.
Item {
    id: root

    readonly property var n: IslandState.notification
    readonly property bool critical: n?.urgency === NotificationUrgency.Critical
    readonly property var actions: (n?.actions ?? []).filter(a => a.identifier !== "default").slice(0, 3)
    // Notification.expireTimeout is in milliseconds (-1/0 = server default).
    readonly property int timeout: n && n.expireTimeout > 0 ? Math.max(1500, n.expireTimeout) : 5000
    property real remaining: 1

    implicitWidth: 440
    implicitHeight: Math.max(76, col.implicitHeight + Tokens.space.m * 2 + 4)

    onNChanged: restart()
    function restart() {
        expire.stop();
        remaining = 1;
        if (n && !critical) {
            expire.duration = timeout;
            expire.start();
        }
    }

    NumberAnimation {
        id: expire
        target: root
        property: "remaining"
        from: 1; to: 0
        paused: running && (hover.containsMouse)
        onFinished: if (root.n) Notifs.hide(root.n)
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => {
            if (!root.n) return;
            if (m.button !== Qt.LeftButton) { root.n.dismiss(); return; }
            const def = root.n.actions.find(a => a.identifier === "default");
            if (def) def.invoke();
            else Notifs.hide(root.n);
        }
    }

    RowLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.space.m
        spacing: Tokens.space.m

        // Image or app icon
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 48
            implicitHeight: 48
            radius: Tokens.radius.l
            color: root.critical ? Theme.error : Theme.secondaryContainer
            clip: true
            Image {
                id: image
                anchors.fill: parent
                source: root.n?.image ?? ""
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                sourceSize.width: 96
                asynchronous: true
            }
            AppIcon {
                anchors.centerIn: parent
                size: 28
                name: root.n?.appIcon ?? ""
                visible: !image.visible && (root.n?.appIcon ?? "") !== ""
            }
            Icon {
                anchors.centerIn: parent
                visible: !image.visible && (root.n?.appIcon ?? "") === ""
                text: root.critical ? "priority_high" : "notifications"
                fill: 1
                color: root.critical ? Theme.errorFg : Theme.secondaryContainerFg
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: root.n?.appName || "Notification"
                    font.pixelSize: Tokens.font.xs
                    color: root.critical ? Theme.errorContainerFg : Theme.surfaceVariantFg
                    font.weight: Font.DemiBold
                }
                StyledText {
                    visible: IslandState.pendingNotifications > 1
                    text: `+${IslandState.pendingNotifications - 1}`
                    font.pixelSize: Tokens.font.xs
                    color: Theme.primary
                    font.weight: Font.Bold
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.n?.summary ?? ""
                color: root.critical ? Theme.errorContainerFg : Theme.surfaceFg
                font.weight: Font.Bold
                font.pixelSize: Tokens.font.m + 1
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: (root.n?.body ?? "").replace(/<img\b[^>]*>/gi, "")
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                color: root.critical ? Theme.errorContainerFg : Theme.surfaceVariantFg
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.space.xs
                visible: root.actions.length > 0
                spacing: Tokens.space.xs
                Repeater {
                    model: root.actions
                    Surface {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: 15
                        interactive: true
                        base: Theme.secondaryContainer
                        content: Theme.secondaryContainerFg
                        onClicked: modelData.invoke()
                        StyledText {
                            anchors.centerIn: parent
                            width: parent.width - Tokens.space.m
                            horizontalAlignment: Text.AlignHCenter
                            text: parent.modelData.text
                            font.weight: Font.DemiBold
                            font.pixelSize: Tokens.font.s
                            color: Theme.secondaryContainerFg
                        }
                    }
                }
            }
        }

        IconButton {
            Layout.alignment: Qt.AlignTop
            size: 28
            iconSize: 16
            icon: "close"
            onClicked: root.n?.dismiss()
        }
    }

    // Time-left indicator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: (parent.width - 2 * Tokens.space.xl) * root.remaining
        height: 3
        radius: 1.5
        visible: !root.critical
        color: Theme.alpha(Theme.primary, 0.7)
    }
}
