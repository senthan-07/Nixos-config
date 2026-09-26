import QtQuick
import qs.config
import qs.services

GaugeCard {
    readonly property var c: Weather.current
    readonly property real uv: c && Weather.valid(c.uv) ? c.uv : NaN
    readonly property var level: Weather.uvLevel(uv)
    readonly property var today: Weather.daily.length ? Weather.daily[0] : null

    title: "UV index"
    icon: "wb_sunny"
    accent: level.color
    fraction: Weather.valid(uv) ? uv / 12 : 0
    valueText: Weather.fmt(uv, 1)
    levelText: level.name
    caption: today ? "Peak today " + Weather.fmt(today.uvMax, 1) : ""
}
