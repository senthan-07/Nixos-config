import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Collapsed timer: pomodoro ring + phase + remaining.
Item {
    id: root

    readonly property bool pomo: Timers.pomodoroRunning
    readonly property color accent: Timers.pomodoroPhase === "focus" ? Theme.primary : Theme.tertiary

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
                value: 1 - Timers.pomodoroProgress
                color: root.accent
                track: Theme.alpha(root.accent, 0.2)
                thickness: 3
            }
            Icon {
                anchors.centerIn: parent
                text: Timers.pomodoroPhase === "focus" ? "target" : "local_cafe"
                size: 13
                fill: 1
                color: root.accent
            }
        }
        StyledText {
            text: Timers.phaseLabel()
            color: Theme.surfaceVariantFg
            font.weight: Font.Medium
        }
        StyledText {
            text: Timers.fmt(Timers.pomodoroRemaining)
            font.weight: Font.Bold
            font.pixelSize: Tokens.font.l
            font.features: { "tnum": 1 }
        }
    }
}
