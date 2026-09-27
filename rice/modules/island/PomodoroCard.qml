import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.config
import qs.components
import qs.services

// Pomodoro: progress ring on the left; phase, rounds, lengths and controls on
// the right, so the card uses its width instead of stretching one column.
Surface {
    id: root

    readonly property bool focusPhase: Timers.pomodoroPhase === "focus"
    readonly property color phaseColor: focusPhase ? Theme.primary : Theme.tertiary
    readonly property color phaseContainer: focusPhase ? Theme.primaryContainer : Theme.tertiaryContainer
    readonly property color phaseContainerFg: focusPhase ? Theme.primaryContainerFg : Theme.tertiaryContainerFg
    readonly property color phaseFg: focusPhase ? Theme.primaryFg : Theme.tertiaryFg

    // What comes after the current phase, for the "Up next" line.
    readonly property string nextLabel: focusPhase
        ? (Timers.pomodoroCycle + 1 >= Timers.cyclesBeforeLongBreak
            ? `Long break · ${Timers.longBreakMinutes} min` : `Short break · ${Timers.breakMinutes} min`)
        : `Focus · ${Timers.focusMinutes} min`

    radius: Tokens.radius.xl
    base: Theme.surfaceHigh

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.space.l
        spacing: Tokens.space.l

        // ---- Ring ----
        Item {
            id: ring
            Layout.preferredWidth: Math.min(parent.height, 220)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            readonly property real value: Math.max(0.001, 1 - Timers.pomodoroProgress)
            readonly property real thick: 10

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.alpha(root.phaseColor, 0.16)
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
                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.focusPhase ? "target" : "local_cafe"
                    size: 20
                    fill: 1
                    color: root.phaseColor
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Timers.fmt(Timers.pomodoroRemaining)
                    font.pixelSize: ring.width * 0.2
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Timers.phaseLabel()
                    font.pixelSize: Tokens.font.s
                    font.weight: Font.DemiBold
                    color: root.phaseColor
                }
            }
        }

        // ---- Details + controls ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.space.s

            StyledText {
                text: "Pomodoro"
                font.pixelSize: Tokens.font.xl
                font.weight: Font.Bold
            }
            StyledText {
                Layout.fillWidth: true
                text: Timers.pomodoroRunning || !Timers.pomodoroIdle ? `Up next: ${root.nextLabel}`
                    : `${Timers.focusMinutes} min focus, then a ${Timers.breakMinutes} min break`
                color: Theme.surfaceVariantFg
            }

            // Rounds until the long break
            RowLayout {
                spacing: Tokens.space.s
                Row {
                    spacing: 6
                    Repeater {
                        model: Timers.cyclesBeforeLongBreak
                        Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: index === Timers.pomodoroCycle ? 22 : 8
                            height: 8
                            radius: 4
                            color: index <= Timers.pomodoroCycle ? root.phaseColor : Theme.alpha(Theme.surfaceFg, 0.16)
                            Behavior on width { Anim { easing.bezierCurve: Motion.curve.springDefault } }
                            Behavior on color { ColorAnim {} }
                        }
                    }
                }
                StyledText {
                    text: `Round ${Timers.pomodoroCycle + 1} of ${Timers.cyclesBeforeLongBreak}`
                    font.pixelSize: Tokens.font.s
                    color: Theme.surfaceVariantFg
                }
            }

            // Focus length presets (only while idle, so a running timer isn't changed)
            RowLayout {
                Layout.topMargin: Tokens.space.xs
                spacing: Tokens.space.xs
                opacity: Timers.pomodoroIdle ? 1 : 0.45
                StyledText {
                    Layout.preferredWidth: 44
                    text: "Focus"
                    font.pixelSize: Tokens.font.s
                    color: Theme.surfaceVariantFg
                }
                Repeater {
                    model: [15, 25, 45, 60]
                    Surface {
                        required property int modelData
                        readonly property bool current: Timers.focusMinutes === modelData
                        implicitWidth: presetText.implicitWidth + Tokens.space.s * 2 + 4
                        implicitHeight: 28
                        radius: height / 2
                        interactive: Timers.pomodoroIdle
                        base: current ? root.phaseContainer : Theme.surfaceHighest
                        content: current ? root.phaseContainerFg : Theme.surfaceFg
                        onClicked: Timers.setDurations(modelData, Timers.breakMinutes, Timers.longBreakMinutes, Timers.cyclesBeforeLongBreak)
                        StyledText {
                            id: presetText
                            anchors.centerIn: parent
                            text: `${parent.modelData}m`
                            font.pixelSize: Tokens.font.s
                            font.weight: parent.current ? Font.Bold : Font.Normal
                            color: parent.content
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                spacing: Tokens.space.s

                Surface {
                    implicitWidth: 150
                    implicitHeight: 44
                    radius: Timers.pomodoroRunning ? Tokens.radius.m : height / 2
                    interactive: true
                    base: Timers.pomodoroRunning ? root.phaseContainer : root.phaseColor
                    content: Timers.pomodoroRunning ? root.phaseContainerFg : root.phaseFg
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
                    size: 44
                    filled: true
                    onClicked: Timers.skip()
                }
                IconButton {
                    icon: "restart_alt"
                    size: 44
                    filled: true
                    enabled: !Timers.pomodoroIdle
                    opacity: enabled ? 1 : 0.4
                    onClicked: Timers.reset()
                }
            }
        }
    }
}
