import QtQuick
import QtQuick.Layouts
import qs.config
import "CardCatalog.js" as Catalog

// Vertical stack of system cards for the sidebar (or any column). Each row
// lists card types and a height; square cards (clock, liquid metrics) take
// height × height, the others share the remaining width.
//   CardsColumn { Layout.fillWidth: true }
//   CardsColumn { rows: [{ types: ["cpuTile", "memTile"], height: 150 }] }
ColumnLayout {
    id: root

    property bool running: visible
    property bool elevated: false
    property var rows: [
        { types: ["clock", CardStyle.weatherAvailable ? "weather" : "digital"], height: 168 },
        { types: ["cpu", "memory", "gpu", "temp"], height: 88 },
        { types: ["network"], height: 150 }
    ]

    spacing: Tokens.space.m

    Repeater {
        model: root.rows

        RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: modelData.height
            spacing: Tokens.space.m

            Repeater {
                model: row.modelData.types

                CardContent {
                    required property string modelData
                    readonly property var def: Catalog.find(modelData)
                    readonly property bool square: !!(def && def.square)
                    type: modelData
                    running: root.running
                    elevated: root.elevated
                    Layout.fillHeight: true
                    Layout.fillWidth: !square
                    Layout.preferredWidth: square ? row.modelData.height : 1
                    Layout.maximumWidth: square ? row.modelData.height : Number.POSITIVE_INFINITY
                }
            }
        }
    }
}
