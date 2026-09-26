import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import qs.config
import qs.components

// M3 exposed dropdown menu.
//   Dropdown {
//       model: [{ value: "a", label: "Alpha", icon: "star", font: "Inter" }, "plain-string", …]
//       value: Settings.data.thing
//       searchable: true            // adds a filter field (long lists)
//       onActivated: v => Settings.data.thing = v
//   }
// Keyboard: Space/Enter/Down opens, arrows move, Enter picks, Esc closes.
Surface {
    id: root

    property var model: []
    property var value
    property string placeholder: "Select…"
    property string icon
    property bool searchable: false
    property int popupMaxHeight: 320

    signal activated(var value)

    readonly property var items: (model || []).map(m => typeof m === "object" ? m : { value: m, label: String(m) })
    readonly property int currentIndex: items.findIndex(i => i.value === value)
    readonly property var current: currentIndex >= 0 ? items[currentIndex] : null
    readonly property bool expanded: popup.visible

    property string filter: ""
    readonly property var filtered: filter === "" ? items
        : items.filter(i => String(i.label).toLowerCase().includes(filter.toLowerCase()))

    implicitWidth: 240
    implicitHeight: 40
    radius: Tokens.radius.s
    interactive: true
    activeFocusOnTab: true
    base: Theme.surfaceHighest
    content: Theme.surfaceFg
    border.width: expanded || activeFocus ? 2 : 0
    border.color: Theme.primary

    onClicked: expanded ? popup.close() : openPopup()

    function openPopup() {
        filter = "";
        popup.open();
    }

    function pick(item) {
        popup.close();
        if (item && item.value !== root.value) root.activated(item.value);
    }

    Keys.onPressed: event => {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Down].includes(event.key)) {
            openPopup();
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.icon !== "" || (root.current && root.current.icon) ? Tokens.space.m : Tokens.space.l
        anchors.rightMargin: Tokens.space.s
        spacing: Tokens.space.s

        Icon {
            readonly property string glyph: root.current && root.current.icon ? root.current.icon : root.icon
            visible: glyph !== ""
            text: glyph
            size: 20
            color: Theme.surfaceVariantFg
        }
        StyledText {
            Layout.fillWidth: true
            text: root.current ? root.current.label : root.placeholder
            color: root.current ? Theme.surfaceFg : Theme.surfaceVariantFg
            font.family: root.current && root.current.font ? root.current.font : Tokens.font.sans
        }
        Icon {
            text: "arrow_drop_down"
            size: 24
            color: root.expanded ? Theme.primary : Theme.surfaceVariantFg
            rotation: root.expanded ? 180 : 0
            Behavior on rotation { Anim { duration: Motion.duration.short } }
        }
    }

    QC.Popup {
        id: popup

        y: root.height + Tokens.space.xs
        width: Math.max(root.width, 200)
        height: Math.min(root.popupMaxHeight, column.implicitHeight + padding * 2)
        padding: Tokens.space.xs
        // Keeps the menu inside the window (Qt shifts/flips it when it would overflow).
        margins: Tokens.space.s
        modal: false
        focus: true
        closePolicy: QC.Popup.CloseOnEscape | QC.Popup.CloseOnPressOutsideParent

        onOpened: {
            list.currentIndex = Math.max(0, root.filtered.findIndex(i => i.value === root.value));
            list.positionViewAtIndex(list.currentIndex, ListView.Center);
            if (root.searchable) search.focusInput(); else list.forceActiveFocus();
        }
        onClosed: root.forceActiveFocus()

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.duration.short }
                NumberAnimation {
                    property: "scale"; from: 0.92; to: 1
                    duration: Motion.duration.medium
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.emphasizedDecel
                }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Motion.duration.tiny }
        }

        background: Rectangle {
            radius: Tokens.radius.m
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.6)
            transformOrigin: Item.Top

            Rectangle {
                z: -1
                anchors.fill: parent
                anchors.topMargin: 3
                anchors.margins: -1
                radius: parent.radius + 1
                color: Theme.alpha(Theme.shadow, 0.25)
            }
        }

        contentItem: ColumnLayout {
            id: column
            spacing: Tokens.space.xs

            InputField {
                id: search
                visible: root.searchable
                Layout.fillWidth: true
                Layout.margins: Tokens.space.xs
                icon: "search"
                placeholder: "Filter…"
                onEdited: t => { root.filter = t; list.currentIndex = 0; }
                onDownPressed: list.incrementCurrentIndex()
                onUpPressed: list.decrementCurrentIndex()
                onAccepted: root.pick(root.filtered[list.currentIndex])
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.max(44, contentHeight)
                clip: true
                model: root.filtered
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: Motion.duration.short
                highlightFollowsCurrentItem: true
                // Cursor (keyboard or hover): an M3 state layer drawn over the row.
                highlight: Rectangle {
                    z: 2
                    radius: Tokens.radius.s
                    color: Theme.alpha(Theme.surfaceFg, 0.1)
                    border.width: list.activeFocus || search.focused ? 1 : 0
                    border.color: Theme.alpha(Theme.primary, 0.6)
                }
                keyNavigationWraps: true
                QC.ScrollBar.vertical: QC.ScrollBar { policy: list.contentHeight > list.height ? QC.ScrollBar.AsNeeded : QC.ScrollBar.AlwaysOff }

                Keys.onReturnPressed: root.pick(root.filtered[currentIndex])
                Keys.onEnterPressed: root.pick(root.filtered[currentIndex])

                delegate: Surface {
                    id: option
                    required property var modelData
                    required property int index
                    readonly property bool selected: modelData.value === root.value

                    width: ListView.view.width
                    implicitHeight: 40
                    radius: Tokens.radius.s
                    interactive: true
                    base: selected ? Theme.secondaryContainer
                        : Theme.alpha(Theme.surfaceContainer, 0)
                    content: selected ? Theme.secondaryContainerFg : Theme.surfaceFg
                    onClicked: root.pick(modelData)
                    onHoveredChanged: if (hovered) list.currentIndex = index

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.space.m
                        anchors.rightMargin: Tokens.space.m
                        spacing: Tokens.space.m
                        Icon {
                            visible: !!option.modelData.icon
                            text: option.modelData.icon || ""
                            size: 20
                            color: option.content
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: option.modelData.label
                            color: option.content
                            font.family: option.modelData.font || Tokens.font.sans
                        }
                        StyledText {
                            visible: !!option.modelData.hint
                            text: option.modelData.hint || ""
                            color: Theme.surfaceVariantFg
                            font.pixelSize: Tokens.font.s
                        }
                        Icon {
                            visible: option.selected
                            text: "check"
                            size: 18
                            color: option.content
                        }
                    }
                }
            }

            StyledText {
                visible: root.filtered.length === 0
                Layout.fillWidth: true
                Layout.margins: Tokens.space.m
                horizontalAlignment: Text.AlignHCenter
                text: "No matches"
                color: Theme.surfaceVariantFg
            }
        }
    }
}
