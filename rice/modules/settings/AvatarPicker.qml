import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services
import "widgets"

// Image picker for the profile picture, drawn over the Settings window while
// Avatar.picking is set. Browse folders, click an image to use it.
Item {
    id: root

    property string folder: Paths.picturesDir

    visible: opacity > 0
    opacity: Avatar.picking ? 1 : 0
    Behavior on opacity { Anim { duration: Motion.duration.short } }

    onVisibleChanged: if (visible) forceActiveFocus()
    Keys.onEscapePressed: Avatar.picking = false

    readonly property var places: [
        { label: "Pictures", icon: "photo_library", path: Paths.picturesDir },
        { label: "Wallpapers", icon: "wallpaper", path: Settings.data.wallpaperDir || Paths.wallpaperDir },
        { label: "Downloads", icon: "download", path: `${Paths.home}/Downloads` },
        { label: "Home", icon: "home", path: Paths.home }
    ]

    // Scrim
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.scrim, 0.45)
        MouseArea { anchors.fill: parent; onClicked: Avatar.picking = false }
    }

    Rectangle {
        id: sheet
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 820)
        height: Math.min(parent.height - 48, 600)
        radius: Tokens.radius.xl
        color: Theme.surfaceContainer
        scale: Avatar.picking ? 1 : 0.96
        Behavior on scale { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }
        MouseArea { anchors.fill: parent }   // swallow clicks

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.space.xl
            spacing: Tokens.space.m

            RowLayout {
                spacing: Tokens.space.m
                StyledText {
                    Layout.fillWidth: true
                    text: "Choose a profile picture"
                    font.pixelSize: Tokens.font.xl
                    font.weight: Font.DemiBold
                }
                ActionButton {
                    visible: Avatar.path !== ""
                    style: "text"
                    icon: "delete"
                    text: "Remove photo"
                    onClicked: Avatar.clear()
                }
                IconButton { icon: "close"; onClicked: Avatar.picking = false }
            }

            // Places + current folder
            RowLayout {
                spacing: Tokens.space.s
                Repeater {
                    model: root.places
                    Surface {
                        id: place
                        required property var modelData
                        readonly property bool active: root.folder === modelData.path
                        implicitHeight: 34
                        implicitWidth: placeRow.implicitWidth + Tokens.space.l * 2
                        radius: height / 2
                        interactive: true
                        base: active ? Theme.secondaryContainer : Theme.alpha(Theme.surface, 0)
                        content: active ? Theme.secondaryContainerFg : Theme.surfaceVariantFg
                        border.width: active ? 0 : 1
                        border.color: Theme.outlineVariant
                        onClicked: root.folder = modelData.path
                        RowLayout {
                            id: placeRow
                            anchors.centerIn: parent
                            spacing: Tokens.space.xs
                            Icon { text: place.modelData.icon; size: 18; fill: place.active ? 1 : 0; color: place.content }
                            StyledText { text: place.modelData.label; color: place.content; font.weight: Font.Medium }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            RowLayout {
                spacing: Tokens.space.s
                IconButton {
                    icon: "arrow_upward"
                    enabled: root.folder !== "/"
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.folder = root.folder.replace(/\/[^\/]+\/?$/, "") || "/"
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.folder.replace(Paths.home, "~")
                    color: Theme.surfaceVariantFg
                    elide: Text.ElideMiddle
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                readonly property int columns: Math.max(3, Math.floor(width / 150))
                cellWidth: Math.floor(width / columns)
                cellHeight: cellWidth + 22
                ScrollBar.vertical: ScrollBar {}

                model: FolderListModel {
                    id: files
                    folder: "file://" + root.folder
                    showDirsFirst: true
                    showHidden: false
                    caseSensitive: false
                    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.avif", "*.svg"]
                }

                delegate: Item {
                    id: cell
                    required property string fileName
                    required property string filePath
                    required property bool fileIsDir

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Surface {
                        id: tile
                        anchors.fill: parent
                        anchors.margins: Tokens.space.xs
                        radius: Tokens.radius.m
                        interactive: true
                        base: hovered ? Theme.surfaceHigh : Theme.alpha(Theme.surfaceHigh, 0)
                        onClicked: cell.fileIsDir ? root.folder = cell.filePath : Avatar.set(cell.filePath)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.space.s
                            spacing: Tokens.space.xs

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Icon {
                                    anchors.centerIn: parent
                                    visible: cell.fileIsDir
                                    text: "folder"
                                    fill: 1
                                    size: 56
                                    color: Theme.primary
                                }
                                // Circular preview, as the picture will appear.
                                ClippingRectangle {
                                    anchors.centerIn: parent
                                    visible: !cell.fileIsDir
                                    width: Math.min(parent.width, parent.height)
                                    height: width
                                    radius: width / 2
                                    color: Theme.surfaceHighest
                                    border.width: tile.hovered ? 3 : 0
                                    border.color: Theme.primary
                                    Image {
                                        anchors.fill: parent
                                        source: cell.fileIsDir ? "" : "file://" + cell.filePath
                                        sourceSize.width: 200
                                        sourceSize.height: 200
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: cell.fileName
                                font.pixelSize: Tokens.font.s
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideMiddle
                                color: Theme.surfaceVariantFg
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: files.status === FolderListModel.Ready && grid.count === 0
                    text: "No images in this folder"
                    color: Theme.surfaceVariantFg
                }
            }
        }
    }
}
