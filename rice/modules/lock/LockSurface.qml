import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

WlSessionLockSurface {
    id: root

    required property var context

    color: Theme.surfaceDim

    Image {
        id: wall
        anchors.fill: parent
        source: Wallpapers.current ? `file://${Wallpapers.current}` : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 1280
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wall
        visible: wall.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: -0.25
        saturation: 0.2
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.scrim, 0.25)
    }

    // Entrance animation.
    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { Anim { duration: Motion.duration.long } }

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.14
            spacing: 0

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.format(Settings.data.use24h ? "HH:mm" : "h:mm")
                font.pixelSize: Tokens.font.display * 1.4
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Theme.primary
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.format("dddd, d MMMM")
                font.pixelSize: Tokens.font.xxl
                color: Theme.surfaceFg
            }
        }

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.16
            spacing: Tokens.space.l

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 72
                implicitHeight: 72
                radius: Tokens.radius.xl
                color: Theme.primaryContainer
                StyledText {
                    anchors.centerIn: parent
                    text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    color: Theme.primaryContainerFg
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Quickshell.env("USER") || ""
                font.pixelSize: Tokens.font.xl
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: field
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 340
                implicitHeight: 56
                radius: height / 2
                color: Theme.alpha(Theme.surfaceContainer, 0.9)
                border.width: 2
                border.color: root.context.failed ? Theme.error : input.activeFocus ? Theme.primary : "transparent"
                Behavior on border.color { ColorAnim {} }

                // Shake on failure.
                transform: Translate { id: shake }
                SequentialAnimation {
                    id: shakeAnim
                    loops: 2
                    NumberAnimation { target: shake; property: "x"; to: -10; duration: 50 }
                    NumberAnimation { target: shake; property: "x"; to: 10; duration: 100 }
                    NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
                }
                Connections {
                    target: root.context
                    function onFailedChanged() { if (root.context.failed) shakeAnim.start(); }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space.xl
                    anchors.rightMargin: Tokens.space.s
                    spacing: Tokens.space.s

                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        focus: true
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: Theme.surfaceFg
                        font.pixelSize: Tokens.font.l
                        font.letterSpacing: 2
                        enabled: !root.context.busy
                        onTextChanged: if (text) root.context.failed = false
                        onAccepted: {
                            root.context.submit(text);
                            text = "";
                        }
                        Component.onCompleted: forceActiveFocus()

                        StyledText {
                            anchors.fill: parent
                            visible: !parent.text
                            text: root.context.busy ? "Checking…" : root.context.message || "Enter password"
                            color: root.context.failed ? Theme.error : Theme.surfaceVariantFg
                            font.letterSpacing: 0
                        }
                    }

                    IconButton {
                        size: 40
                        icon: root.context.busy ? "hourglass_top" : "arrow_forward"
                        toggled: true
                        onClicked: input.accepted()
                    }
                }
            }
        }

        // Bottom status row.
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.space.xl
            spacing: Tokens.space.m

            Chip {
                visible: Media.active !== null
                StyledText {
                    Layout.maximumWidth: 360
                    text: Media.active ? [Media.active.trackTitle, Media.active.trackArtist].filter(s => s).join("  ·  ") : ""
                }
                IconButton { size: 26; icon: "skip_previous"; onClicked: Media.active?.previous() }
                IconButton { size: 26; icon: Media.active?.isPlaying ? "pause" : "play_arrow"; onClicked: Media.active?.togglePlaying() }
                IconButton { size: 26; icon: "skip_next"; onClicked: Media.active?.next() }
            }

            Item { Layout.fillWidth: true }

            Chip {
                visible: UPower.displayDevice?.isLaptopBattery ?? false
                Icon { text: UPower.onBattery ? "battery_5_bar" : "battery_charging_full"; size: 18 }
                StyledText { text: `${Math.round((UPower.displayDevice?.percentage ?? 0) * 100)}%` }
            }
            Chip {
                Icon { text: Net.icon; size: 18 }
                StyledText { text: Net.label }
            }
        }
    }
}
