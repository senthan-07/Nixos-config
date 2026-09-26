import QtQuick
import QtQuick.Layouts
import qs.config

// Hub "Focus" tab: calendar, pomodoro and stopwatch side by side.
Item {
    id: root

    implicitWidth: 780
    implicitHeight: 300

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.space.m

        CalendarCard {
            Layout.preferredWidth: 250
            Layout.fillHeight: true
        }
        PomodoroCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        StopwatchCard {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
        }
    }
}
