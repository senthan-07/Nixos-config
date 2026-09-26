import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Chip {
    spacing: Tokens.space.m

    component Meter: RowLayout {
        property alias value: ring.value
        property alias icon: glyph.text
        property color accent: Theme.primary
        spacing: Tokens.space.xs

        Item {
            implicitWidth: 22
            implicitHeight: 22
            Ring { id: ring; anchors.fill: parent; color: parent.parent.accent }
            Icon { id: glyph; anchors.centerIn: parent; size: 12; fill: 1; color: parent.parent.accent }
        }
    }

    Meter {
        icon: "memory"
        value: SysStats.cpu
        accent: SysStats.cpu > 0.85 ? Theme.error : Theme.primary
    }
    Meter {
        icon: "memory_alt"
        value: SysStats.memory
        accent: SysStats.memory > 0.85 ? Theme.error : Theme.secondary
    }
    Meter {
        icon: "device_thermostat"
        value: SysStats.temperature / 100
        accent: SysStats.temperature > 85 ? Theme.error : Theme.tertiary
    }
}
