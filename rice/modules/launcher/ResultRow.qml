import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// One list result: icon, title/subtitle and trailing hint.
Item {
    id: root

    property var item: ({})
    property bool selected: false
    property bool confirming: false

    readonly property bool sub: item.kind === "action"
    readonly property color fg: selected ? Spot.selectedFg : Theme.surfaceFg

    implicitHeight: sub ? Spot.subRowHeight : Spot.rowHeight

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.sub ? 36 : 12
        anchors.rightMargin: 14
        spacing: 14

        // Tree connector for desktop actions
        Rectangle {
            visible: root.sub
            Layout.preferredWidth: 2
            Layout.fillHeight: true
            Layout.topMargin: -2
            Layout.bottomMargin: -2
            color: Theme.alpha(root.fg, 0.18)
            radius: 1
        }

        ItemIcon {
            item: root.confirming ? Object.assign({}, root.item, { tone: "error", appIcon: undefined, icon: "warning" }) : root.item
            size: root.sub ? 28 : Spot.iconSize
            selected: root.selected
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                text: root.item.title || ""
                textFormat: Text.PlainText
                font.pixelSize: root.sub ? Tokens.font.m + 1 : Tokens.font.l
                font.weight: Font.Medium
                font.family: root.item.mono ? Tokens.font.mono : Tokens.font.sans
                color: root.fg
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.confirming ? "Press Enter again to confirm" : (root.item.subtitle || "")
                textFormat: Text.PlainText
                font.pixelSize: Tokens.font.s
                color: root.confirming ? Theme.error : Theme.alpha(root.fg, 0.72)
            }
        }

        // Badge (e.g. "On"/"Off", file count)
        Rectangle {
            visible: !!root.item.badge
            Layout.preferredHeight: 24
            Layout.preferredWidth: badgeText.implicitWidth + 16
            radius: 12
            color: root.item.badgeOn ? Theme.primary : Theme.alpha(root.fg, 0.1)
            StyledText {
                id: badgeText
                anchors.centerIn: parent
                text: root.item.badge || ""
                font.pixelSize: Tokens.font.s
                font.weight: Font.DemiBold
                color: root.item.badgeOn ? Theme.primaryFg : root.fg
            }
        }

        KeyHint {
            visible: root.selected && !!root.item.hint
            keys: "↵"
            label: root.item.hint || ""
            fg: root.fg
            cap: Theme.alpha(root.fg, 0.12)
        }

        Icon {
            visible: !!root.item.expandable
            text: root.item.expanded ? "expand_less" : "chevron_right"
            size: 20
            color: Theme.alpha(root.fg, 0.7)
        }
    }
}
