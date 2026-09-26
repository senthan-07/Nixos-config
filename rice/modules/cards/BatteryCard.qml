import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.config
import qs.components

// Battery as a liquid tank: the card is the cell, the charge is the liquid.
Item {
    id: root

    property bool running: true
    property bool elevated: true

    readonly property UPowerDevice dev: UPower.displayDevice
    readonly property bool present: !!dev && dev.ready && dev.isLaptopBattery && dev.isPresent
    readonly property real pct: present ? Math.max(0, Math.min(1, dev.percentage)) : 0
    readonly property bool charging: present && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: present && (dev.state === UPowerDeviceState.FullyCharged || (pct >= 0.995 && !UPower.onBattery))
    readonly property bool low: present && pct <= 0.15 && UPower.onBattery

    readonly property color container: low ? Theme.errorContainer : charging ? Theme.primaryContainer : Theme.secondaryContainer
    readonly property color content: low ? Theme.errorContainerFg : charging ? Theme.primaryContainerFg : Theme.secondaryContainerFg
    readonly property color liquid: low ? Theme.error : charging ? Theme.primary : Theme.secondary
    readonly property bool compact: body.width < 150

    function duration(s) {
        if (!(s > 0)) return "";
        const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    readonly property string status: !present ? "No battery"
        : full ? "Fully charged"
        : charging ? "Charging"
        : UPower.onBattery ? "On battery" : "Plugged in"
    readonly property string timing: !present || full ? ""
        : charging ? (dev.timeToFull > 0 ? duration(dev.timeToFull) + " to full" : "")
        : UPower.onBattery ? (dev.timeToEmpty > 0 ? duration(dev.timeToEmpty) + " left" : "") : "Not charging"

    implicitWidth: 176
    implicitHeight: 272

    Accessible.role: Accessible.Indicator
    Accessible.name: present ? `Battery ${Math.round(pct * 100)} percent, ${status}` : "No battery"

    // Terminal nub.
    Rectangle {
        anchors.horizontalCenter: body.horizontalCenter
        anchors.bottom: body.top
        anchors.bottomMargin: -radius
        width: Math.max(28, body.width * 0.28)
        height: 10 + radius
        radius: 5
        color: CardStyle.mix(root.container, root.content, 0.25)
        Behavior on color { ColorAnim {} }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        anchors.topMargin: 8
        radius: Math.min(Tokens.radius.xl, width * 0.18)
        color: root.container
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

    Item {
        anchors.fill: body
        visible: root.present
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: bodyMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
        Liquid {
            anchors.fill: parent
            level: root.pct
            running: root.running
            color: CardStyle.mix(root.container, root.liquid, 0.4)
            backColor: CardStyle.mix(root.container, root.liquid, 0.2)
        }
    }

    Rectangle {
        id: bodyMask
        anchors.fill: body
        radius: body.radius
        visible: false
        layer.enabled: true
    }

    ColumnLayout {
        anchors.fill: body
        anchors.margins: root.compact ? Tokens.space.m : Tokens.space.l
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Icon {
                id: glyph
                text: !root.present ? "battery_unknown" : root.charging ? "bolt" : root.full ? "battery_full"
                    : "battery_" + Math.min(6, Math.floor(root.pct * 7)) + "_bar"
                size: root.compact ? 22 : 28
                fill: 1
                color: root.content
                SequentialAnimation on opacity {
                    running: root.charging && root.running
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) glyph.opacity = 1
                    NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Item { Layout.fillWidth: true }
            Icon {
                visible: root.present && !UPower.onBattery
                text: "power"
                size: 18
                color: Theme.alpha(root.content, 0.7)
            }
        }

        Item { Layout.fillHeight: true }

        StyledText {
            Layout.fillWidth: true
            text: root.present ? Math.round(root.pct * 100) + "%" : "—"
            color: root.content
            font.family: CardStyle.display
            font.pixelSize: Math.max(26, Math.min(body.width * 0.34, body.height * 0.2))
            font.weight: Font.Black
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 18
            elide: Text.ElideNone
            font.features: { "tnum": 1 }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.status
            color: root.content
            font.pixelSize: root.compact ? Tokens.font.s : Tokens.font.m
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.fillWidth: true
            visible: text !== "" && body.height > 150
            text: root.timing
            color: Theme.alpha(root.content, 0.75)
            font.pixelSize: Tokens.font.s
        }
    }
}
