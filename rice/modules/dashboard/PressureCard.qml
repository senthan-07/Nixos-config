import QtQuick
import qs.config
import qs.services

// Sea-level pressure on a 960–1060 hPa dial.
GaugeCard {
    readonly property var c: Weather.current
    readonly property real hpa: c && Weather.valid(c.pressure) ? c.pressure : NaN

    title: "Pressure"
    icon: "compress"
    accent: Theme.tertiary
    fraction: Weather.valid(hpa) ? (hpa - 960) / 100 : 0
    valueText: Weather.valid(hpa) ? String(Math.round(hpa)) : "--"
    unitText: "hPa"
    levelText: !Weather.valid(hpa) ? "" : hpa < 1000 ? "Low" : hpa > 1025 ? "High" : "Normal"
    caption: !Weather.valid(hpa) ? "" : hpa < 1000 ? "Unsettled weather likely" : hpa > 1025 ? "Settled, dry weather" : "Typical conditions"
}
