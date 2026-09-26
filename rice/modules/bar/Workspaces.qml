import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Workspace strip with a sliding, stretching active indicator.
Surface {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w.id > 0)
    readonly property int count: Math.max(5, activeId, ...workspaces.map(w => w.id))
    readonly property int cell: 22

    implicitHeight: Tokens.bar.chipHeight
    implicitWidth: count * cell + 8
    radius: height / 2
    base: Theme.surfaceContainer

    Behavior on implicitWidth { Anim {} }

    function occupied(id) {
        const ws = workspaces.find(w => w.id === id);
        return ws ? ws.toplevels.values.length > 0 : false;
    }

    function urgent(id) {
        return workspaces.find(w => w.id === id)?.urgent ?? false;
    }

    // Two edges animate at different speeds so the pill stretches while moving.
    Item {
        id: indicator
        property real target: (root.activeId - 1) * root.cell + 4
        property real leading: target
        property real trailing: target
        Behavior on leading { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.emphasizedDecel } }
        Behavior on trailing { Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.emphasizedDecel } }
        onTargetChanged: { leading = target; trailing = target; }
    }

    Rectangle {
        x: Math.min(indicator.leading, indicator.trailing)
        width: Math.abs(indicator.leading - indicator.trailing) + root.cell
        anchors.verticalCenter: parent.verticalCenter
        height: root.cell
        radius: height / 2
        color: Theme.primary
    }

    Row {
        x: 4
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.count

            Item {
                id: cellItem
                required property int index
                readonly property int wsId: index + 1
                readonly property bool active: wsId === root.activeId

                width: root.cell
                height: root.cell

                Rectangle {
                    anchors.centerIn: parent
                    visible: !cellItem.active
                    width: root.occupied(cellItem.wsId) ? 8 : 5
                    height: width
                    radius: width / 2
                    color: root.urgent(cellItem.wsId) ? Theme.error
                        : root.occupied(cellItem.wsId) ? Theme.surfaceVariantFg : Theme.outlineVariant
                    Behavior on width { Anim { duration: Motion.duration.short } }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: cellItem.active
                    text: cellItem.wsId
                    color: Theme.primaryFg
                    font.pixelSize: Tokens.font.s
                    font.weight: Font.Bold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.focusWorkspace(cellItem.wsId)
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => Hypr.focusWorkspace(w.angleDelta.y > 0 ? "e-1" : "e+1")
    }
}
