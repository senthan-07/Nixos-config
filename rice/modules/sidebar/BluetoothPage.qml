import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.components
import qs.services

ColumnLayout {
    id: root

    signal back()
    readonly property var adapter: Bluetooth.defaultAdapter
    // Connected first, then paired (saved) devices, then newly discovered ones.
    function group(d) { return d.connected ? 0 : d.paired ? 1 : 2; }
    readonly property var groupNames: ["Connected", "Paired devices", "New devices"]
    readonly property var devices: adapter ? [...adapter.devices.values]
        .filter(d => d.paired || d.name)
        .sort((a, b) => (group(a) - group(b)) || (a.name || "").localeCompare(b.name || "")) : []

    spacing: Tokens.space.s
    onVisibleChanged: if (adapter?.enabled) adapter.discovering = visible

    SubpageHeader {
        title: "Bluetooth"
        checked: root.adapter?.enabled ?? false
        onBack: root.back()
        onToggle: BluetoothPower.toggle()
    }

    Repeater {
        model: root.adapter?.enabled ? root.devices : []

        ColumnLayout {
            id: slot
            required property var modelData
            required property int index
            readonly property int section: root.group(modelData)
            Layout.fillWidth: true
            spacing: Tokens.space.xs

            SectionLabel {
                visible: slot.index === 0 || root.group(root.devices[slot.index - 1]) !== slot.section
                text: root.groupNames[slot.section]
            }

        Surface {
            id: dev
            readonly property var modelData: slot.modelData
            readonly property bool busy: modelData.pairing
                || modelData.state === BluetoothDeviceState.Connecting
                || modelData.state === BluetoothDeviceState.Disconnecting

            Layout.fillWidth: true
            implicitHeight: 56
            radius: Tokens.radius.l
            interactive: true
            base: modelData.connected ? Theme.primaryContainer : Theme.surfaceContainer
            content: modelData.connected ? Theme.primaryContainerFg : Theme.surfaceFg
            onClicked: {
                if (modelData.connected) modelData.disconnect();
                else if (modelData.paired) modelData.connect();
                else modelData.pair();
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.space.l
                anchors.rightMargin: Tokens.space.l
                spacing: Tokens.space.m

                Icon {
                    readonly property string kind: dev.modelData.icon || ""
                    text: kind.includes("audio") || kind.includes("head") ? "headphones"
                        : kind.includes("phone") ? "smartphone"
                        : kind.includes("mouse") ? "mouse"
                        : kind.includes("keyboard") ? "keyboard"
                        : kind.includes("game") ? "sports_esports" : "bluetooth"
                    fill: dev.modelData.connected ? 1 : 0
                    color: dev.content
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: dev.modelData.name || dev.modelData.address
                        font.weight: Font.Medium
                        color: dev.content
                    }
                    StyledText {
                        text: dev.busy ? "Working…"
                            : dev.modelData.connected
                                ? (dev.modelData.batteryAvailable ? `Connected · ${Math.round(dev.modelData.battery * 100)}%` : "Connected")
                                : dev.modelData.paired ? "Paired" : "Tap to pair"
                        font.pixelSize: Tokens.font.s
                        color: Theme.surfaceVariantFg
                    }
                }
                IconButton {
                    visible: dev.modelData.paired
                    size: 30
                    icon: "delete"
                    onClicked: dev.modelData.forget()
                }
            }
        }
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.margins: Tokens.space.xl
        visible: !root.adapter?.enabled || root.devices.length === 0
        text: !root.adapter ? "No Bluetooth adapter" : root.adapter.enabled ? "Searching…" : "Bluetooth is off"
        color: Theme.outline
    }
}
