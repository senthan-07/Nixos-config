import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Small pill shown when Caps Lock or Num Lock is toggled. Sits just above
// the volume/brightness OSD so both can be visible at once.
PanelWindow {
    id: root

    property string key: "caps"
    property bool on: false
    property bool shown: false

    screen: Quickshell.screens[0]
    visible: shown || pill.opacity > 0
    anchors.bottom: true
    margins.bottom: Tokens.space.xxl * 2 + 64 + Tokens.space.m
    implicitWidth: pill.implicitWidth + 16
    implicitHeight: 56
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "rice-lockkeys"
    WlrLayershell.layer: WlrLayer.Overlay

    Connections {
        target: LockKeys
        function onToggled(key, on) {
            root.key = key;
            root.on = on;
            root.shown = true;
            hide.restart();
            if (pill.opacity > 0) bump.restart();
        }
    }

    Timer {
        id: hide
        interval: 1400
        onTriggered: root.shown = false
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + Tokens.space.s + Tokens.space.xl
        implicitHeight: 48
        radius: height / 2
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.6)
        opacity: root.shown && !Panels.locked ? 1 : 0
        scale: root.shown ? 1 : 0.85
        Behavior on opacity { Anim { duration: Motion.duration.short } }
        Behavior on scale { Anim { easing.bezierCurve: Motion.curve.springFast } }
        Behavior on implicitWidth { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.emphasizedDecel } }

        SequentialAnimation {
            id: bump
            Anim { target: pill; property: "scale"; to: 1.06; duration: Motion.duration.tiny }
            Anim { target: pill; property: "scale"; to: 1; duration: Motion.duration.short; easing.bezierCurve: Motion.curve.springFast }
        }

        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Tokens.space.s
            spacing: Tokens.space.m

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: root.on ? Tokens.radius.s : 17
                color: root.on ? Theme.primary : Theme.surfaceHighest
                Behavior on color { ColorAnim {} }
                Behavior on radius { Anim { duration: Motion.duration.short } }

                Icon {
                    anchors.centerIn: parent
                    text: root.key === "caps" ? "keyboard_capslock" : "dialpad"
                    size: 20
                    fill: root.on ? 1 : 0
                    color: root.on ? Theme.primaryFg : Theme.surfaceVariantFg
                }
            }

            StyledText {
                text: root.key === "caps" ? "Caps Lock" : "Num Lock"
                font.pixelSize: Tokens.font.l
                font.weight: Font.DemiBold
            }

            StyledText {
                text: root.on ? "On" : "Off"
                font.pixelSize: Tokens.font.l
                color: root.on ? Theme.primary : Theme.surfaceVariantFg
            }
        }
    }
}
