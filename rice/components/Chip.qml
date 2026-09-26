import QtQuick
import QtQuick.Layouts
import qs.config

// Pill-shaped container that sizes itself to its row of children.
Surface {
    id: root

    default property alias content: row.data
    property int padding: Tokens.space.m
    property alias spacing: row.spacing

    implicitHeight: Tokens.bar.chipHeight
    implicitWidth: row.implicitWidth + padding * 2
    radius: height / 2
    base: Theme.surfaceContainer

    Behavior on implicitWidth { Anim { easing.bezierCurve: Motion.curve.emphasizedDecel } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.space.s
    }
}
