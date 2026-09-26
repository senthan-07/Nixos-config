import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// M3 button: text (default), tonal, filled or outlined, with optional leading icon.
Surface {
    id: root

    property string text
    property string icon
    property string kind: "text"      // text | tonal | filled | outlined | danger
    property bool busy: false

    readonly property color fg: kind === "filled" ? Theme.primaryFg
        : kind === "tonal" ? Theme.secondaryContainerFg
        : kind === "danger" ? Theme.errorFg
        : Theme.primary

    implicitHeight: 40
    implicitWidth: row.implicitWidth + (kind === "text" ? Tokens.space.l : Tokens.space.xl) * 2 - (icon !== "" ? 4 : 0)
    radius: height / 2
    interactive: enabled && !busy
    opacity: enabled ? 1 : 0.38
    base: kind === "filled" ? Theme.primary
        : kind === "tonal" ? Theme.secondaryContainer
        : kind === "danger" ? Theme.error
        : Theme.alpha(Theme.surface, 0)
    content: fg
    border.width: kind === "outlined" ? 1 : 0
    border.color: Theme.outline
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: text

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            root.clicked(null);
            e.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
        visible: root.activeFocus
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.space.s

        Spinner {
            visible: root.busy
            size: 18
            color: root.fg
        }
        Icon {
            visible: root.icon !== "" && !root.busy
            text: root.icon
            size: 18
            color: root.fg
        }
        StyledText {
            text: root.text
            font.weight: Font.Medium
            color: root.fg
        }
    }
}
