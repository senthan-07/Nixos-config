import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Body of WeatherCard; references the Weather singleton (services/Weather.qml).
// Layout: temperature + condition top-left, glyph top-right, place and
// high/low along the bottom; tall cards add an hourly strip.
Item {
    id: root

    property bool elevated: true
    property bool running: true

    readonly property var cur: Weather.current
    readonly property bool hasData: Weather.ready && !!cur
    readonly property bool busy: !hasData && (Weather.loading ?? true) && !(Weather.error ?? "")
    readonly property var today: (Weather.daily || [])[0] || null
    readonly property bool tall: height >= 250
    readonly property real pad: Tokens.space.l + Math.min(bg.radius, 40) * 0.3
    readonly property string icon: hasData ? (cur.icon || Weather.iconFor(cur.code, cur.isDay)) : "cloud"

    function temp(v) {
        return v === undefined || v === null || isNaN(v) ? "--°" : Math.round(v) + "°";
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: hasData ? `Weather ${Weather.location}: ${temp(cur.temp)}, ${cur.description}` : "Weather unavailable"

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Math.min(height / 2, Tokens.radius.xl * 1.6)
        color: Theme.primaryContainer
        Behavior on color { ColorAnim {} }
        layer.enabled: root.elevated
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.alpha(Theme.shadow, 0.35)
            shadowBlur: 0.7
            shadowVerticalOffset: 3
            autoPaddingEnabled: true
        }
    }

    EmptyState {
        anchors.centerIn: parent
        visible: !root.hasData
        busy: root.busy
        icon: "cloud_off"
        text: root.busy ? "Fetching weather…" : (Weather.error || "Weather unavailable")
    }

    IconButton {
        visible: !root.hasData && !root.busy
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.space.m
        icon: "refresh"
        size: 32
        onClicked: Weather.refresh()
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: root.pad
        anchors.topMargin: Tokens.space.l
        anchors.bottomMargin: Tokens.space.l
        visible: root.hasData

        ColumnLayout {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.right: glyph.left
            spacing: -6
            StyledText {
                text: root.temp(root.cur?.temp)
                color: Theme.primary
                font.family: CardStyle.display
                font.pixelSize: Math.min(72, root.height * 0.38, root.width * 0.26)
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.cur?.description ?? ""
                color: Theme.primaryContainerFg
                font.pixelSize: Tokens.font.l
                font.weight: Font.DemiBold
            }
        }

        Icon {
            id: glyph
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: -Tokens.space.xs
            text: root.icon
            size: Math.min(80, root.height * 0.42, root.width * 0.22)
            fill: 1
            color: Theme.primaryContainerFg
            // Gentle float.
            transform: Translate {
                id: bob
                SequentialAnimation on y {
                    running: root.running && root.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: 4; duration: 2600; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 4; to: 0; duration: 2600; easing.type: Easing.InOutSine }
                }
            }
        }

        // Next hours, only when the card is tall enough.
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.bottomMargin: Tokens.space.s
            visible: root.tall && (Weather.hourly || []).length > 0
            spacing: Tokens.space.xs

            Repeater {
                model: (Weather.hourly || []).slice(1, root.width >= 330 ? 7 : 5)
                Rectangle {
                    id: hour
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 76
                    radius: Tokens.radius.l
                    color: Theme.alpha(Theme.surface, 0.3)
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatTime(hour.modelData.time, Settings.data.use24h ? "HH" : "h AP")
                            color: Theme.alpha(Theme.primaryContainerFg, 0.8)
                            font.pixelSize: Tokens.font.xs
                        }
                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            text: hour.modelData.icon || Weather.iconFor(hour.modelData.code, hour.modelData.isDay)
                            size: 22
                            fill: 1
                            color: Theme.primaryContainerFg
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.temp(hour.modelData.temp)
                            color: Theme.primaryContainerFg
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }

        RowLayout {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: Tokens.space.s

            Icon { text: "location_on"; size: 15; fill: 1; color: Theme.alpha(Theme.primaryContainerFg, 0.8) }
            StyledText {
                Layout.fillWidth: true
                text: (Weather.location || "—").split(",")[0]
                color: Theme.primaryContainerFg
                font.pixelSize: Tokens.font.s
                font.weight: Font.DemiBold
            }
            StyledText {
                visible: !!root.today && root.width >= 240
                text: root.today ? `↑ ${root.temp(root.today.max)}  ↓ ${root.temp(root.today.min)}` : ""
                color: Theme.alpha(Theme.primaryContainerFg, 0.85)
                font.pixelSize: Tokens.font.s
                font.features: { "tnum": 1 }
            }
            StyledText {
                visible: root.width >= 300
                text: `· feels ${root.temp(root.cur?.feelsLike)}`
                color: Theme.alpha(Theme.primaryContainerFg, 0.7)
                font.pixelSize: Tokens.font.s
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: Weather.refresh()
    }
}
