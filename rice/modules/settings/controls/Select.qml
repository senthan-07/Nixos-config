import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import qs.config
import qs.components

// Dropdown menu field. options: [{ value, label, sublabel?, icon?, appIcon? }]
// A search box appears automatically for long lists.
Surface {
    id: root

    property var options: []
    property var value
    property string placeholder: "Select…"
    property bool searchable: options.length > 8
    readonly property var current: options.find(o => o.value === value) ?? null
    readonly property var filtered: {
        const q = search.text.trim().toLowerCase();
        return q ? options.filter(o => (o.label + " " + (o.sublabel ?? "")).toLowerCase().includes(q)) : options;
    }
    signal selected(var value)

    function open() {
        if (!enabled) return;
        search.text = "";
        list.currentIndex = Math.max(0, filtered.findIndex(o => o.value === value));
        menu.open();
    }

    implicitWidth: 240
    implicitHeight: 44
    radius: Tokens.radius.s
    interactive: enabled
    opacity: enabled ? 1 : 0.38
    base: Theme.surfaceHigh
    border.width: menu.opened || activeFocus ? 2 : 0
    border.color: Theme.primary
    activeFocusOnTab: enabled
    Accessible.role: Accessible.ComboBox
    onClicked: open()
    Keys.onPressed: e => {
        if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space, Qt.Key_Down].includes(e.key)) {
            open();
            e.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.m
        anchors.rightMargin: Tokens.space.s
        spacing: Tokens.space.s

        AppIcon {
            visible: (root.current?.appIcon ?? "") !== ""
            name: root.current?.appIcon ?? ""
            size: 22
        }
        Icon {
            visible: (root.current?.icon ?? "") !== ""
            text: root.current?.icon ?? ""
            size: 20
            color: Theme.surfaceVariantFg
        }
        StyledText {
            Layout.fillWidth: true
            text: root.current?.label ?? root.placeholder
            color: root.current ? Theme.surfaceFg : Theme.surfaceVariantFg
        }
        Icon {
            text: "arrow_drop_down"
            size: 24
            color: Theme.surfaceVariantFg
            rotation: menu.opened ? 180 : 0
            Behavior on rotation { Anim { duration: Motion.duration.short } }
        }
    }

    QC.Popup {
        id: menu
        y: root.height + 4
        width: Math.max(root.width, 260)
        height: Math.min(360, list.contentHeight + (root.searchable ? 56 : 0) + 16)
        padding: 8
        focus: true
        closePolicy: QC.Popup.CloseOnEscape | QC.Popup.CloseOnPressOutside
        onOpened: root.searchable ? search.forceActiveFocus() : list.forceActiveFocus()
        onClosed: root.forceActiveFocus()

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.duration.short }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Motion.duration.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.emphasizedDecel }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.duration.tiny }
        }

        background: Rectangle {
            radius: Tokens.radius.m
            color: Theme.surfaceHigh
            border.width: 1
            border.color: Theme.outlineVariant
        }

        contentItem: ColumnLayout {
            spacing: Tokens.space.s

            Rectangle {
                Layout.fillWidth: true
                visible: root.searchable
                implicitHeight: 44
                radius: height / 2
                color: Theme.surfaceHighest
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space.m
                    anchors.rightMargin: Tokens.space.m
                    Icon { text: "search"; size: 20; color: Theme.surfaceVariantFg }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.surfaceFg
                        font.family: Tokens.font.sans
                        font.pixelSize: Tokens.font.m
                        clip: true
                        onTextChanged: list.currentIndex = 0
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        onAccepted: list.pick(list.currentIndex)
                        StyledText {
                            anchors.fill: parent
                            visible: !parent.text
                            text: "Search"
                            color: Theme.surfaceVariantFg
                        }
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.filtered
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                keyNavigationEnabled: true
                Keys.onReturnPressed: pick(currentIndex)
                Keys.onEnterPressed: pick(currentIndex)

                function pick(i) {
                    const o = root.filtered[i];
                    if (!o) return;
                    menu.close();
                    if (o.value !== root.value) root.selected(o.value);
                }

                QC.ScrollBar.vertical: QC.ScrollBar { policy: list.contentHeight > list.height ? QC.ScrollBar.AlwaysOn : QC.ScrollBar.AlwaysOff }

                delegate: Surface {
                    id: opt
                    required property var modelData
                    required property int index
                    readonly property bool chosen: modelData.value === root.value

                    width: ListView.view.width - (list.contentHeight > list.height ? 10 : 0)
                    implicitHeight: modelData.sublabel ? 52 : 44
                    radius: Tokens.radius.s
                    interactive: true
                    base: chosen ? Theme.secondaryContainer
                        : ListView.isCurrentItem ? Theme.surfaceHighest : Theme.alpha(Theme.surfaceHigh, 0)
                    content: chosen ? Theme.secondaryContainerFg : Theme.surfaceFg
                    onClicked: list.pick(index)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.space.m
                        anchors.rightMargin: Tokens.space.m
                        spacing: Tokens.space.m
                        AppIcon {
                            visible: (opt.modelData.appIcon ?? "") !== ""
                            name: opt.modelData.appIcon ?? ""
                            size: 24
                        }
                        Icon {
                            visible: (opt.modelData.icon ?? "") !== ""
                            text: opt.modelData.icon ?? ""
                            size: 20
                            color: opt.content
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: opt.modelData.label
                                color: opt.content
                                font.weight: opt.chosen ? Font.DemiBold : Font.Normal
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: !!opt.modelData.sublabel
                                text: opt.modelData.sublabel ?? ""
                                font.pixelSize: Tokens.font.s
                                color: Theme.surfaceVariantFg
                            }
                        }
                        Icon {
                            visible: opt.chosen
                            text: "check"
                            size: 18
                            color: opt.content
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.margins: Tokens.space.m
                visible: root.filtered.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: "No matches"
                color: Theme.surfaceVariantFg
            }
        }
    }
}
