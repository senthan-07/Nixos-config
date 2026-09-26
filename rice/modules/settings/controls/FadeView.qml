import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A column that slides + fades in each time it becomes `active` (page sub-views).
ColumnLayout {
    id: root

    property bool active: true
    property int direction: 1

    Layout.fillWidth: true
    visible: active
    spacing: Tokens.space.l
    transform: Translate { id: shift }

    onActiveChanged: if (active) enter.restart()
    Component.onCompleted: if (active) enter.restart()

    ParallelAnimation {
        id: enter
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Motion.duration.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.standardDecel }
        NumberAnimation { target: shift; property: "x"; from: 28 * root.direction; to: 0; duration: Motion.duration.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.emphasizedDecel }
    }
}
