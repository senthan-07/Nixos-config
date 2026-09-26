import QtQuick
import qs.config
import qs.components

// Segmented button group with a sliding selection pill. The selected entry
// expands to show its label (M3 expressive "connected button group").
Item {
    id: root

    // [{ id, icon, label, enabled? }]
    property var model: []
    property string current
    property color accent: Theme.secondaryContainer
    property color accentFg: Theme.secondaryContainerFg
    signal picked(string id)

    readonly property Item currentItem: {
        for (let i = 0; i < rep.count; i++)
            if (rep.itemAt(i)?.entry.id === current) return rep.itemAt(i);
        return null;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 40

    Rectangle {
        id: pill
        visible: root.currentItem !== null
        x: root.currentItem?.x ?? 0
        width: root.currentItem?.width ?? 0
        height: parent.height
        radius: height / 2
        color: root.accent
        Behavior on x { Anim { easing.bezierCurve: Motion.curve.springDefault } }
        Behavior on width { Anim { easing.bezierCurve: Motion.curve.springDefault } }
    }

    Row {
        id: row
        height: parent.height
        spacing: Tokens.space.xxs

        Repeater {
            id: rep
            model: root.model

            Surface {
                id: btn
                required property var modelData
                readonly property var entry: modelData
                readonly property bool selected: root.current === entry.id
                readonly property bool usable: entry.enabled !== false

                height: row.height
                width: selected ? inner.implicitWidth + Tokens.space.l * 2 : height
                radius: height / 2
                interactive: usable
                opacity: usable ? 1 : 0.38
                base: "transparent"
                content: selected ? root.accentFg : Theme.surfaceVariantFg
                onClicked: if (usable) root.picked(entry.id)

                Behavior on width { Anim { easing.bezierCurve: Motion.curve.springDefault } }

                Row {
                    id: inner
                    anchors.centerIn: parent
                    spacing: Tokens.space.s

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: btn.entry.icon
                        size: 20
                        fill: btn.selected ? 1 : 0
                        color: btn.content
                    }

                    StyledText {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        visible: btn.selected
                        text: btn.entry.label
                        font.weight: Font.DemiBold
                        color: btn.content
                    }
                }

                ToolTipBubble {
                    shown: btn.hovered && !btn.selected
                    text: btn.entry.label + (btn.entry.key ? `  ·  ${btn.entry.key}` : "")
                }
            }
        }
    }
}
