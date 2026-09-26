import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Hub "Tools" tab: quick actions. Arrow keys move the selection, Enter runs it,
// hovering selects. Actions are defined in IslandState.tools.
Item {
    id: root

    property int selected: 0
    readonly property var tools: IslandState.tools

    implicitWidth: 780
    implicitHeight: 128

    function move(step) { selected = (selected + step + tools.length) % tools.length; }
    function trigger() { if (tools[selected]) IslandState.runTool(tools[selected].id); }

    onVisibleChanged: if (visible) selected = 0

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.space.s

        Repeater {
            model: root.tools

            Surface {
                id: tile
                required property var modelData
                required property int index
                readonly property bool current: index === root.selected

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: current ? Tokens.radius.xl : Tokens.radius.l
                interactive: true
                base: current ? Theme.primaryContainer : Theme.surfaceHigh
                content: current ? Theme.primaryContainerFg : Theme.surfaceFg
                onHoveredChanged: if (hovered) root.selected = index
                onClicked: { root.selected = index; root.trigger(); }
                Behavior on radius { Anim { duration: Motion.duration.short } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.space.xs

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 48
                        implicitHeight: 48
                        radius: tile.current ? Tokens.radius.m : 24
                        color: tile.current ? Theme.primary : Theme.surfaceHighest
                        Behavior on radius { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }
                        Behavior on color { ColorAnim {} }
                        Icon {
                            anchors.centerIn: parent
                            text: tile.modelData.icon
                            size: 24
                            fill: tile.current ? 1 : 0
                            color: tile.current ? Theme.primaryFg : Theme.surfaceFg
                        }
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.modelData.label
                        font.weight: Font.DemiBold
                        color: tile.content
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.modelData.hint
                        font.pixelSize: Tokens.font.xs
                        color: tile.content
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
