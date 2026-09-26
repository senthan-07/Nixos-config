import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.config
import qs.components

// Magnifier for the colour picker: a pixel grid of the frozen frame around
// (px, py) plus the colour under the centre cell.
Rectangle {
    id: root

    required property Item source      // the frozen ScreencopyView
    property real px: 0                // logical position being inspected
    property real py: 0
    property real dpr: 1
    property color picked: "black"
    property string hex: "#000000"
    readonly property int cells: 15    // odd, so there is a centre pixel
    readonly property int zoomSize: 150

    width: zoomSize + Tokens.space.s * 2
    height: zoomSize + info.implicitHeight + Tokens.space.s * 3
    radius: Tokens.radius.xl
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Theme.alpha(Theme.outlineVariant, 0.7)

    Item {
        id: zoomBox
        x: Tokens.space.s
        y: Tokens.space.s
        width: root.zoomSize
        height: root.zoomSize
        visible: false
        layer.enabled: true

        // One screen pixel per cell (physical pixels on scaled outputs).
        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: root.source
            smooth: false
            mipmap: false
            live: true
            hideSource: false
            readonly property real half: (root.cells / root.dpr) / 2
            sourceRect: Qt.rect(Math.floor(root.px * root.dpr) / root.dpr - half + 0.5 / root.dpr,
                                Math.floor(root.py * root.dpr) / root.dpr - half + 0.5 / root.dpr,
                                root.cells / root.dpr, root.cells / root.dpr)
            textureSize: Qt.size(root.cells, root.cells)
        }

        // Pixel grid.
        Repeater {
            model: root.cells - 1
            Rectangle {
                required property int index
                x: Math.round((index + 1) * root.zoomSize / root.cells)
                width: 1
                height: root.zoomSize
                color: Theme.alpha("black", 0.12)
            }
        }
        Repeater {
            model: root.cells - 1
            Rectangle {
                required property int index
                y: Math.round((index + 1) * root.zoomSize / root.cells)
                height: 1
                width: root.zoomSize
                color: Theme.alpha("black", 0.12)
            }
        }

        // Centre cell.
        Rectangle {
            readonly property real cell: root.zoomSize / root.cells
            x: Math.floor(root.cells / 2) * cell - 1
            y: x
            width: cell + 2
            height: cell + 2
            color: "transparent"
            border.width: 2
            border.color: "white"
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                color: "transparent"
                border.width: 1
                border.color: "black"
            }
        }
    }

    Rectangle {
        id: zoomMask
        width: root.zoomSize
        height: root.zoomSize
        radius: Tokens.radius.l
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        x: zoomBox.x
        y: zoomBox.y
        width: zoomBox.width
        height: zoomBox.height
        source: zoomBox
        maskEnabled: true
        maskSource: zoomMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    RowLayout {
        id: info
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.space.s
        anchors.leftMargin: Tokens.space.m
        anchors.bottomMargin: Tokens.space.m
        spacing: Tokens.space.s

        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: Tokens.radius.s
            color: root.picked
            border.width: 1
            border.color: Theme.alpha(Theme.surfaceFg, 0.2)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                text: root.hex.toUpperCase()
                font.family: Tokens.font.mono
                font.pixelSize: Tokens.font.l
                font.weight: Font.Bold
            }
            StyledText {
                text: `${Math.round(root.picked.r * 255)}, ${Math.round(root.picked.g * 255)}, ${Math.round(root.picked.b * 255)}`
                font.family: Tokens.font.mono
                font.pixelSize: Tokens.font.xs
                color: Theme.surfaceVariantFg
            }
        }
    }
}
