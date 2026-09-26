import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// To-do list backed by services/Todo.qml. Enter adds, click toggles,
// right-click (or Enter on a focused row) edits, the trailing × removes; Delete removes the focused row.
CardFrame {
    id: root

    icon: "checklist"
    title: "To-do"
    subtitle: Todo.items.length === 0 ? "" : Todo.remaining === 0 ? "All done" : `${Todo.remaining} left`

    implicitWidth: 272
    implicitHeight: 368

    trailing: [
        IconButton {
            visible: Todo.items.some(i => i.done)
            size: 28
            iconSize: 18
            icon: "done_all"
            onClicked: Todo.clearDone()
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.space.s

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            EmptyState {
                anchors.centerIn: parent
                visible: Todo.items.length === 0
                icon: "task_alt"
                text: "Nothing to do.\nAdd a task below."
            }

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: Todo.items
                delegate: TodoRow {}

                add: Transition { Anim { properties: "opacity,scale"; from: 0; to: 1; duration: Motion.duration.short } }
                displaced: Transition { Anim { properties: "y"; duration: Motion.duration.short } }
            }
        }

        // Input pill.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: height / 2
            color: input.activeFocus ? Theme.surfaceHighest : Theme.surfaceHigh
            border.width: input.activeFocus ? 2 : 0
            border.color: Theme.primary
            Behavior on color { ColorAnim {} }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.space.m
                anchors.rightMargin: Tokens.space.xs
                spacing: Tokens.space.s

                Icon { text: "add"; size: 18; color: Theme.surfaceVariantFg }

                TextInput {
                    id: input
                    Layout.fillWidth: true
                    color: Theme.surfaceFg
                    font.family: Tokens.font.sans
                    font.pixelSize: Tokens.font.m
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryFg
                    clip: true
                    activeFocusOnTab: true

                    function commit() {
                        if (Todo.add(text)) {
                            text = "";
                            list.positionViewAtEnd();
                        }
                    }

                    Keys.onReturnPressed: commit()
                    Keys.onEnterPressed: commit()
                    Keys.onEscapePressed: { text = ""; focus = false; }

                    StyledText {
                        anchors.fill: parent
                        visible: !parent.text && !parent.activeFocus
                        text: "Add a task"
                        color: Theme.surfaceVariantFg
                    }
                }

                IconButton {
                    visible: input.text.trim() !== ""
                    size: 32
                    iconSize: 18
                    icon: "arrow_upward"
                    toggled: true
                    onClicked: input.commit()
                }
            }
        }
    }

    component TodoRow: Surface {
        id: row
        required property var modelData
        required property int index
        property bool editing: false

        width: ListView.view.width
        implicitHeight: 38
        radius: Tokens.radius.m
        interactive: true
        base: Theme.alpha(Theme.surfaceContainer, 0)
        activeFocusOnTab: true
        border.width: activeFocus ? 2 : 0
        border.color: Theme.primary

        onClicked: m => {
            if (editing) return;
            if (m.button === Qt.RightButton) editing = true;
            else Todo.toggle(modelData.id);
        }
        Keys.onSpacePressed: Todo.toggle(modelData.id)
        Keys.onDeletePressed: Todo.remove(modelData.id)
        Keys.onReturnPressed: editing = true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.space.s
            anchors.rightMargin: Tokens.space.xs
            spacing: Tokens.space.s

            // Checkbox that fills and morphs to a rounded square when done.
            Rectangle {
                implicitWidth: 20
                implicitHeight: 20
                radius: row.modelData.done ? 6 : 10
                color: row.modelData.done ? Theme.primary : "transparent"
                border.width: row.modelData.done ? 0 : 2
                border.color: Theme.outline
                Behavior on radius { Anim { duration: Motion.duration.short } }
                Behavior on color { ColorAnim {} }
                Icon {
                    anchors.centerIn: parent
                    text: "check"
                    size: 16
                    color: Theme.primaryFg
                    scale: row.modelData.done ? 1 : 0
                    Behavior on scale { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.springFast } }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: !row.editing
                text: row.modelData.text
                color: row.modelData.done ? Theme.surfaceVariantFg : Theme.surfaceFg
                font.strikeout: row.modelData.done
                opacity: row.modelData.done ? 0.7 : 1
            }

            TextInput {
                id: editor
                Layout.fillWidth: true
                visible: row.editing
                text: row.modelData.text
                color: Theme.surfaceFg
                font.family: Tokens.font.sans
                font.pixelSize: Tokens.font.m
                selectionColor: Theme.primary
                selectedTextColor: Theme.primaryFg
                clip: true
                onVisibleChanged: if (visible) { forceActiveFocus(); selectAll(); }
                onActiveFocusChanged: if (!activeFocus && row.editing) row.editing = false
                Keys.onReturnPressed: { Todo.setText(row.modelData.id, text); row.editing = false; }
                Keys.onEnterPressed: { Todo.setText(row.modelData.id, text); row.editing = false; }
                Keys.onEscapePressed: row.editing = false
            }

            IconButton {
                size: 26
                iconSize: 16
                icon: "close"
                opacity: row.hovered || row.activeFocus ? 1 : 0
                Behavior on opacity { Anim { duration: Motion.duration.short } }
                onClicked: Todo.remove(row.modelData.id)
            }
        }
    }
}
