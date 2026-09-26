import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// M3 outlined text field with floating label, optional password reveal and error text.
ColumnLayout {
    id: root

    property string label
    property alias text: input.text
    property alias validator: input.validator
    property alias inputMethodHints: input.inputMethodHints
    property alias maximumLength: input.maximumLength
    property alias field: input
    property string icon
    property string suffix
    property bool password: false
    property bool mono: false
    property string error
    property string helper
    property bool revealed: false
    property color surfaceColor: Theme.surfaceContainer   // colour behind the field (for the notched label)

    signal accepted()
    signal editingFinished()

    function focusField() { input.forceActiveFocus(); }

    spacing: 2
    Layout.fillWidth: true

    Item {
        Layout.fillWidth: true
        implicitHeight: 56
        implicitWidth: 200

        Rectangle {
            id: frame
            anchors.fill: parent
            anchors.topMargin: 6
            radius: Tokens.radius.s
            color: "transparent"
            border.width: input.activeFocus ? 2 : 1
            border.color: root.error !== "" ? Theme.error : input.activeFocus ? Theme.primary : Theme.outline
            Behavior on border.color { ColorAnim {} }
        }

        // Floating label (sits on the outline when raised).
        Rectangle {
            id: labelBg
            readonly property bool raised: input.activeFocus || input.text !== "" || input.preeditText !== ""
            x: raised ? 12 : (root.icon !== "" ? 44 : 14)
            y: raised ? 0 : 6 + (frame.height - lbl.implicitHeight) / 2
            width: lbl.implicitWidth + (raised ? 8 : 0)
            height: lbl.implicitHeight
            color: raised ? root.surfaceColor : "transparent"
            Behavior on x { Anim { duration: Motion.duration.short } }
            Behavior on y { Anim { duration: Motion.duration.short } }

            StyledText {
                id: lbl
                anchors.centerIn: parent
                text: root.label
                font.pixelSize: labelBg.raised ? Tokens.font.s : Tokens.font.l - 1
                color: root.error !== "" ? Theme.error : input.activeFocus ? Theme.primary : Theme.surfaceVariantFg
                Behavior on font.pixelSize { Anim { duration: Motion.duration.short } }
            }
        }

        RowLayout {
            anchors.fill: frame
            anchors.leftMargin: root.icon !== "" ? Tokens.space.m : Tokens.space.l
            anchors.rightMargin: Tokens.space.xs
            spacing: Tokens.space.s

            Icon {
                visible: root.icon !== ""
                text: root.icon
                size: 20
                color: Theme.surfaceVariantFg
            }

            TextInput {
                id: input
                Layout.fillWidth: true
                clip: true
                color: Theme.surfaceFg
                selectionColor: Theme.primary
                selectedTextColor: Theme.primaryFg
                selectByMouse: true
                activeFocusOnTab: true
                font.family: root.mono ? Tokens.font.mono : Tokens.font.sans
                font.pixelSize: Tokens.font.l - 1
                echoMode: root.password && !root.revealed ? TextInput.Password : TextInput.Normal
                verticalAlignment: TextInput.AlignVCenter
                onAccepted: root.accepted()
                onEditingFinished: root.editingFinished()
                Keys.onEscapePressed: e => { focus = false; e.accepted = false; }
            }

            StyledText {
                visible: root.suffix !== ""
                text: root.suffix
                color: Theme.surfaceVariantFg
            }

            IconButton {
                visible: root.password
                size: 36
                icon: root.revealed ? "visibility_off" : "visibility"
                onClicked: root.revealed = !root.revealed
            }
            Item { visible: !root.password; implicitWidth: Tokens.space.s }
        }

        MouseArea {
            anchors.fill: frame
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.IBeamCursor
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.space.l
        visible: text !== ""
        text: root.error !== "" ? root.error : root.helper
        font.pixelSize: Tokens.font.s
        color: root.error !== "" ? Theme.error : Theme.surfaceVariantFg
    }
}
