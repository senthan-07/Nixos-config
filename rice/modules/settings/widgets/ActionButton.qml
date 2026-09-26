import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// M3 common button. style: "filled" | "tonal" | "outlined" | "text".
//   ActionButton { icon: "shuffle"; text: "Random"; style: "tonal"; onClicked: … }
Surface {
    id: root

    property string text
    property string icon
    property string style: "filled"
    property bool busy: false

    readonly property color fg: !enabled ? Theme.alpha(Theme.surfaceFg, 0.38)
        : style === "filled" ? Theme.primaryFg
        : style === "tonal" ? Theme.secondaryContainerFg
        : Theme.primary

    implicitHeight: 40
    implicitWidth: row.implicitWidth + (root.icon !== "" ? Tokens.space.l + Tokens.space.xl : Tokens.space.xl * 2)
    radius: pressed ? Tokens.radius.s : height / 2
    interactive: enabled
    activeFocusOnTab: enabled
    base: !enabled ? Theme.alpha(Theme.surfaceFg, style === "text" || style === "outlined" ? 0 : 0.12)
        : style === "filled" ? Theme.primary
        : style === "tonal" ? Theme.secondaryContainer
        : Theme.alpha(Theme.surface, 0)
    content: fg
    border.width: style === "outlined" || activeFocus ? (activeFocus ? 2 : 1) : 0
    border.color: activeFocus ? Theme.primary : Theme.outlineVariant

    Behavior on radius { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.springFast } }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked(null);
            event.accepted = true;
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.space.s

        Icon {
            visible: root.icon !== ""
            text: root.icon
            size: 18
            color: root.fg
            RotationAnimation on rotation {
                running: root.busy
                loops: Animation.Infinite
                from: 0; to: 360; duration: 900
            }
        }
        StyledText {
            text: root.text
            color: root.fg
            font.weight: Font.Medium
        }
    }
}
