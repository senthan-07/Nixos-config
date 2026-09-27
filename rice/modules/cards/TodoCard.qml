import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// To-do list backed by services/Todo.qml. Enter adds, click toggles,
// right-click (or Enter on a focused row) edits, the trailing × removes; Delete removes the focused row.
// Deadlines: the calendar button (or typing "@tomorrow 5pm") sets one; click a
// task's deadline chip to change it. Tasks are sorted by deadline.
CardFrame {
    id: root

    // Deadline picker target: "" closed, "new" for the task being typed, or an item id.
    property string pickerFor: ""
    property var pendingDue: null

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
                model: Todo.sorted
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
                        if (Todo.add(text, root.pendingDue)) {
                            text = "";
                            root.pendingDue = null;
                            root.pickerFor = "";
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

                // Deadline for the new task: chip when set, calendar button otherwise.
                DueChip {
                    visible: root.pendingDue !== null
                    due: root.pendingDue ?? 0
                    onClicked: root.pickerFor = root.pickerFor === "new" ? "" : "new"
                }
                IconButton {
                    visible: root.pendingDue === null
                    size: 30
                    iconSize: 18
                    icon: "event"
                    toggled: root.pickerFor === "new"
                    onClicked: root.pickerFor = root.pickerFor === "new" ? "" : "new"
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
        // Hover over the whole row, including its buttons (the Surface's own
        // hover state drops as soon as the pointer is over a child button).
        readonly property bool rowHovered: rowHover.hovered
        HoverHandler { id: rowHover }

        width: ListView.view.width
        implicitHeight: modelData.due && !modelData.done ? 52 : 38
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

            ColumnLayout {
                Layout.fillWidth: true
                visible: !row.editing
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.text
                    color: row.modelData.done ? Theme.surfaceVariantFg : Theme.surfaceFg
                    font.strikeout: row.modelData.done
                    opacity: row.modelData.done ? 0.7 : 1
                }
                DueChip {
                    visible: !!row.modelData.due && !row.modelData.done
                    due: row.modelData.due ?? 0
                    onClicked: root.pickerFor = root.pickerFor === row.modelData.id ? "" : row.modelData.id
                }
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
                visible: !row.modelData.due && !row.modelData.done
                size: 26
                iconSize: 16
                icon: "event"
                opacity: row.rowHovered || row.activeFocus ? 1 : 0
                Behavior on opacity { Anim { duration: Motion.duration.short } }
                onClicked: root.pickerFor = row.modelData.id
            }
            IconButton {
                size: 26
                iconSize: 16
                icon: "close"
                opacity: row.rowHovered || row.activeFocus ? 1 : 0.35
                Behavior on opacity { Anim { duration: Motion.duration.short } }
                onClicked: Todo.remove(row.modelData.id)
            }
        }
    }

    // Small deadline pill; turns red when overdue.
    component DueChip: Surface {
        id: chip
        property real due: 0
        readonly property bool overdue: due > 0 && due <= Todo.now
        implicitWidth: chipRow.implicitWidth + Tokens.space.s * 2
        implicitHeight: 20
        radius: 10
        interactive: true
        base: overdue ? Theme.errorContainer : Theme.secondaryContainer
        content: overdue ? Theme.errorContainerFg : Theme.secondaryContainerFg
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 3
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.overdue ? "alarm" : "event"
                size: 12
                fill: 1
                color: chip.content
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Todo.dueLabel(chip.due)
                font.pixelSize: Tokens.font.xs
                font.weight: Font.DemiBold
                color: chip.content
            }
        }
    }

    // While the picker is open, a click anywhere else on the card closes it.
    MouseArea {
        z: 19
        anchors.fill: parent
        visible: root.pickerFor !== ""
        acceptedButtons: Qt.AllButtons
        onClicked: root.pickerFor = ""
    }

    // Leaving the card closes the picker too (clicks outside the card never
    // reach the desktop layer, so they can't close it).
    HoverHandler { id: cardHover }
    Timer {
        running: root.pickerFor !== "" && !cardHover.hovered
        interval: 1200
        onTriggered: root.pickerFor = ""
    }

    // Deadline presets, floating above the input.
    Rectangle {
        id: picker
        z: 20
        visible: root.pickerFor !== ""
        focus: visible
        onVisibleChanged: if (visible) forceActiveFocus()
        Keys.onEscapePressed: root.pickerFor = ""

        // Swallow clicks on the picker's background so they don't close it.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        implicitHeight: pickerCol.implicitHeight + Tokens.space.m * 2
        radius: Tokens.radius.l
        color: Theme.surfaceHighest
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.6)

        readonly property var presets: {
            const n = new Date(Todo.now);
            const at = (days, h, m) => { const d = new Date(n); d.setDate(d.getDate() + days); d.setHours(h, m, 0, 0); return d.getTime(); };
            const list = [{ label: "In 1 hour", due: Todo.now + 3600e3 }];
            if (n.getHours() < 17) list.push({ label: "Today 18:00", due: at(0, 18, 0) });
            if (n.getHours() < 20) list.push({ label: "Tonight 20:00", due: at(0, 20, 0) });
            list.push({ label: "Tomorrow 09:00", due: at(1, 9, 0) });
            list.push({ label: "Tomorrow 18:00", due: at(1, 18, 0) });
            list.push({ label: "In a week", due: at(7, 9, 0) });
            return list;
        }

        function choose(due) {
            if (root.pickerFor === "new") root.pendingDue = due;
            else Todo.setDue(root.pickerFor, due);
            root.pickerFor = "";
        }

        ColumnLayout {
            id: pickerCol
            anchors.fill: parent
            anchors.margins: Tokens.space.m
            spacing: Tokens.space.s

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: "Deadline"
                    font.weight: Font.Bold
                }
                IconButton { size: 30; iconSize: 18; icon: "close"; filled: true; onClicked: root.pickerFor = "" }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.space.xs
                Repeater {
                    model: picker.presets
                    Surface {
                        required property var modelData
                        implicitWidth: presetLabel.implicitWidth + Tokens.space.m * 2
                        implicitHeight: 28
                        radius: 14
                        interactive: true
                        base: Theme.surfaceHigh
                        onClicked: picker.choose(modelData.due)
                        StyledText {
                            id: presetLabel
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            font.pixelSize: Tokens.font.s
                        }
                    }
                }
                Surface {
                    implicitWidth: noneLabel.implicitWidth + Tokens.space.m * 2
                    implicitHeight: 28
                    radius: 14
                    interactive: true
                    base: Theme.alpha(Theme.errorContainer, 0.6)
                    content: Theme.errorContainerFg
                    onClicked: picker.choose(null)
                    StyledText {
                        id: noneLabel
                        anchors.centerIn: parent
                        text: "No deadline"
                        font.pixelSize: Tokens.font.s
                        color: parent.content
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: "Or type it: “Pay rent @fri”, “Call @2h”, “Report @tomorrow 5pm”"
                wrapMode: Text.Wrap
                font.pixelSize: Tokens.font.xs
                color: Theme.surfaceVariantFg
            }
        }
    }
}
