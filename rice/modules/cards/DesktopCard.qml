import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import "CardCatalog.js" as Catalog

// One card on a DesktopCanvas. Outside edit mode it is just the card; in
// edit mode an overlay takes the pointer: drag to move, × to remove. Geometry commits go through the canvas,
// which validates them against the grid.
Item {
    id: card

    required property string cardId
    required property string type
    required property int gx
    required property int gy
    required property int gw
    required property int gh
    required property var canvas

    readonly property var def: Catalog.find(type)
    readonly property bool editing: canvas.editing
    readonly property bool selected: canvas.selectedId === cardId
    readonly property bool unavailable: type === "weather" && !CardStyle.weatherAvailable

    // Pointer interaction state. `glide` enables the settle animation; it is
    // switched off while the card follows the pointer.
    property bool dragging: false
    property bool resizing: false
    property bool glide: true
    property real dragX: 0
    property real dragY: 0
    property real liveW: 0
    property real liveH: 0

    readonly property real homeX: canvas.originX + gx * CardStyle.pitch
    readonly property real homeY: canvas.originY + gy * CardStyle.pitch

    x: dragging ? dragX : homeX
    y: dragging ? dragY : homeY
    width: resizing ? liveW : CardStyle.span(gw)
    height: resizing ? liveH : CardStyle.span(gh)
    z: dragging || resizing ? 10 : selected ? 5 : 1
    visible: !unavailable || editing
    scale: dragging ? 1.03 : 1

    Behavior on x { enabled: card.glide; Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.emphasizedDecel } }
    Behavior on y { enabled: card.glide; Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.emphasizedDecel } }
    Behavior on width { enabled: card.glide; Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.emphasizedDecel } }
    Behavior on height { enabled: card.glide; Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.emphasizedDecel } }
    Behavior on scale { Anim { duration: Motion.duration.short } }

    // Appear with a small pop the first time.
    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity { Anim { duration: Motion.duration.medium } }

    Accessible.role: Accessible.Pane
    Accessible.name: def ? def.name : type

    CardContent {
        anchors.fill: parent
        type: card.type
        running: card.canvas.animate
        active: !card.unavailable
    }

    // Placeholder for a card whose backing service is missing (edit mode only).
    Rectangle {
        anchors.fill: parent
        visible: card.unavailable
        radius: Tokens.radius.xl
        color: Theme.alpha(Theme.surfaceContainer, 0.85)
        EmptyState {
            anchors.centerIn: parent
            icon: "cloud_off"
            text: "Weather service not installed"
        }
    }

    Loader {
        anchors.fill: parent
        active: card.editing
        sourceComponent: editOverlay
    }

    Component {
        id: editOverlay

        Item {
            id: overlay

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { Anim { duration: Motion.duration.short } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: Tokens.radius.xl + 4
                color: Theme.alpha(Theme.primary, move.containsMouse || card.dragging ? 0.10 : 0.04)
                border.width: card.selected ? 3 : 2
                border.color: Theme.alpha(Theme.primary, card.selected || card.dragging ? 1 : 0.55)
                Behavior on color { ColorAnim {} }
            }

            MouseArea {
                id: move
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: card.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true
                property point grab

                onPressed: m => {
                    card.canvas.select(card.cardId);
                    const p = mapToItem(card.canvas.contentItem, m.x, m.y);
                    grab = Qt.point(p.x - card.homeX, p.y - card.homeY);
                    card.glide = false;
                    card.dragX = card.homeX;
                    card.dragY = card.homeY;
                    card.dragging = true;
                }
                onPositionChanged: m => {
                    if (!card.dragging) return;
                    const p = mapToItem(card.canvas.contentItem, m.x, m.y);
                    const W = card.canvas.contentItem.width, H = card.canvas.contentItem.height;
                    card.dragX = Math.max(0, Math.min(W - card.width, p.x - grab.x));
                    card.dragY = Math.max(0, Math.min(H - card.height, p.y - grab.y));
                    card.canvas.preview(card.cardId, card.canvas.cellX(card.dragX), card.canvas.cellY(card.dragY), card.gw, card.gh);
                }
                onReleased: finish(true)
                onCanceled: finish(false)

                function finish(commit) {
                    if (!card.dragging) return;
                    const target = { x: card.canvas.cellX(card.dragX), y: card.canvas.cellY(card.dragY), w: card.gw, h: card.gh };
                    card.glide = true;
                    if (commit) card.canvas.commit(card.cardId, target, 2);
                    card.canvas.clearPreview();
                    card.dragging = false;
                }
            }

            // Name chip, sitting on the top edge so it doesn't cover the card.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: Tokens.space.l
                anchors.topMargin: -height / 2
                visible: card.selected || move.containsMouse
                implicitWidth: nameRow.implicitWidth + Tokens.space.m * 2
                implicitHeight: 26
                radius: 13
                color: Theme.primary
                RowLayout {
                    id: nameRow
                    anchors.centerIn: parent
                    spacing: Tokens.space.xs
                    Icon { text: card.def ? card.def.icon : "widgets"; size: 14; fill: 1; color: Theme.primaryFg }
                    StyledText {
                        text: card.def ? card.def.name : card.type
                        color: Theme.primaryFg
                        font.pixelSize: Tokens.font.xs
                        font.weight: Font.Bold
                    }
                }
            }

            // Remove.
            Surface {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -10
                anchors.topMargin: -10
                width: 30; height: 30; radius: 15
                interactive: true
                base: Theme.error
                content: Theme.errorFg
                onClicked: card.canvas.removeCard(card.cardId)
                Icon { anchors.centerIn: parent; text: "close"; size: 18; color: Theme.errorFg }
            }

        }
    }
}
