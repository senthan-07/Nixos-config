import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Stopwatch with laps.
Surface {
    id: root

    radius: Tokens.radius.xl
    base: Theme.surfaceHigh

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.space.m
        spacing: Tokens.space.s

        RowLayout {
            Layout.fillWidth: true
            Icon { text: "timer"; size: 20; fill: 1; color: Theme.secondary }
            StyledText {
                Layout.fillWidth: true
                text: "Stopwatch"
                font.pixelSize: Tokens.font.l
                font.weight: Font.Bold
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.space.s
            text: Timers.fmt(Timers.stopwatchElapsed)
            font.pixelSize: 34
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "." + String(Math.floor((Timers.stopwatchElapsed % 1) * 100)).padStart(2, "0")
            font.pixelSize: Tokens.font.l
            font.features: { "tnum": 1 }
            color: Theme.surfaceVariantFg
            Layout.topMargin: -Tokens.space.s
        }

        ListView {
            id: laps
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: Timers.stopwatchLaps.slice().reverse()
            spacing: 2
            visible: count > 0
            delegate: RowLayout {
                required property var modelData
                required property int index
                width: ListView.view.width
                StyledText {
                    text: `Lap ${laps.count - index}`
                    font.pixelSize: Tokens.font.s
                    color: Theme.surfaceVariantFg
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: Timers.fmtPrecise(modelData)
                    font.pixelSize: Tokens.font.s
                    font.features: { "tnum": 1 }
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: laps.count === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: Timers.stopwatchRunning ? "Tap the flag to record a lap" : "No laps yet"
            font.pixelSize: Tokens.font.s
            color: Theme.surfaceVariantFg
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.s

            Surface {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Timers.stopwatchRunning ? Tokens.radius.m : height / 2
                interactive: true
                base: Timers.stopwatchRunning ? Theme.secondaryContainer : Theme.secondary
                content: Timers.stopwatchRunning ? Theme.secondaryContainerFg : Theme.secondaryFg
                onClicked: Timers.toggleStopwatch()
                Behavior on radius { Anim { duration: Motion.duration.short } }
                Icon {
                    anchors.centerIn: parent
                    text: Timers.stopwatchRunning ? "pause" : "play_arrow"
                    fill: 1
                    color: parent.content
                }
            }
            IconButton {
                icon: Timers.stopwatchRunning ? "flag" : "restart_alt"
                size: 40
                filled: true
                enabled: Timers.stopwatchRunning || Timers.stopwatchElapsed > 0
                opacity: enabled ? 1 : 0.4
                onClicked: Timers.stopwatchRunning ? Timers.lap() : Timers.resetStopwatch()
            }
        }
    }
}
