import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// M3 filled text field for secrets: leading key icon, floating label,
// reveal toggle, error state.
Rectangle {
    id: root

    property alias text: input.text
    property alias input: input
    property string label: "Password"
    property bool secret: true
    property bool error: false
    property bool revealed: false

    signal accepted()

    implicitHeight: 56
    radius: Tokens.radius.s
    color: Theme.stateLayer(Theme.surfaceHighest, Theme.surfaceFg, hover.hovered, false)
    border.width: input.activeFocus || error ? 2 : 1
    border.color: error ? Theme.error : input.activeFocus ? Theme.primary : Theme.outline

    Behavior on border.color { ColorAnim {} }
    Behavior on color { ColorAnim {} }

    function clear() { input.text = ""; }

    HoverHandler {
        id: hover
        cursorShape: Qt.IBeamCursor
    }

    TapHandler {
        onTapped: input.forceActiveFocus()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.m
        anchors.rightMargin: Tokens.space.xs
        spacing: Tokens.space.m

        Icon {
            text: root.error ? "error" : "key"
            size: 22
            fill: root.error ? 1 : 0
            color: root.error ? Theme.error : input.activeFocus ? Theme.primary : Theme.surfaceVariantFg
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Floating label: centred when empty, small and on top otherwise.
            StyledText {
                id: floating
                readonly property bool raised: input.activeFocus || input.text !== ""
                x: 0
                y: raised ? 8 : (parent.height - height) / 2
                text: root.label
                font.pixelSize: raised ? Tokens.font.xs + 1 : Tokens.font.l
                color: root.error ? Theme.error : input.activeFocus ? Theme.primary : Theme.surfaceVariantFg
                Behavior on y { Anim { duration: Motion.duration.short } }
                Behavior on font.pixelSize { Anim { duration: Motion.duration.short } }
            }

            TextInput {
                id: input
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                echoMode: root.secret && !root.revealed ? TextInput.Password : TextInput.Normal
                passwordCharacter: "●"
                color: Theme.surfaceFg
                selectionColor: Theme.alpha(Theme.primary, 0.35)
                selectedTextColor: Theme.surfaceFg
                font.family: Tokens.font.sans
                font.pixelSize: Tokens.font.l
                font.letterSpacing: root.secret && !root.revealed ? 2 : 0
                clip: true
                onAccepted: root.accepted()
            }
        }

        IconButton {
            visible: root.secret
            icon: root.revealed ? "visibility_off" : "visibility"
            size: 40
            onClicked: {
                root.revealed = !root.revealed;
                input.forceActiveFocus();
            }
        }
    }
}
