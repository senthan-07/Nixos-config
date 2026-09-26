import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// M3 filled text field: leading icon, placeholder, clear button, focus indicator.
//   InputField { icon: "search"; placeholder: "Search"; onEdited: t => … ; onAccepted: t => … }
// `text` is two-way: set it from outside, read it back after edits.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder
    property string icon
    property bool clearable: true
    property bool error: false
    property bool monospace: false
    property alias input: input
    readonly property bool focused: input.activeFocus

    signal edited(string text)
    signal accepted(string text)
    signal upPressed()
    signal downPressed()

    function focusInput() { input.forceActiveFocus(); }

    implicitWidth: 240
    implicitHeight: 40
    radius: Tokens.radius.s
    color: hover.hovered ? Theme.stateLayer(Theme.surfaceHighest, Theme.surfaceFg, true, false) : Theme.surfaceHighest
    border.width: root.focused || root.error ? 2 : 0
    border.color: root.error ? Theme.error : Theme.primary
    Behavior on color { ColorAnim {} }
    Behavior on border.width { Anim { duration: Motion.duration.tiny } }

    HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }
    TapHandler { onTapped: input.forceActiveFocus() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.icon !== "" ? Tokens.space.m : Tokens.space.l
        anchors.rightMargin: Tokens.space.xs
        spacing: Tokens.space.s

        Icon {
            visible: root.icon !== ""
            text: root.icon
            size: 20
            color: root.error ? Theme.error : root.focused ? Theme.primary : Theme.surfaceVariantFg
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextInput {
                id: input
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.surfaceFg
                selectionColor: Theme.alpha(Theme.primary, 0.35)
                selectedTextColor: Theme.surfaceFg
                font.family: root.monospace ? Tokens.font.mono : Tokens.font.sans
                font.pixelSize: Tokens.font.m
                clip: true
                selectByMouse: true
                activeFocusOnTab: true
                onTextEdited: root.edited(text)
                onAccepted: root.accepted(text)
                // Show the start of long values (paths) when not editing.
                onTextChanged: if (!activeFocus) cursorPosition = 0
                onActiveFocusChanged: if (!activeFocus) cursorPosition = 0
                Keys.onUpPressed: root.upPressed()
                Keys.onDownPressed: root.downPressed()
                Keys.onEscapePressed: event => {
                    if (text !== "" && root.clearable) { text = ""; root.edited(""); }
                    else { focus = false; event.accepted = false; }
                }
            }

            StyledText {
                anchors.fill: parent
                visible: input.text === ""
                text: root.placeholder
                color: Theme.surfaceVariantFg
                opacity: 0.8
                font.family: input.font.family
            }
        }

        IconButton {
            visible: root.clearable && input.text !== ""
            size: 30
            icon: "close"
            iconSize: 18
            onClicked: { input.text = ""; root.edited(""); input.forceActiveFocus(); }
        }
    }
}
