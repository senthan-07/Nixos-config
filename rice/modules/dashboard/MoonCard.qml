import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

WeatherCard {
    id: root

    readonly property var moon: Weather.moon
    readonly property real toFull: ((0.5 - moon.phase + 1) % 1) * 29.53
    readonly property real toNew: ((1 - moon.phase) % 1) * 29.53
    readonly property string next: toFull < toNew
        ? (toFull < 1 ? "Full moon today" : `Full moon in ${Math.round(toFull)} d`)
        : (toNew < 1 ? "New moon today" : `New moon in ${Math.round(toNew)} d`)

    title: "Moon"
    icon: "dark_mode"
    accent: Theme.primary

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.space.xs

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            MoonGlyph {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) - 4
                height: width
                rotation: -12 + 12 * root.progress
                scale: 0.8 + 0.2 * root.progress
                phase: root.moon.phase
                litColor: Theme.dark ? "#ecebe4" : "#f7f3dc"
                darkColor: Theme.alpha(Theme.surfaceFg, 0.10)
                craterColor: Qt.rgba(0, 0, 0, 0.06)
            }
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.moon.name
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: `${Math.round(root.moon.illumination * 100)}% lit · ${root.next}`
            font.pixelSize: Tokens.font.s
            color: Theme.surfaceVariantFg
        }
    }
}
