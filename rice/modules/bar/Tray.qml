import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components

Chip {
    id: root

    required property var bar

    padding: Tokens.space.s
    spacing: Tokens.space.xs

    Repeater {
        model: SystemTray.items

        Surface {
            id: trayItem
            required property SystemTrayItem modelData

            implicitWidth: 24
            implicitHeight: 24
            radius: 12
            interactive: true
            base: Theme.alpha(Theme.surface, 0)
            onClicked: m => {
                if (m.button === Qt.LeftButton && !modelData.onlyMenu) {
                    modelData.activate();
                } else if (m.button === Qt.MiddleButton) {
                    modelData.secondaryActivate();
                } else if (modelData.hasMenu) {
                    const p = trayItem.mapToItem(root.bar.contentItem, 0, trayItem.height + Tokens.space.s);
                    modelData.display(root.bar, p.x, p.y);
                }
            }
            onWheel: w => modelData.scroll(w.angleDelta.y, false)

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: trayItem.modelData.icon
            }
        }
    }
}
