import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.components

Surface {
    id: root

    required property Notification notification
    property bool popup: false
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical

    implicitHeight: layout.implicitHeight + Tokens.space.l * 2
    radius: Tokens.radius.l
    base: critical ? Theme.errorContainer : popup ? Theme.surfaceContainer : Theme.surfaceHigh
    content: critical ? Theme.errorContainerFg : Theme.surfaceFg
    interactive: true
    border.width: popup ? 1 : 0
    border.color: Theme.alpha(Theme.outlineVariant, 0.6)
    onClicked: m => {
        if (m.button === Qt.MiddleButton || m.button === Qt.RightButton) {
            notification.dismiss();
        } else {
            const def = notification.actions.find(a => a.identifier === "default");
            if (def) def.invoke();
        }
    }

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.space.l
        spacing: Tokens.space.m

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 40
            implicitHeight: 40

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radius.m
                color: root.critical ? Theme.error : Theme.secondaryContainer
                visible: !image.visible
                AppIcon {
                    anchors.centerIn: parent
                    size: 24
                    name: root.notification?.appIcon || "dialog-information"
                    visible: root.notification?.appIcon !== ""
                }
                Icon {
                    anchors.centerIn: parent
                    visible: root.notification?.appIcon === ""
                    text: root.critical ? "priority_high" : "notifications"
                    fill: 1
                    color: root.critical ? Theme.errorFg : Theme.secondaryContainerFg
                }
            }

            Image {
                id: image
                anchors.fill: parent
                source: root.notification?.image ?? ""
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(80, 80)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.xxs

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: root.notification?.appName || "Notification"
                    font.pixelSize: Tokens.font.xs
                    color: Theme.alpha(root.content, 0.7)
                }
                Icon {
                    text: "close"
                    size: 16
                    color: Theme.alpha(root.content, 0.7)
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notification.dismiss()
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.notification?.summary ?? ""
                font.weight: Font.DemiBold
                color: root.content
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notification?.body ?? ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 3 : 6
                color: Theme.alpha(root.content, 0.85)
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.space.xs
                spacing: Tokens.space.xs
                visible: actions.count > 0

                Repeater {
                    id: actions
                    model: (root.notification?.actions ?? []).filter(a => a.identifier !== "default")

                    Surface {
                        required property var modelData
                        implicitHeight: 30
                        implicitWidth: label.implicitWidth + Tokens.space.l * 2
                        radius: height / 2
                        interactive: true
                        base: root.critical ? Theme.error : Theme.primaryContainer
                        content: root.critical ? Theme.errorFg : Theme.primaryContainerFg
                        onClicked: modelData.invoke()

                        StyledText {
                            id: label
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            font.weight: Font.Medium
                            color: parent.content
                        }
                    }
                }
            }
        }
    }
}
