import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.config
import qs.components
import qs.services

// Pomodoro: big progress ring with the remaining time, round indicator and
// start/pause, skip and reset controls.
Surface {
    id: root

    readonly property color phaseColor: Timers.pomodoroPhase === "focus" ? Theme.primary : Theme.tertiary
    readonly property color phaseContainer: Timers.pomodoroPhase === "focus" ? Theme.primaryContainer : Theme.tertiaryContainer
    readonly property color phaseContainerFg: Timers.pomodoroPhase === "focus" ? Theme.primaryContainerFg : Theme.tertiaryContainerFg

    radius: Tokens.radius.xl
    base: Theme.surfaceHigh

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.space.m
        spacing: Tokens.space.s

        RowLayout {
            Layout.fillWidth: true
            Icon {
                text: Timers.pomodoroPhase === "focus" ? "target" : "local_cafe"
                size: 20
                fill: 1
                color: root.phaseColor
            }
            StyledText {
                Layout.fillWidth: true
                text: "Pomodoro"
                font.pixelSize: Tokens.font.l
                font.weight: Font.Bold
            }
            StyledText {
                text: `Round ${Timers.pomodoroCycle + 1} / ${Timers.cyclesBeforeLongBreak}`
                font.pixelSize: Tokens.font.xs
                color: Theme.surfaceVariantFg
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: ring
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                readonly property real value: Math.max(0.001, 1 - Timers.pomodoroProgress)
                readonly property real thick: 9

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.alpha(root.phaseColor, 0.18)
                        strokeWidth: ring.thick
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: ring.width / 2; centerY: ring.height / 2
                            radiusX: (ring.width - ring.thick) / 2; radiusY: radiusX
                            startAngle: -90; sweepAngle: 360
                        }
                    }
                    ShapePath {
                        strokeColor: root.phaseColor
                        strokeWidth: ring.thick
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: ring.width / 2; centerY: ring.height / 2
                            radiusX: (ring.width - ring.thick) / 2; radiusY: radiusX
                            startAngle: -90; sweepAngle: 360 * ring.value
                            Behavior on sweepAngle { Anim { duration: Motion.duration.long } }
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Timers.fmt(Timers.pomodoroRemaining)
                        font.pixelSize: ring.width * 0.22
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Timers.phaseLabel()
                        font.pixelSize: Tokens.font.s
                        color: root.phaseColor
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        // Round dots
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Repeater {
                model: Timers.cyclesBeforeLongBreak
                Rectangle {
                    required property int index
                    width: index === Timers.pomodoroCycle ? 20 : 7
                    height: 7
                    radius: 3.5
                    color: index <= Timers.pomodoroCycle ? root.phaseColor : Theme.alpha(Theme.surfaceFg, 0.18)
                    Behavior on width { Anim { easing.bezierCurve: Motion.curve.springDefault } }
                    Behavior on color { ColorAnim {} }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.s

            Surface {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Timers.pomodoroRunning ? Tokens.radius.m : height / 2
                interactive: true
                base: Timers.pomodoroRunning ? root.phaseContainer : root.phaseColor
                content: Timers.pomodoroRunning ? root.phaseContainerFg : Theme.primaryFg
                onClicked: Timers.toggle()
                Behavior on radius { Anim { duration: Motion.duration.short } }

                Row {
                    anchors.centerIn: parent
                    spacing: Tokens.space.xs
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Timers.pomodoroRunning ? "pause" : "play_arrow"
                        fill: 1
                        color: parent.parent.content
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Timers.pomodoroRunning ? "Pause" : Timers.pomodoroIdle ? "Start" : "Resume"
                        font.weight: Font.DemiBold
                        color: parent.parent.content
                    }
                }
            }
            IconButton {
                icon: "skip_next"
                size: 40
                filled: true
                onClicked: Timers.skip()
            }
            IconButton {
                icon: "restart_alt"
                size: 40
                filled: true
                enabled: !Timers.pomodoroIdle
                opacity: enabled ? 1 : 0.4
                onClicked: Timers.reset()
            }
        }
    }
}
