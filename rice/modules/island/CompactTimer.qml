import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Collapsed timer: pomodoro ring + phase + remaining, or the stopwatch.
Item {
    id: root

    readonly property bool pomo: Timers.pomodoroRunning
    readonly property color accent: pomo ? (Timers.pomodoroPhase === "focus" ? Theme.primary : Theme.tertiary) : Theme.secondary

    implicitHeight: 40
    implicitWidth: row.implicitWidth + Tokens.space.m * 2

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.space.s

        Item {
            implicitWidth: 24
            implicitHeight: 24
            Ring {
                anchors.fill: parent
                visible: root.pomo
                value: 1 - Timers.pomodoroProgress
                color: root.accent
                track: Theme.alpha(root.accent, 0.2)
                thickness: 3
            }
            Icon {
                anchors.centerIn: parent
                text: root.pomo ? (Timers.pomodoroPhase === "focus" ? "target" : "local_cafe") : "timer"
                size: root.pomo ? 13 : 20
                fill: 1
                color: root.accent
            }
        }
        StyledText {
            text: root.pomo ? Timers.phaseLabel() : "Stopwatch"
            color: Theme.surfaceVariantFg
            font.weight: Font.Medium
        }
        StyledText {
            text: root.pomo ? Timers.fmt(Timers.pomodoroRemaining) : Timers.fmt(Timers.stopwatchElapsed)
            font.weight: Font.Bold
            font.pixelSize: Tokens.font.l
            font.features: { "tnum": 1 }
        }
    }
}
