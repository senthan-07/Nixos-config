import QtQuick
import qs.config
import qs.components
import qs.services

// Bar chip: current conditions icon and temperature. Click toggles the
// dashboard on its weather tab; right click refreshes.
Chip {
    id: root

    readonly property var c: Weather.current

    interactive: true
    spacing: Tokens.space.xs
    base: DashboardState.open ? Theme.secondaryContainer : Theme.surfaceContainer
    onClicked: m => {
        if (m.button === Qt.RightButton) {
            Weather.refresh();
        } else if (DashboardState.open && DashboardState.view !== "weather") {
            DashboardState.setView("weather");
        } else {
            DashboardState.setView("weather");
            DashboardState.toggle();
        }
    }

    Icon {
        text: root.c ? root.c.icon : Weather.loading ? "cloud_sync" : "cloud_off"
        size: 18
        fill: 1
        color: root.c ? Theme.primary : Theme.surfaceVariantFg
        opacity: Weather.loading && !root.c ? 0.6 : 1
    }
    StyledText {
        text: root.c ? Weather.fmtTemp(root.c.temp) : "--°"
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
}
