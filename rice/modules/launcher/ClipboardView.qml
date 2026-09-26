pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Clipboard history: compact list on the left, full preview on the right.
Item {
    id: root

    property var items: []
    property int selected: 0
    property string copiedKey: ""
    readonly property int columns: 1
    readonly property var current: items[selected] && items[selected].entry ? items[selected].entry : null

    signal hovered(int index)
    signal activated(int index, var mouse)
    signal removeRequested(int index)

    onCurrentChanged: {
        if (!current) return;
        if (current.image) Clipboard.loadImage(current);
        else Clipboard.loadText(current);
    }

    RowLayout {
        anchors.fill: parent
        spacing: Spot.panelPadding

        // ------------------------------------------------------------ history
        ListView {
            id: list
            Layout.preferredWidth: 380
            Layout.fillHeight: true
            model: root.items
            currentIndex: root.selected
            onModelChanged: Qt.callLater(() => currentIndex = Qt.binding(() => root.selected))
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 140
            highlightResizeDuration: 0
            preferredHighlightBegin: 40
            preferredHighlightEnd: height - 40
            highlightRangeMode: ListView.ApplyRange
            cacheBuffer: 300

            highlight: Rectangle {
                radius: Tokens.radius.l
                color: Spot.selected
            }

            property point lastPointer: Qt.point(-1, -1)

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property var entry: modelData.entry || ({ id: "", image: false, text: "" })
                readonly property bool isSelected: index === root.selected
                readonly property string thumb: entry.image ? (Clipboard.images[entry.id] || "") : ""
                readonly property color fg: isSelected ? Spot.selectedFg : Theme.surfaceFg

                width: list.width
                height: 54

                Component.onCompleted: if (entry.image) Clipboard.loadImage(entry)

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.l
                    color: mouse.containsMouse && !row.isSelected ? Spot.hover : "transparent"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 12

                    ItemIcon {
                        size: 34
                        selected: row.isSelected
                        item: row.entry.image && row.thumb ? { thumb: row.thumb } : { icon: row.modelData.icon, tone: row.modelData.tone, swatch: row.modelData.swatch }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            textFormat: Text.PlainText
                            font.pixelSize: Tokens.font.m + 1
                            color: row.fg
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.copiedKey === row.modelData.key ? "Copied to clipboard" : row.modelData.subtitle
                            font.pixelSize: Tokens.font.xs + 1
                            color: root.copiedKey === row.modelData.key ? Theme.primary : Theme.alpha(row.fg, 0.65)
                        }
                    }

                    IconButton {
                        visible: mouse.containsMouse || row.isSelected
                        icon: "delete"
                        size: 30
                        iconSize: 18
                        content: row.fg
                        onClicked: root.removeRequested(row.index)
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    anchors.rightMargin: 44
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: m => {
                        const p = mapToGlobal(m.x, m.y);
                        if (p.x === list.lastPointer.x && p.y === list.lastPointer.y) return;
                        list.lastPointer = p;
                        root.hovered(row.index);
                    }
                    onClicked: m => root.activated(row.index, m)
                }
            }
        }

        // ------------------------------------------------------------ preview
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.radius.l
            color: Theme.surfaceLow

            readonly property var entry: root.current
            readonly property var payload: entry && !entry.image ? Clipboard.texts[entry.id] : null
            readonly property string imagePath: entry && entry.image ? (Clipboard.images[entry.id] || "") : ""
            readonly property string fullText: payload ? payload.text : (entry ? entry.text : "")

            id: preview

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Header: type chip + metadata
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        implicitHeight: 28
                        implicitWidth: typeRow.implicitWidth + 20
                        radius: 14
                        color: Theme.secondaryContainer
                        Row {
                            id: typeRow
                            anchors.centerIn: parent
                            spacing: 6
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.items[root.selected] && root.items[root.selected].icon || "notes"
                                size: 16
                                fill: 1
                                color: Theme.secondaryContainerFg
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.items[root.selected] && root.items[root.selected].typeLabel || ""
                                font.pixelSize: Tokens.font.s
                                font.weight: Font.DemiBold
                                color: Theme.secondaryContainerFg
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        color: Theme.surfaceVariantFg
                        font.pixelSize: Tokens.font.s
                        text: {
                            const e = preview.entry;
                            if (!e) return "";
                            if (e.image) return `${e.format.toUpperCase()} · ${e.width} × ${e.height} · ${e.size}`;
                            if (e.binary) return `Binary data · ${e.size}`;
                            if (!preview.payload) return "Loading…";
                            const t = preview.payload.text;
                            const lines = t.length ? t.split(/\r\n|\r|\n/).length : 0;
                            return `${t.length.toLocaleString()}${preview.payload.truncated ? "+" : ""} characters · ${lines} line${lines === 1 ? "" : "s"}`;
                        }
                    }
                }

                // Body
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // Colour entries get a large swatch above the value.
                    Rectangle {
                        id: swatch
                        readonly property string value: root.items[root.selected] && root.items[root.selected].swatch || ""
                        visible: value !== ""
                        anchors.top: parent.top
                        anchors.left: parent.left
                        width: 160
                        height: visible ? 120 : 0
                        radius: Tokens.radius.l
                        color: value || "transparent"
                        border.width: 1
                        border.color: Theme.alpha(Theme.surfaceFg, 0.15)
                    }

                    Flickable {
                        id: flick
                        anchors.fill: parent
                        anchors.topMargin: swatch.visible ? swatch.height + 12 : 0
                        visible: !!preview.entry && !preview.entry.image && !preview.entry.binary
                        contentWidth: width
                        contentHeight: body.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        TextEdit {
                            id: body
                            width: flick.width
                            text: preview.fullText
                            textFormat: TextEdit.PlainText
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            color: Theme.surfaceFg
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.primaryFg
                            font.family: Tokens.font.mono
                            font.pixelSize: Tokens.font.m
                        }
                    }

                    Image {
                        id: big
                        anchors.fill: parent
                        visible: preview.imagePath !== ""
                        source: preview.imagePath ? `file://${preview.imagePath}` : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 1200
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }

                    StateView {
                        anchors.fill: parent
                        visible: !!preview.entry && ((preview.entry.image && big.status !== Image.Ready) || !!preview.entry.binary)
                        info: preview.entry && preview.entry.binary
                            ? { icon: "data_object", title: "Binary data", subtitle: "No preview available" }
                            : { loading: true, title: "Decoding image…" }
                    }
                }

                // Actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Surface {
                        implicitHeight: 38
                        implicitWidth: copyRow.implicitWidth + 28
                        radius: 19
                        interactive: true
                        base: Theme.primary
                        content: Theme.primaryFg
                        onClicked: root.activated(root.selected, null)
                        Row {
                            id: copyRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { anchors.verticalCenter: parent.verticalCenter; text: "content_copy"; size: 18; color: Theme.primaryFg }
                            StyledText { anchors.verticalCenter: parent.verticalCenter; text: "Copy"; font.weight: Font.DemiBold; color: Theme.primaryFg }
                        }
                    }

                    Surface {
                        implicitHeight: 38
                        implicitWidth: delRow.implicitWidth + 28
                        radius: 19
                        interactive: true
                        base: Theme.surfaceHighest
                        content: Theme.surfaceFg
                        onClicked: root.removeRequested(root.selected)
                        Row {
                            id: delRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { anchors.verticalCenter: parent.verticalCenter; text: "delete"; size: 18; color: Theme.surfaceFg }
                            StyledText { anchors.verticalCenter: parent.verticalCenter; text: "Delete"; font.weight: Font.DemiBold }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        visible: !!preview.payload && !!preview.payload.truncated
                        text: "Preview truncated · Copy restores everything"
                        font.pixelSize: Tokens.font.s
                        color: Theme.surfaceVariantFg
                    }
                }
            }
        }
    }
}
