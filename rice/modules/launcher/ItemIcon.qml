import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components

// Leading visual for a result: app icon, emoji, image thumbnail, themed
// file icon or a Material glyph on a tonal tile.
Item {
    id: root

    property var item: ({})
    readonly property var d: item || ({})
    property real size: Spot.iconSize
    property bool selected: false

    implicitWidth: size
    implicitHeight: size

    readonly property string kind: d.swatch ? "swatch"
        : d.appIcon !== undefined ? "app"
        : d.glyph ? "glyph"
        : d.thumb ? "thumb"
        : d.file ? "file" : "symbol"

    // --- app icon
    AppIcon {
        anchors.centerIn: parent
        visible: root.kind === "app"
        size: root.size
        name: root.kind === "app" ? (root.d.appIcon || "") : ""
    }

    // --- colour swatch
    Rectangle {
        anchors.fill: parent
        visible: root.kind === "swatch"
        radius: root.size * 0.32
        color: root.kind === "swatch" ? root.d.swatch : "transparent"
        border.width: 1
        border.color: Theme.alpha(Theme.surfaceFg, 0.2)
    }

    // --- emoji
    Text {
        anchors.centerIn: parent
        visible: root.kind === "glyph"
        text: root.d.glyph || ""
        font.pixelSize: root.size * 0.72
        renderType: Text.NativeRendering
    }

    // --- image thumbnail
    Item {
        anchors.fill: parent
        visible: root.kind === "thumb"

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radius.s
            color: Theme.surfaceHighest
        }

        Image {
            id: thumb
            anchors.fill: parent
            source: root.kind === "thumb" ? `file://${root.d.thumb}` : ""
            sourceSize.width: root.size * 2
            sourceSize.height: root.size * 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        Rectangle {
            id: thumbMask
            anchors.fill: parent
            radius: Tokens.radius.s
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: thumb
            maskEnabled: true
            maskSource: thumbMask
            visible: thumb.status === Image.Ready
        }
    }

    // --- themed file icon with glyph fallback
    readonly property var fileMeta: ({
        folder: ["folder", "folder", "primary"],
        image: ["image-x-generic", "image", "tertiary"],
        video: ["video-x-generic", "movie", "tertiary"],
        audio: ["audio-x-generic", "music_note", "tertiary"],
        pdf: ["application-pdf", "picture_as_pdf", "error"],
        doc: ["x-office-document", "description", "neutral"],
        sheet: ["x-office-spreadsheet", "table_chart", "neutral"],
        slides: ["x-office-presentation", "slideshow", "neutral"],
        archive: ["package-x-generic", "folder_zip", "neutral"],
        code: ["text-x-script", "code", "neutral"],
        exec: ["application-x-executable", "terminal", "neutral"],
        file: ["text-x-generic", "draft", "neutral"]
    })
    readonly property var meta: kind === "file" ? (fileMeta[d.file.kind] || fileMeta.file) : null
    readonly property string themeIcon: meta && Quickshell.hasThemeIcon(meta[0]) ? Quickshell.iconPath(meta[0]) : ""

    IconImage {
        id: fileImg
        anchors.centerIn: parent
        visible: root.kind === "file" && root.themeIcon !== "" && status === Image.Ready
        implicitSize: root.size
        source: root.kind === "file" ? root.themeIcon : ""
        asynchronous: true
    }

    // --- Material glyph tile
    readonly property string tone: kind === "file" ? meta[2] : (d.tone || "neutral")
    readonly property bool showTile: kind === "symbol" || (kind === "file" && !fileImg.visible)

    Rectangle {
        anchors.fill: parent
        visible: root.showTile
        radius: root.size * 0.32
        color: root.tone === "primary" ? Theme.primaryContainer
            : root.tone === "tertiary" ? Theme.tertiaryContainer
            : root.tone === "error" ? Theme.errorContainer
            : root.tone === "secondary" ? Theme.secondaryContainer
            : root.selected ? Theme.alpha(Theme.surfaceFg, 0.08) : Theme.surfaceHighest
        Behavior on color { ColorAnim {} }

        Icon {
            anchors.centerIn: parent
            text: root.kind === "file" ? root.meta[1] : (root.d.icon || "circle")
            size: root.size * 0.55
            fill: root.selected ? 1 : 0
            color: root.tone === "primary" ? Theme.primaryContainerFg
                : root.tone === "tertiary" ? Theme.tertiaryContainerFg
                : root.tone === "error" ? Theme.errorContainerFg
                : root.tone === "secondary" ? Theme.secondaryContainerFg
                : Theme.surfaceVariantFg
        }
    }
}
