import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.config
import qs.components

// Sidebar sub-page: pick a power profile (power-profiles-daemon sets the
// CPU governor and the laptop's platform/firmware profile together).
ColumnLayout {
    id: root

    signal back()

    readonly property var profiles: [
        { value: PowerProfile.PowerSaver, icon: "eco", name: "Power saver", desc: "Longer battery, quieter fans, lower clocks" },
        { value: PowerProfile.Balanced, icon: "balance", name: "Balanced", desc: "Everyday use" },
        { value: PowerProfile.Performance, icon: "bolt", name: "Performance", desc: "Maximum CPU and fan headroom" }
    ].filter(p => p.value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

    spacing: Tokens.space.s

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.space.s
        spacing: Tokens.space.s
        IconButton { icon: "arrow_back"; onClicked: root.back() }
        StyledText {
            Layout.fillWidth: true
            text: "Performance"
            font.pixelSize: Tokens.font.xl
            font.weight: Font.DemiBold
        }
    }

    Repeater {
        model: root.profiles

        Surface {
            id: opt
            required property var modelData
            readonly property bool current: PowerProfiles.profile === modelData.value

            Layout.fillWidth: true
            implicitHeight: 64
            radius: Tokens.radius.l
            interactive: true
            base: current ? Theme.primaryContainer : Theme.surfaceContainer
            content: current ? Theme.primaryContainerFg : Theme.surfaceFg
            onClicked: PowerProfiles.profile = modelData.value

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.space.l
                anchors.rightMargin: Tokens.space.l
                spacing: Tokens.space.m

                Icon { text: opt.modelData.icon; size: 24; fill: opt.current ? 1 : 0; color: opt.content }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText { Layout.fillWidth: true; text: opt.modelData.name; font.weight: Font.Medium; color: opt.content }
                    StyledText {
                        Layout.fillWidth: true
                        text: opt.modelData.desc
                        font.pixelSize: Tokens.font.s
                        color: Theme.alpha(opt.content, 0.75)
                    }
                }
                Icon { visible: opt.current; text: "check_circle"; size: 22; fill: 1; color: opt.content }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.space.s
        visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
        text: "Performance is currently limited by the system (heat or lap detection)."
        wrapMode: Text.Wrap
        font.pixelSize: Tokens.font.s
        color: Theme.error
    }
}
