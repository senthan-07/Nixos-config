import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Volume / brightness level shown in the island; draggable, scroll to adjust.
Item {
    id: root

    readonly property string kind: IslandState.osdKind || "volume"
    readonly property bool volume: kind === "volume"
    readonly property real value: volume ? (Audio.muted ? 0 : Audio.volume) : Brightness.value
    readonly property color accent: volume ? Theme.primary : Theme.tertiary
    readonly property color accentFg: volume ? Theme.primaryFg : Theme.tertiaryFg

    implicitWidth: 380
    implicitHeight: 48

    function set(v) {
        IslandState.holdOsd();
        if (volume) Audio.setVolume(v); else Brightness.set(v);
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.s
        anchors.rightMargin: Tokens.space.l
        spacing: Tokens.space.m

        Surface {
            implicitWidth: 36
            implicitHeight: 36
            radius: 18
            interactive: root.volume
            base: Theme.alpha(root.accent, 0.18)
            content: root.accent
            onClicked: { IslandState.holdOsd(); Audio.toggleMute(); }
            Icon {
                anchors.centerIn: parent
                text: root.volume ? Audio.icon : root.value < 0.34 ? "brightness_5" : root.value < 0.67 ? "brightness_6" : "brightness_7"
                size: 20
                fill: 1
                color: root.accent
            }
        }

        Slider {
            Layout.fillWidth: true
            implicitHeight: 22
            value: Math.min(1, root.value)
            accent: root.accent
            onAccent: root.accentFg
            onMoved: v => root.set(v)
        }

        StyledText {
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.value * 100)
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
    }
}
