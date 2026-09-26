import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Labelled slider over an arbitrary range. Optional `gradient` (list of colours) paints
// the track, e.g. a colour-temperature ramp. Keyboard: arrows (Shift = ×10), Home/End.
ColumnLayout {
    id: root

    property string label
    property string icon
    property real from: 0
    property real to: 1
    property real step: 0.01
    property real value: 0
    property string suffix
    property var format: v => `${Math.round(v)}${root.suffix}`
    property var gradient: null
    property color accent: Theme.primary
    property bool live: true              // emit moved() while dragging

    property bool settled: false          // no animation for the initial layout pass
    Timer { running: true; interval: 300; onTriggered: root.settled = true }

    signal moved(real value)
    signal committed(real value)

    readonly property real shown: area.pressed ? area.dragValue : value
    readonly property real frac: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0

    function snap(v) {
        const s = step > 0 ? Math.round((v - from) / step) * step + from : v;
        return Math.max(from, Math.min(to, +s.toFixed(4)));
    }
    function nudge(delta) {
        const v = snap(value + delta);
        moved(v);
        committed(v);
    }

    Layout.fillWidth: true
    spacing: Tokens.space.s

    RowLayout {
        Layout.fillWidth: true
        visible: root.label !== ""
        spacing: Tokens.space.m
        Icon { visible: root.icon !== ""; text: root.icon; size: 20; color: Theme.surfaceVariantFg }
        StyledText { Layout.fillWidth: true; text: root.label; font.weight: Font.Medium }
        Rectangle {
            implicitWidth: valueText.implicitWidth + Tokens.space.m * 2
            implicitHeight: 26
            radius: height / 2
            color: area.pressed ? root.accent : Theme.surfaceHighest
            Behavior on color { ColorAnim {} }
            StyledText {
                id: valueText
                anchors.centerIn: parent
                text: root.format(root.shown)
                font.pixelSize: Tokens.font.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: area.pressed ? Theme.primaryFg : Theme.surfaceFg
            }
        }
    }

    Item {
        id: track
        Layout.fillWidth: true
        implicitHeight: 36
        activeFocusOnTab: true
        Accessible.role: Accessible.Slider
        Accessible.name: root.label

        Keys.onPressed: e => {
            const big = e.modifiers & Qt.ShiftModifier ? 10 : 1;
            if (e.key === Qt.Key_Left || e.key === Qt.Key_Down) root.nudge(-root.step * big);
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Up) root.nudge(root.step * big);
            else if (e.key === Qt.Key_Home) root.nudge(root.from - root.value);
            else if (e.key === Qt.Key_End) root.nudge(root.to - root.value);
            else return;
            e.accepted = true;
        }

        readonly property real handleX: root.frac * (width - 6)

        // Gradient track (full width) or two-part M3 track.
        Rectangle {
            visible: root.gradient !== null
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 16
            radius: 8
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.gradient ? root.gradient[0] : "black" }
                GradientStop { position: 0.5; color: root.gradient ? root.gradient[Math.floor(root.gradient.length / 2)] : "black" }
                GradientStop { position: 1; color: root.gradient ? root.gradient[root.gradient.length - 1] : "black" }
            }
        }
        Rectangle {
            visible: root.gradient === null
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(8, track.handleX - 4)
            height: 16
            radius: 8
            color: root.accent
        }
        Rectangle {
            visible: root.gradient === null
            anchors.verticalCenter: parent.verticalCenter
            x: track.handleX + 10
            width: Math.max(0, parent.width - x)
            height: 16
            radius: 8
            color: Theme.surfaceHighest
        }
        Rectangle {
            id: handle
            x: track.handleX
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: area.pressed || track.activeFocus ? 40 : 34
            radius: 3
            color: root.gradient !== null ? Theme.surfaceFg : root.accent
            border.width: root.gradient !== null ? 2 : 0
            border.color: Theme.surface
            Behavior on height { Anim { duration: Motion.duration.short } }
            Behavior on x { enabled: !area.pressed && root.settled; Anim { duration: Motion.duration.short } }
        }

        MouseArea {
            id: area
            property real dragValue: root.value
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function update(x) {
                dragValue = root.snap(root.from + Math.max(0, Math.min(1, x / track.width)) * (root.to - root.from));
                if (root.live) root.moved(dragValue);
            }
            onPressed: m => { track.forceActiveFocus(); update(m.x); }
            onPositionChanged: m => { if (pressed) update(m.x); }
            onReleased: { root.moved(dragValue); root.committed(dragValue); }
            onWheel: w => root.nudge((w.angleDelta.y > 0 ? 1 : -1) * root.step * (root.step < (root.to - root.from) / 50 ? 5 : 1))
        }
    }
}
