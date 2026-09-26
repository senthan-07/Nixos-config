import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Seven-day outlook. Each day's range is drawn on a shared scale so warm and
// cold days stand out; click a day for its details.
WeatherCard {
    id: root

    readonly property var days: Weather.daily
    readonly property real lo: days.length ? Math.min(...days.map(d => d.min)) : 0
    readonly property real hi: days.length ? Math.max(...days.map(d => d.max)) : 1
    property int expanded: -1

    function dayName(d, i) {
        if (i === 0) return "Today";
        if (i === 1) return "Tomorrow";
        return Qt.formatDate(d, "dddd");
    }

    title: "7-day forecast"
    icon: "calendar_month"
    implicitHeight: 34 + Tokens.space.l + list.implicitHeight + Tokens.space.xs + 4

    Column {
        id: list
        width: parent.width

        Repeater {
            model: root.days

            Surface {
                id: row
                required property var modelData
                required property int index
                readonly property bool open: root.expanded === index

                width: list.width
                implicitHeight: 44 + (open ? details.implicitHeight + Tokens.space.s : 0)
                height: implicitHeight
                clip: true
                radius: Tokens.radius.l
                interactive: true
                base: open ? Theme.surfaceHigh : Theme.alpha(Theme.surfaceContainer, 0)
                content: Theme.surfaceFg
                onClicked: root.expanded = open ? -1 : index

                Behavior on implicitHeight { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }

                RowLayout {
                    x: Tokens.space.s
                    width: parent.width - Tokens.space.s * 2
                    height: 44
                    spacing: Tokens.space.s

                    StyledText {
                        Layout.preferredWidth: 78
                        text: root.dayName(row.modelData.date, row.index)
                        font.weight: row.index === 0 ? Font.DemiBold : Font.Normal
                    }
                    Icon {
                        Layout.preferredWidth: 26
                        text: row.modelData.icon
                        size: 22
                        fill: 1
                    }
                    StyledText {
                        Layout.preferredWidth: 34
                        text: row.modelData.precipProb >= 20 ? Math.round(row.modelData.precipProb) + "%" : ""
                        font.pixelSize: Tokens.font.xs
                        font.weight: Font.DemiBold
                        color: "#5aa9ff"
                    }
                    StyledText {
                        Layout.preferredWidth: 30
                        horizontalAlignment: Text.AlignRight
                        text: Weather.fmtTemp(row.modelData.min)
                        color: Theme.surfaceVariantFg
                        font.features: { "tnum": 1 }
                    }

                    // Range bar on the week's scale.
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        readonly property real span: Math.max(1, root.hi - root.lo)
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Theme.alpha(Theme.surfaceFg, 0.08)
                        }
                        Rectangle {
                            readonly property real a: (row.modelData.min - root.lo) / parent.span
                            readonly property real b: (row.modelData.max - root.lo) / parent.span
                            x: a * parent.width
                            width: Math.max(6, (b - a) * parent.width * root.progress)
                            height: parent.height
                            radius: 3
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.secondary }
                                GradientStop { position: 1; color: Theme.tertiary }
                            }
                        }
                        // Current temperature on today's bar.
                        Rectangle {
                            visible: row.index === 0 && Weather.current !== null
                            readonly property real f: Weather.current ? (Weather.current.temp - root.lo) / parent.span : 0
                            x: Math.max(0, Math.min(1, f)) * parent.width - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10; height: 10; radius: 5
                            color: Theme.surfaceFg
                            border.width: 2
                            border.color: Theme.surfaceContainer
                        }
                    }

                    StyledText {
                        Layout.preferredWidth: 30
                        text: Weather.fmtTemp(row.modelData.max)
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                }

                GridLayout {
                    id: details
                    x: Tokens.space.m
                    y: 44
                    width: parent.width - Tokens.space.m * 2
                    columns: 2
                    rowSpacing: Tokens.space.xs
                    columnSpacing: Tokens.space.m
                    opacity: row.open ? 1 : 0
                    Behavior on opacity { Anim { duration: Motion.duration.short } }

                    component Detail: RowLayout {
                        property string icon
                        property string label
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: Tokens.space.s
                        Icon { text: parent.icon; size: 16; color: Theme.primary }
                        StyledText { Layout.fillWidth: true; text: parent.label; font.pixelSize: Tokens.font.s; color: Theme.surfaceVariantFg }
                    }

                    Detail { Layout.columnSpan: 2; icon: "info"; label: row.modelData.description }
                    Detail { icon: "water_drop"; label: `${Weather.fmt(row.modelData.precipSum, Weather.unit === "F" ? 2 : 1)} ${Weather.precipUnit} · ${Math.round(row.modelData.precipProb)}%` }
                    Detail { icon: "air"; label: `${Weather.fmt(row.modelData.windMax)} ${Weather.speedUnit}` }
                    Detail { icon: "wb_sunny"; label: `UV ${Weather.fmt(row.modelData.uvMax, 1)} · ${Weather.uvLevel(row.modelData.uvMax).name}` }
                    Detail { icon: "wb_twilight"; label: `${Weather.formatTime(row.modelData.sunrise)} – ${Weather.formatTime(row.modelData.sunset)}` }
                }
            }
        }
    }
}
