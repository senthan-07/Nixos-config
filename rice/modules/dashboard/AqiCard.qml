import QtQuick
import qs.config
import qs.services

GaugeCard {
    readonly property var a: Weather.air
    readonly property var level: Weather.aqiLevel(Weather.aqi)

    title: "Air quality"
    icon: "aq"
    accent: level.color
    fraction: Weather.valid(Weather.aqi) ? Weather.aqi / 300 : 0
    valueText: Weather.valid(Weather.aqi) ? String(Math.round(Weather.aqi)) : "--"
    unitText: "US AQI"
    levelText: level.name
    caption: a && Weather.valid(a.pm25) ? `PM2.5 ${Weather.fmt(a.pm25, 1)} µg/m³` : ""
}
