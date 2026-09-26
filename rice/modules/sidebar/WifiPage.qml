import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.config
import qs.components
import qs.services

ColumnLayout {
    id: root

    signal back()
    property var pending: null   // network awaiting a password

    // Connected first, then saved networks, then everything else in range.
    function group(n) { return n.connected ? 0 : n.known ? 1 : 2; }
    readonly property var groupNames: ["Connected", "Saved networks", "Available"]
    readonly property var list: Net.wifiEnabled
        ? [...Net.networks].sort((a, b) => (group(a) - group(b)) || (b.signalStrength - a.signalStrength))
        : []

    spacing: Tokens.space.s
    onVisibleChanged: { Net.setScanning(visible); pending = null; }

    SubpageHeader {
        title: "Wi-Fi"
        checked: Net.wifiEnabled
        onBack: root.back()
        onToggle: Net.toggleWifi()
    }

    Repeater {
        model: root.list

        ColumnLayout {
            id: entry
            required property var modelData
            required property int index
            readonly property bool secured: modelData.security !== WifiSecurityType.Open
            readonly property int section: root.group(modelData)
            Layout.fillWidth: true
            spacing: Tokens.space.xs

            SectionLabel {
                visible: entry.index === 0 || root.group(root.list[entry.index - 1]) !== entry.section
                text: root.groupNames[entry.section]
            }

            Surface {
                Layout.fillWidth: true
                implicitHeight: 56
                radius: Tokens.radius.l
                interactive: true
                base: entry.modelData.connected ? Theme.primaryContainer : Theme.surfaceContainer
                content: entry.modelData.connected ? Theme.primaryContainerFg : Theme.surfaceFg
                onClicked: {
                    const n = entry.modelData;
                    if (n.connected) n.disconnect();
                    else if (n.known || !entry.secured) n.connect();
                    else root.pending = root.pending === n ? null : n;
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space.l
                    anchors.rightMargin: Tokens.space.l
                    spacing: Tokens.space.m

                    Icon {
                        readonly property real s: entry.modelData.signalStrength
                        text: s > 0.75 ? "network_wifi" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                        fill: 1
                        color: parent.parent.content
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: entry.modelData.name
                            font.weight: Font.Medium
                            color: parent.parent.parent.content
                        }
                        StyledText {
                            text: entry.modelData.stateChanging ? "Working…"
                                : entry.modelData.connected ? "Connected" : entry.modelData.known ? "Saved" : ""
                            visible: text !== ""
                            font.pixelSize: Tokens.font.s
                            color: Theme.surfaceVariantFg
                        }
                    }
                    Icon { visible: entry.secured; text: "lock"; size: 16; color: Theme.surfaceVariantFg }
                    IconButton {
                        visible: entry.modelData.known
                        size: 30
                        icon: "delete"
                        onClicked: entry.modelData.forget()
                    }
                }
            }

            // Inline password prompt for new secured networks.
            Rectangle {
                Layout.fillWidth: true
                visible: root.pending === entry.modelData
                implicitHeight: 48
                radius: height / 2
                color: Theme.surfaceHighest

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space.l
                    anchors.rightMargin: Tokens.space.xs
                    TextInput {
                        id: psk
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        color: Theme.surfaceFg
                        font.pixelSize: Tokens.font.m
                        focus: parent.parent.visible
                        onAccepted: connectBtn.clicked(null)
                        StyledText {
                            anchors.fill: parent
                            visible: !parent.text
                            text: "Password"
                            color: Theme.surfaceVariantFg
                        }
                    }
                    IconButton {
                        id: connectBtn
                        icon: "arrow_forward"
                        toggled: true
                        onClicked: {
                            entry.modelData.connectWithPsk(psk.text);
                            psk.text = "";
                            root.pending = null;
                        }
                    }
                }
            }
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.margins: Tokens.space.xl
        visible: !Net.wifiEnabled || Net.networks.length === 0
        text: Net.wifiEnabled ? "Scanning…" : "Wi-Fi is off"
        color: Theme.outline
    }
}
