pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.config
import qs.components

// Card below the search pill. Hosts the active view, morphs its size
// between modes and shows context key hints.
Item {
    id: root

    property string view: "list"          // list | appgrid | wallgrid | emoji | clipboard
    property var items: []
    property int selected: 0
    property var info: null               // StateView info when there is nothing to show
    property var hints: []                // [[keys, label]]
    property string status: ""            // right side of the footer
    property var preview: null            // { glyph, title } footer preview (emoji)
    property string confirmKey: ""
    property string copiedKey: ""
    property bool showLayoutToggle: false
    property bool gridLayout: false

    readonly property int columns: activeView && activeView.columns ? activeView.columns : 1
    readonly property var activeView: view === "list" ? list
        : view === "appgrid" ? appGrid
        : view === "wallgrid" ? wallGrid
        : view === "emoji" ? emojiGrid
        : view === "clipboard" ? clipLoader.item : null

    signal hovered(int index)
    signal activated(int index, var mouse)
    signal secondary(int index)
    signal removeRequested(int index)
    signal layoutRequested(bool grid)
    signal infoAction()

    function itemsFor(v) {
        return root.view === v && (!root.items.length || root.items[0].view === v) ? root.items : [];
    }

    readonly property bool showingInfo: !!info && items.length === 0

    readonly property real targetWidth: view === "appgrid" ? Spot.gridWidth
        : view === "wallgrid" ? Spot.wallWidth
        : view === "clipboard" && !showingInfo ? Spot.clipWidth
        : Spot.searchWidth
    readonly property real bodyHeight: {
        if (showingInfo) return 230;
        switch (view) {
        case "appgrid": return Math.min(appGrid.naturalHeight, Spot.gridCellHeight * 4);
        case "wallgrid": return Math.min(wallGrid.naturalHeight, 560);
        case "emoji": return Math.min(emojiGrid.naturalHeight, Spot.emojiCell * 6);
        case "clipboard": return Spot.clipHeight;
        default: return Math.min(list.naturalHeight, Spot.listMaxHeight);
        }
    }
    readonly property real targetHeight: Math.max(Spot.rowHeight, bodyHeight) + Spot.panelPadding * 2 + Spot.footerHeight

    width: targetWidth
    height: targetHeight
    Behavior on width { Anim { duration: Spot.panelDuration; easing.bezierCurve: Motion.curve.emphasizedDecel } }
    Behavior on height { Anim { duration: Spot.panelDuration; easing.bezierCurve: Motion.curve.emphasizedDecel } }

    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        blur: 28
        spread: 0
        offset.y: 8
        color: Spot.shadow
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Spot.panelRadius
        color: Spot.panel
        clip: true

        MouseArea { anchors.fill: parent }     // swallow clicks so the scrim doesn't close us

        Item {
            id: body
            x: Spot.panelPadding
            y: Spot.panelPadding
            width: parent.width - Spot.panelPadding * 2
            height: parent.height - Spot.panelPadding * 2 - Spot.footerHeight

            StateView {
                anchors.fill: parent
                visible: root.showingInfo
                info: root.info || ({})
                onActionClicked: root.infoAction()
            }

            ResultList {
                id: list
                anchors.fill: parent
                visible: root.view === "list" && !root.showingInfo
                items: root.itemsFor("list")
                selected: root.selected
                confirmKey: root.confirmKey
                copiedKey: root.copiedKey
                onHovered: i => root.hovered(i)
                onActivated: (i, m) => root.activated(i, m)
                onSecondary: i => root.secondary(i)
            }

            AppGrid {
                id: appGrid
                anchors.fill: parent
                visible: root.view === "appgrid" && !root.showingInfo
                items: root.itemsFor("appgrid")
                selected: root.selected
                onHovered: i => root.hovered(i)
                onActivated: (i, m) => root.activated(i, m)
                onSecondary: i => root.secondary(i)
            }

            WallpaperGrid {
                id: wallGrid
                anchors.fill: parent
                visible: root.view === "wallgrid" && !root.showingInfo
                items: root.itemsFor("wallgrid")
                selected: root.selected
                onHovered: i => root.hovered(i)
                onActivated: (i, m) => root.activated(i, m)
            }

            EmojiGrid {
                id: emojiGrid
                anchors.fill: parent
                visible: root.view === "emoji" && !root.showingInfo
                items: root.itemsFor("emoji")
                selected: root.selected
                onHovered: i => root.hovered(i)
                onActivated: (i, m) => root.activated(i, m)
            }

            Loader {
                id: clipLoader
                anchors.fill: parent
                active: root.view === "clipboard"
                visible: active && !root.showingInfo
                sourceComponent: ClipboardView {
                    items: root.itemsFor("clipboard")
                    selected: root.selected
                    copiedKey: root.copiedKey
                    onHovered: i => root.hovered(i)
                    onActivated: (i, m) => root.activated(i, m)
                    onRemoveRequested: i => root.removeRequested(i)
                }
            }
        }

        // ------------------------------------------------------------ footer
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            height: 1
            color: Theme.alpha(Theme.outlineVariant, 0.5)
        }

        Item {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Spot.footerHeight

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 10
                spacing: 16

                // Emoji preview replaces the hints.
                Row {
                    visible: !!root.preview
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.preview ? root.preview.glyph : ""
                        font.pixelSize: 20
                        renderType: Text.NativeRendering
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.preview ? root.preview.title : ""
                        font.weight: Font.Medium
                    }
                }

                Repeater {
                    model: root.preview ? [] : root.hints
                    KeyHint {
                        required property var modelData
                        keys: modelData[0]
                        label: modelData[1]
                    }
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    visible: text !== ""
                    text: root.status
                    font.pixelSize: Tokens.font.s
                    color: Theme.surfaceVariantFg
                }

                // List / grid segmented toggle
                Rectangle {
                    visible: root.showLayoutToggle
                    implicitWidth: 64
                    implicitHeight: 28
                    radius: 14
                    color: Theme.alpha(Theme.surfaceFg, 0.06)

                    Rectangle {
                        x: root.gridLayout ? 32 : 0
                        width: 32
                        height: 28
                        radius: 14
                        color: Theme.secondaryContainer
                        Behavior on x { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.emphasizedDecel } }
                    }

                    Row {
                        Repeater {
                            model: [["view_list", false], ["grid_view", true]]
                            Item {
                                required property var modelData
                                width: 32
                                height: 28
                                Icon {
                                    anchors.centerIn: parent
                                    text: parent.modelData[0]
                                    size: 17
                                    fill: root.gridLayout === parent.modelData[1] ? 1 : 0
                                    color: root.gridLayout === parent.modelData[1] ? Theme.secondaryContainerFg : Theme.surfaceVariantFg
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.layoutRequested(parent.modelData[1])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
