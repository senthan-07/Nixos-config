import QtQuick
import QtQuick.Effects
import qs.config
import qs.components
import qs.services

// M3 expressive analog clock on a scalloped cookie face. Drawn at a 230px
// reference size and scaled to fit, so it works from sidebar to desktop.
//   CookieClock { dateStyle: "bubble" }   // bubble | rotating | none
Item {
    id: root

    property bool running: true
    property bool elevated: true
    property int sides: 12
    property bool numbers: true
    property bool seconds: true
    property string dateStyle: "bubble"

    readonly property real ref: 230
    readonly property date now: Time.now
    readonly property int hours: now.getHours()
    readonly property int minutes: now.getMinutes()
    readonly property int secs: now.getSeconds()

    readonly property color face: Theme.primaryContainer
    readonly property color dial: CardStyle.mix(Theme.secondary, Theme.primaryContainer, 0.35)
    readonly property color info: CardStyle.mix(Theme.primary, Theme.primaryContainer, 0.55)

    implicitWidth: 230
    implicitHeight: 230

    Accessible.role: Accessible.Clock
    Accessible.name: "Clock " + Qt.formatTime(now, "h:mm AP")

    Item {
        id: comp
        width: root.ref
        height: root.ref
        anchors.centerIn: parent
        scale: Math.max(0.01, Math.min(root.width, root.height) / root.ref)

        CookieShape {
            id: body
            anchors.fill: parent
            sides: root.sides
            depth: 0.075
            color: root.face
            layer.enabled: root.elevated
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.alpha(Theme.shadow, 0.4)
                shadowBlur: 0.8
                shadowVerticalOffset: 4
                autoPaddingEnabled: true
            }

            // Slow drift of the scallops, like the upstream "constantly rotate".
            RotationAnimation on rotation {
                running: root.running && root.visible
                from: 360; to: 0
                duration: 90000
                loops: Animation.Infinite
            }
        }

        // Twelve dots just inside the rim.
        Repeater {
            model: 12
            Item {
                required property int index
                anchors.fill: parent
                rotation: index * 30
                visible: !root.numbers || index % 3 !== 0
                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 20
                    color: root.dial
                }
            }
        }

        // Big 12 / 3 / 6 / 9.
        Repeater {
            model: root.numbers ? 4 : 0
            Item {
                id: num
                required property int index
                anchors.fill: parent
                rotation: 90 * index
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 12
                    rotation: -num.rotation
                    text: num.index === 0 ? "12" : String(num.index * 3)
                    color: root.dial
                    font.family: CardStyle.display
                    font.pixelSize: 34
                    font.weight: Font.Black
                    renderType: Text.QtRendering
                }
            }
        }

        // Date: a small tertiary cookie tucked at the lower right…
        Item {
            visible: root.dateStyle === "bubble"
            x: 146; y: 146
            width: 56; height: 56
            z: 1
            CookieShape {
                anchors.fill: parent
                sides: 5
                depth: 0.12
                color: Theme.tertiaryContainer
                rotation: 12
            }
            Text {
                anchors.centerIn: parent
                text: root.now.getDate()
                color: Theme.tertiaryContainerFg
                font.family: CardStyle.display
                font.pixelSize: 24
                font.weight: Font.Black
            }
        }

        // …or the weekday + day written around the rim, turning with the seconds.
        Item {
            id: ring
            visible: root.dateStyle === "rotating"
            anchors.fill: parent
            z: 1
            readonly property string label: Qt.formatDate(root.now, "ddd d").toUpperCase()
            readonly property real stepDeg: 10
            rotation: root.running ? 6 * root.secs - stepDeg * (label.length - 1) / 2 : 0
            Behavior on rotation { RotationAnimation { direction: RotationAnimation.Clockwise; duration: 700; easing.type: Easing.OutCubic } }

            Repeater {
                model: ring.label.length
                Item {
                    required property int index
                    anchors.fill: parent
                    rotation: index * ring.stepDeg
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 38
                        text: ring.label.charAt(parent.index)
                        color: root.info
                        font.family: CardStyle.display
                        font.pixelSize: 17
                        font.weight: Font.Bold
                    }
                }
            }
        }

        // Hour hand: a fat primary pill.
        Item {
            anchors.fill: parent
            z: 2
            rotation: 30 * ((root.hours % 12) + root.minutes / 60)
            Behavior on rotation { RotationAnimation { direction: RotationAnimation.Clockwise; duration: Motion.duration.long; easing.type: Easing.OutCubic } }
            Rectangle {
                width: 22; height: 76; radius: 11
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - height + 11
                color: Theme.primary
            }
        }

        // Minute hand: longer, slimmer, tertiary.
        Item {
            anchors.fill: parent
            z: 3
            rotation: 6 * root.minutes
            Behavior on rotation { RotationAnimation { direction: RotationAnimation.Clockwise; duration: Motion.duration.long; easing.type: Easing.OutBack } }
            Rectangle {
                width: 12; height: 98; radius: 6
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - height + 6
                color: Theme.tertiary
            }
        }

        // Second marker: a dot orbiting just inside the scallops.
        Item {
            anchors.fill: parent
            z: 4
            visible: root.seconds
            rotation: 6 * root.secs
            Behavior on rotation {
                enabled: root.running
                RotationAnimation { direction: RotationAnimation.Clockwise; duration: 600; easing.type: Easing.OutBack }
            }
            Rectangle {
                width: 11; height: 11; radius: 5.5
                anchors.horizontalCenter: parent.horizontalCenter
                y: 1
                color: Theme.primary
                border.width: 2
                border.color: root.face
            }
        }

        Rectangle {
            anchors.centerIn: parent
            z: 5
            width: 6; height: 6; radius: 3
            color: root.face
        }
    }
}
