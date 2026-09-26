import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Apparent temperature against the measured one on a cold → hot scale.
WeatherCard {
    id: root

    readonly property var c: Weather.current
    readonly property real actual: c ? c.temp : NaN
    readonly property real feels: c ? c.feelsLike : NaN
    readonly property real diff: feels - actual
    readonly property real lo: Math.min(actual, feels) - 8
    readonly property real hi: Math.max(actual, feels) + 8
    readonly property string note: {
        if (!Weather.valid(diff)) return "";
        const tol = Weather.unit === "F" ? 2 : 1;
        if (Math.abs(diff) <= tol) return "Similar to the actual temperature";
        if (diff > 0) return c.humidity > 55 ? "Humidity makes it feel warmer" : "Feels warmer than it is";
        return c.windSpeed > 12 ? "Wind makes it feel cooler" : "Feels cooler than it is";
    }

    title: "Feels like"
    icon: "thermostat"
    accent: Theme.tertiary

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.space.s

        StyledText {
            text: Weather.fmtTemp(root.feels)
            font.pixelSize: 40
            font.weight: Font.Normal
            font.features: { "tnum": 1 }
        }

        // Scale with a hollow marker for the actual and a filled one for the
        // apparent temperature.
        Item {
            Layout.fillWidth: true
            implicitHeight: 16

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#6aa8ff" }
                    GradientStop { position: 0.5; color: "#f5c33b" }
                    GradientStop { position: 1; color: "#ff6b4a" }
                }
                opacity: 0.85
            }
            Rectangle {
                readonly property real f: (root.actual - root.lo) / (root.hi - root.lo)
                x: (Weather.valid(f) ? f : 0.5) * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7
                color: Theme.surfaceContainer
                border.width: 2
                border.color: Theme.surfaceVariantFg
            }
            Rectangle {
                readonly property real f: (root.feels - root.lo) / (root.hi - root.lo)
                x: (Weather.valid(f) ? 0.5 + (f - 0.5) * root.progress : 0.5) * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; radius: 8
                color: Theme.tertiary
                border.width: 3
                border.color: Theme.surfaceContainer
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignBottom
            text: root.note + (Weather.valid(root.actual) ? `\nActual ${Weather.fmtTemp(root.actual)}` : "")
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            font.pixelSize: Tokens.font.s
            color: Theme.surfaceVariantFg
        }
    }
}
