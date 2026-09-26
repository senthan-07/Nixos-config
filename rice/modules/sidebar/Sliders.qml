import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Surface {
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + Tokens.space.l * 2
    radius: Tokens.radius.xl
    base: Theme.surfaceContainer

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Tokens.space.l
        spacing: Tokens.space.l

        RowLayout {
            spacing: Tokens.space.m
            Slider {
                Layout.fillWidth: true
                icon: Audio.icon
                value: Math.min(1, Audio.volume)
                onMoved: v => Audio.setVolume(v)
            }
            IconButton {
                icon: Audio.muted ? "volume_off" : "volume_up"
                toggled: Audio.muted
                onClicked: Audio.toggleMute()
            }
        }

        RowLayout {
            visible: Brightness.available
            spacing: Tokens.space.m
            Slider {
                Layout.fillWidth: true
                icon: "brightness_6"
                accent: Theme.tertiary
                onAccent: Theme.tertiaryFg
                value: Brightness.value
                onMoved: v => Brightness.set(v)
            }
            IconButton {
                icon: "light_mode"
                onClicked: Brightness.set(1)
            }
        }
    }
}
