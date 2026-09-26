import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Big-number clock: hours in primary, minutes in secondary, date underneath.
// Stacks the digits when the card is taller than it is wide.
Item {
    id: root

    property bool elevated: true

    readonly property bool h12: !Settings.data.use24h
    readonly property int hour: Time.now.getHours()
    readonly property string hh: String(h12 ? ((hour + 11) % 12) + 1 : hour).padStart(2, "0")
    readonly property string mm: String(Time.now.getMinutes()).padStart(2, "0")
    readonly property bool stacked: height > width * 0.85
    readonly property real digitSize: stacked ? Math.min(width * 0.62, (height - dateLine.height) * 0.5)
                                              : Math.min(height * 0.72, width * 0.36)

    implicitWidth: 368
    implicitHeight: 176

    Accessible.role: Accessible.Clock
    Accessible.name: `${hh}:${mm} ${dateLine.text}`

    Item {
        id: group
        anchors.centerIn: parent
        width: Math.max(digits.width, dateLine.width)
        height: digits.height + dateLine.height
        layer.enabled: root.elevated
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.alpha(Theme.shadow, 0.45)
            shadowBlur: 0.8
            shadowVerticalOffset: 3
            autoPaddingEnabled: true
        }

        GridLayout {
            id: digits
            anchors.horizontalCenter: parent.horizontalCenter
            columns: root.stacked ? 1 : 3
            rowSpacing: -root.digitSize * 0.22
            columnSpacing: root.digitSize * 0.04

            Digits { text: root.hh; color: Theme.primary }
            Text {
                visible: !root.stacked
                text: ":"
                color: Theme.alpha(Theme.surfaceFg, 0.5)
                font.family: CardStyle.display
                font.pixelSize: root.digitSize * 0.8
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter
                Layout.bottomMargin: root.digitSize * 0.1
            }
            Digits { text: root.mm; color: Theme.secondary }
        }

        StyledText {
            id: dateLine
            anchors.top: digits.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(Time.now, "dddd · d MMMM") + (root.h12 ? (root.hour >= 12 ? "  PM" : "  AM") : "")
            color: Theme.surfaceFg
            font.family: CardStyle.display
            font.pixelSize: Math.max(12, root.digitSize * 0.16)
            font.weight: Font.DemiBold
            font.letterSpacing: 1.5
        }
    }

    component Digits: Text {
        font.family: CardStyle.display
        font.pixelSize: root.digitSize
        font.weight: Font.Black
        font.features: { "tnum": 1 }
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
        Behavior on color { ColorAnim {} }
    }
}
