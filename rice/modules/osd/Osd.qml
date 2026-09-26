import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.island

// Volume / brightness indicator shown near the bottom of the primary screen.
PanelWindow {
    id: root

    property string kind: "volume"
    property bool shown: false

    screen: Quickshell.screens[0]
    visible: shown || pill.opacity > 0
    anchors.bottom: true
    margins.bottom: Tokens.space.xxl * 2
    implicitWidth: 320
    implicitHeight: 64
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "rice-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    function show(k) {
        kind = k;
        shown = true;
        hide.restart();
    }

    Connections {
        target: Audio
        function onChanged() { root.show("volume"); }
    }
    Connections {
        target: Brightness
        function onChanged() { root.show("brightness"); }
    }

    Timer {
        id: hide
        interval: 1500
        onTriggered: root.shown = false
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.6)
        opacity: root.shown && !Panels.sidebar && !IslandState.replacesOsd ? 1 : 0
        scale: root.shown ? 1 : 0.9
        Behavior on opacity { Anim { duration: Motion.duration.short } }
        Behavior on scale { Anim { easing.bezierCurve: Motion.curve.springFast } }

        readonly property real value: root.kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : Brightness.value

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.space.l
            anchors.rightMargin: Tokens.space.xl
            spacing: Tokens.space.m

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 20
                color: root.kind === "volume" ? Theme.primaryContainer : Theme.tertiaryContainer
                Icon {
                    anchors.centerIn: parent
                    text: root.kind === "volume" ? Audio.icon : "brightness_6"
                    fill: 1
                    color: root.kind === "volume" ? Theme.primaryContainerFg : Theme.tertiaryContainerFg
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 10
                radius: 5
                color: Theme.surfaceHighest
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * Math.min(1, pill.value)
                    color: root.kind === "volume" ? Theme.primary : Theme.tertiary
                    Behavior on width { Anim { duration: Motion.duration.short } }
                }
            }

            StyledText {
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
                text: Math.round(pill.value * 100)
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
        }
    }
}
