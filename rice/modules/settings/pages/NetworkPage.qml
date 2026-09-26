import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.modules.settings
import "../controls"
import qs.components
import qs.services
import qs.config

// Network: Wi-Fi radio + nearby networks, wired status, saved profiles, hidden
// networks and live connection details (nmcli, read-only).
SettingsPage {
    id: root

    property string view: "main"          // main | saved | hidden
    property var pending: null            // secured network awaiting a password
    property var selected: null           // expanded nearby/active network row
    property string failure: ""
    property bool scanSettled: false

    readonly property bool nmAvailable: Networking.backend !== NetworkBackendType.None && nm.available
    readonly property var wifiDev: Net.wifiDevice
    readonly property var wiredDev: Net.wiredDevice
    readonly property var nearby: Net.networks.filter(n => !n.connected && n.name !== "")
    readonly property var activeWifi: Net.active
    readonly property string iface: Net.wired && wiredDev ? wiredDev.name : wifiDev && activeWifi ? wifiDev.name : ""

    function strengthIcon(s) {
        return s > 0.75 ? "network_wifi" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }
    function secured(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe; }
    function securityName(n) {
        switch (n.security) {
        case WifiSecurityType.Open: return "Open";
        case WifiSecurityType.Owe: return "Enhanced open";
        case WifiSecurityType.Sae: return "WPA3";
        case WifiSecurityType.Wpa3SuiteB192: return "WPA3 Enterprise";
        case WifiSecurityType.Wpa2Psk: return "WPA2";
        case WifiSecurityType.WpaPsk: return "WPA";
        case WifiSecurityType.Wpa2Eap: case WifiSecurityType.WpaEap: return "Enterprise";
        case WifiSecurityType.StaticWep: case WifiSecurityType.DynamicWep: return "WEP";
        default: return "Secured";
        }
    }
    function connectTo(n) {
        failure = "";
        if (n.known || !secured(n)) {
            if (Exec.allow(`wifi connect ${n.name}`)) n.connect();
            pending = null;
        } else {
            pending = pending === n ? null : n;
        }
    }
    function copy(text) {
        Quickshell.clipboardText = text;
        toast.show(`Copied ${text}`);
    }
    function ago(ts) {
        if (!ts) return "Never used";
        const s = Date.now() / 1000 - ts;
        if (s < 120) return "Used just now";
        if (s < 3600) return `Used ${Math.round(s / 60)} min ago`;
        if (s < 86400) return `Used ${Math.round(s / 3600)} h ago`;
        if (s < 86400 * 30) return `Used ${Math.round(s / 86400)} days ago`;
        return `Last used ${Qt.formatDate(new Date(ts * 1000), "d MMM yyyy")}`;
    }

    title: "Network"
    subtitle: view === "main" ? "Wi-Fi, Ethernet and connection details" : ""

    Component.onCompleted: { Net.setScanning(true); settleTimer.start(); }
    onViewChanged: { contentY = 0; selected = null; pending = null; }
    Component.onDestruction: Net.setScanning(false)

    Timer { id: settleTimer; interval: 5000; onTriggered: root.scanSettled = true }

    NmInfo { id: nm; iface: root.iface }

    Connections {
        target: root.pending ?? null
        ignoreUnknownSignals: true
        function onConnectionFailed(reason) {
            root.failure = reason === ConnectionFailReason.NoSecrets ? "Wrong password or the network rejected the key"
                : reason === ConnectionFailReason.WifiAuthTimeout ? "Authentication timed out"
                : reason === ConnectionFailReason.WifiNetworkLost ? "The network went out of range"
                : "Could not connect";
        }
    }

    // =========================== main view ===========================
    FadeView {
        active: root.view === "main"
        direction: -1

        Banner {
            visible: !root.nmAvailable
            tone: "error"
            text: nm.error !== "" ? `NetworkManager unavailable: ${nm.error}` : "NetworkManager is not running — network settings are unavailable."
        }
        Banner {
            visible: root.failure !== ""
            tone: "error"
            text: root.failure
            IconButton { icon: "close"; size: 32; onClicked: root.failure = "" }
        }

        // ---- hero status card ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: hero.implicitHeight + Tokens.space.xl * 2
            radius: Tokens.radius.xl
            color: Net.wired || root.activeWifi ? Theme.primaryContainer : Theme.surfaceContainer
            Behavior on color { ColorAnim {} }

            RowLayout {
                id: hero
                anchors.fill: parent
                anchors.margins: Tokens.space.xl
                spacing: Tokens.space.xl

                Rectangle {
                    implicitWidth: 72
                    implicitHeight: 72
                    radius: 24
                    color: Net.wired || root.activeWifi ? Theme.primary : Theme.surfaceHighest
                    Icon {
                        anchors.centerIn: parent
                        text: Net.icon
                        size: 36
                        fill: 1
                        color: Net.wired || root.activeWifi ? Theme.primaryFg : Theme.surfaceVariantFg
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        Layout.fillWidth: true
                        text: Net.wired ? "Ethernet" : root.activeWifi ? root.activeWifi.name
                            : !Net.wifiEnabled ? "Wi-Fi is off" : "Not connected"
                        font.pixelSize: Tokens.font.xxl
                        font.weight: Font.DemiBold
                        color: Net.wired || root.activeWifi ? Theme.primaryContainerFg : Theme.surfaceFg
                    }
                    StyledText {
                        Layout.fillWidth: true
                        readonly property string conn: Networking.connectivity === NetworkConnectivity.Full ? "Internet access"
                            : Networking.connectivity === NetworkConnectivity.Portal ? "Sign-in required"
                            : Networking.connectivity === NetworkConnectivity.Limited ? "Limited connectivity"
                            : Networking.connectivity === NetworkConnectivity.None ? "No internet" : ""
                        text: [conn, (nm.details.ipv4 ?? [])[0]?.split("/")[0] ?? "",
                               !Net.wired && root.activeWifi ? `Signal ${Math.round(root.activeWifi.signalStrength * 100)}%` : ""]
                            .filter(s => s).join("  ·  ") || (Net.wifiEnabled ? "Choose a network below" : "Turn on Wi-Fi to see networks")
                        color: Net.wired || root.activeWifi ? Theme.alpha(Theme.primaryContainerFg, 0.8) : Theme.surfaceVariantFg
                    }
                }
            }
        }

        // ---- wired ----
        SettingsSection {
            title: "Ethernet"
            visible: root.wiredDev !== null || nm.devices.some(d => d.type === "ethernet")

            Repeater {
                model: nm.devices.filter(d => d.type === "ethernet")
                ListRow {
                    required property var modelData
                    readonly property bool up: modelData.state.startsWith("connected")
                    icon: up ? "lan" : "settings_ethernet"
                    highlighted: up
                    title: modelData.connection || `Wired (${modelData.device})`
                    subtitle: up ? `Connected · ${modelData.device}${root.wiredDev?.linkSpeed > 0 ? ` · ${root.wiredDev.linkSpeed} Mb/s` : ""}`
                        : modelData.state === "unavailable" ? "Cable unplugged" : modelData.state
                }
            }
            ListRow {
                visible: nm.devices.length === 0 && root.wiredDev !== null
                icon: Net.wired ? "lan" : "settings_ethernet"
                highlighted: Net.wired
                title: root.wiredDev?.name ?? "Ethernet"
                subtitle: Net.wired ? "Connected" : (root.wiredDev?.hasLink ? "Link up" : "Cable unplugged")
            }
        }

        // ---- wifi ----
        SettingsSection {
            title: "Wi-Fi"
            visible: root.wifiDev !== null || root.nmAvailable

            SettingsRow {
                icon: Net.wifiEnabled ? "wifi" : "wifi_off"
                label: "Wi-Fi"
                description: !root.wifiDev ? "No wireless adapter found"
                    : !Networking.wifiHardwareEnabled ? "Blocked by a hardware switch or rfkill"
                    : Net.wifiEnabled ? `Adapter ${root.wifiDev.name}` : "Off"
                SettingsSwitch {
                    checked: Net.wifiEnabled
                    visible: root.wifiDev !== null
                    onToggled: if (Networking.wifiHardwareEnabled && Exec.allow("wifi radio toggle")) Net.toggleWifi()
                }
            }

            // Current network
            ListRow {
                visible: Net.wifiEnabled && root.activeWifi !== null
                readonly property var n: root.activeWifi
                icon: root.strengthIcon(n?.signalStrength ?? 0)
                highlighted: true
                interactive: true
                chevron: true
                expanded: root.selected === n
                busy: n?.stateChanging ?? false
                title: n?.name ?? ""
                subtitle: n ? `Connected · ${root.securityName(n)} · ${Math.round(n.signalStrength * 100)}%` : ""
                onClicked: root.selected = root.selected === n ? null : n

                expansion: [
                    RowLayout {
                        spacing: Tokens.space.s
                        ActionButton {
                            text: "Disconnect"; icon: "link_off"; kind: "tonal"
                            onClicked: if (Exec.allow("wifi disconnect")) root.activeWifi.disconnect()
                        }
                        ActionButton {
                            text: "Forget"; icon: "delete"
                            onClicked: { forgetDialog.target = root.activeWifi; forgetDialog.open(); }
                        }
                        Item { Layout.fillWidth: true }
                        ActionButton {
                            text: "Details"; icon: "info"
                            onClicked: detailsSection.forceActiveFocus()
                        }
                    }
                ]
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.space.s
                Layout.leftMargin: Tokens.space.m
                visible: Net.wifiEnabled
                text: "Available networks"
                font.pixelSize: Tokens.font.s
                font.weight: Font.DemiBold
                color: Theme.surfaceVariantFg
            }

            Repeater {
                model: Net.wifiEnabled ? root.nearby : []

                ListRow {
                    id: netRow
                    required property var modelData
                    readonly property var n: modelData
                    readonly property bool asking: root.pending === n

                    icon: root.strengthIcon(n.signalStrength)
                    interactive: true
                    busy: n.stateChanging
                    expanded: asking || root.selected === n
                    title: n.name
                    subtitle: [n.stateChanging ? "Connecting…" : n.known ? "Saved" : "",
                               root.securityName(n), `${Math.round(n.signalStrength * 100)}%`].filter(s => s).join(" · ")
                    onClicked: {
                        if (n.known) root.selected = root.selected === n ? null : n;
                        else root.connectTo(n);
                    }

                    Icon { visible: root.secured(netRow.n); text: "lock"; size: 18; color: Theme.surfaceVariantFg }

                    expansion: [
                        // Password prompt for unknown secured networks
                        ColumnLayout {
                            visible: netRow.asking
                            Layout.fillWidth: true
                            spacing: Tokens.space.s
                            InputField {
                                id: psk
                                Layout.fillWidth: true
                                label: `Password for ${netRow.n.name}`
                                icon: "key"
                                password: true
                                error: text.length > 0 && text.length < 8 ? "At least 8 characters" : ""
                                onAccepted: joinBtn.clicked(null)
                                Component.onCompleted: if (netRow.asking) focusField()
                                onVisibleChanged: if (visible) focusField(); else text = ""
                            }
                            RowLayout {
                                Item { Layout.fillWidth: true }
                                ActionButton { text: "Cancel"; onClicked: root.pending = null }
                                ActionButton {
                                    id: joinBtn
                                    text: "Connect"; kind: "filled"
                                    enabled: psk.text.length >= 8
                                    onClicked: {
                                        if (!enabled) return;
                                        root.failure = "";
                                        if (Exec.allow(`wifi connect ${netRow.n.name} with password`)) netRow.n.connectWithPsk(psk.text);
                                        psk.text = "";
                                    }
                                }
                            }
                        },
                        // Actions for saved networks
                        RowLayout {
                            visible: !netRow.asking && root.selected === netRow.n
                            spacing: Tokens.space.s
                            ActionButton { text: "Connect"; icon: "link"; kind: "filled"; onClicked: root.connectTo(netRow.n) }
                            ActionButton {
                                text: "Forget"; icon: "delete"
                                onClicked: { forgetDialog.target = netRow.n; forgetDialog.open(); }
                            }
                        }
                    ]
                }
            }

            EmptyState {
                visible: Net.wifiEnabled && root.nearby.length === 0
                loading: !root.scanSettled
                icon: "wifi_find"
                title: root.scanSettled ? "No networks found" : "Searching for networks…"
                text: root.scanSettled ? "Move closer to a router or join a hidden network." : ""
            }
            EmptyState {
                visible: root.wifiDev !== null && !Net.wifiEnabled
                icon: "wifi_off"
                title: "Wi-Fi is off"
                text: "Turn it on to see nearby networks."
            }
        }

        SettingsSection {
            title: "More"
            ListRow {
                icon: "bookmarks"
                title: "Saved networks"
                subtitle: nm.loadingProfiles ? "Loading…" : `${nm.profiles.length} profile${nm.profiles.length === 1 ? "" : "s"}`
                chevron: true
                interactive: true
                onClicked: root.view = "saved"
            }
            ListRow {
                icon: "add_circle"
                title: "Join hidden network"
                subtitle: "Connect to a network that doesn't broadcast its name"
                chevron: true
                interactive: true
                enabled: root.wifiDev !== null
                opacity: enabled ? 1 : 0.5
                onClicked: root.view = "hidden"
            }
        }

        // ---- details ----
        SettingsSection {
            id: detailsSection
            title: "Connection details"
            visible: root.iface !== ""

            Repeater {
                model: {
                    const d = nm.details, w = nm.wifi, rows = [];
                    rows.push({ icon: Net.wired ? "lan" : "wifi", label: "Interface", value: root.iface });
                    if (d.connection) rows.push({ icon: "badge", label: "Profile", value: d.connection });
                    rows.push({ icon: "dns", label: "IPv4 address", value: (d.ipv4 ?? []).join(", ") });
                    rows.push({ icon: "router", label: "Gateway", value: d.gateway ?? "" });
                    rows.push({ icon: "travel_explore", label: "DNS", value: (d.dns ?? []).join(", ") });
                    if ((d.ipv6 ?? []).length) rows.push({ icon: "language", label: "IPv6 address", value: d.ipv6.join(", ") });
                    rows.push({ icon: "fingerprint", label: "Hardware address", value: d.mac ?? "" });
                    if (!Net.wired && w) {
                        rows.push({ icon: "cell_tower", label: "Frequency", value: `${w.freq} · channel ${w.chan}` });
                        rows.push({ icon: "speed", label: "Link rate", value: w.rate });
                        rows.push({ icon: "shield_lock", label: "Security", value: w.security });
                    }
                    if (Net.wired && root.wiredDev?.linkSpeed > 0)
                        rows.push({ icon: "speed", label: "Link speed", value: `${root.wiredDev.linkSpeed} Mb/s` });
                    return rows;
                }

                ListRow {
                    id: detailRow
                    required property var modelData
                    icon: modelData.icon
                    title: modelData.label
                    subtitle: modelData.value || (nm.loadingDetails ? "Loading…" : "—")
                    mono: modelData.value !== "" && modelData.label !== "Profile" && modelData.label !== "Frequency"
                    interactive: modelData.value !== ""
                    onClicked: root.copy(modelData.value)
                    IconButton {
                        visible: detailRow.hovered && detailRow.modelData.value !== ""
                        icon: "content_copy"; size: 32; iconSize: 18
                        onClicked: root.copy(detailRow.modelData.value)
                    }
                }
            }
        }
    }

    // =========================== saved networks ===========================
    FadeView {
        active: root.view === "saved"

        SubHeader { title: "Saved networks"; onBack: root.view = "main" }

        Banner {
            visible: nm.error !== ""
            tone: "error"
            text: nm.error
        }

        SettingsSection {
            title: "Profiles"
            EmptyState {
                visible: nm.profiles.length === 0
                loading: nm.loadingProfiles
                icon: "bookmarks"
                title: nm.loadingProfiles ? "Loading profiles…" : "No saved networks"
                text: nm.loadingProfiles ? "" : "Networks you join are remembered here."
            }
            Repeater {
                model: nm.profiles
                ListRow {
                    id: prof
                    required property var modelData
                    readonly property bool inUse: modelData.device !== ""
                    icon: modelData.kind === "wifi" ? "wifi" : modelData.kind === "wired" ? "lan" : modelData.kind === "vpn" ? "vpn_lock" : "hub"
                    highlighted: inUse
                    title: modelData.name
                    subtitle: inUse ? `Active on ${modelData.device}` : root.ago(modelData.lastUsed)
                    interactive: true
                    chevron: true
                    expanded: root.selected === modelData.uuid
                    onClicked: root.selected = root.selected === modelData.uuid ? null : modelData.uuid

                    expansion: [
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.space.m
                            StyledText { text: "Connect automatically"; Layout.fillWidth: true }
                            SettingsSwitch {
                                checked: prof.modelData.autoconnect
                                onToggled: nm.setAutoconnect(prof.modelData.uuid, !checked)
                            }
                        },
                        StyledText {
                            Layout.fillWidth: true
                            text: `UUID ${prof.modelData.uuid}`
                            font.family: Tokens.font.mono
                            font.pixelSize: Tokens.font.s
                            color: Theme.surfaceVariantFg
                        },
                        RowLayout {
                            spacing: Tokens.space.s
                            ActionButton {
                                visible: !prof.inUse
                                text: "Connect"; icon: "link"; kind: "tonal"
                                onClicked: nm.activate(prof.modelData.uuid)
                            }
                            ActionButton {
                                text: "Forget"; icon: "delete"
                                onClicked: { forgetDialog.target = prof.modelData; forgetDialog.open(); }
                            }
                        }
                    ]
                }
            }
        }
    }

    // =========================== hidden network ===========================
    FadeView {
        id: hiddenView
        active: root.view === "hidden"
        property int security: 1

        SubHeader { title: "Join hidden network"; onBack: root.view = "main" }

        SettingsSection {
            title: "Network"
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: Tokens.space.l
                spacing: Tokens.space.l

                InputField {
                    id: ssid
                    label: "Network name (SSID)"
                    icon: "wifi"
                    maximumLength: 32
                    error: text.length > 0 && text.trim() === "" ? "Name can't be blank" : ""
                }
                RowLayout {
                    spacing: Tokens.space.m
                    StyledText { text: "Security"; Layout.fillWidth: true; font.weight: Font.Medium }
                    Segmented {
                        options: [{ value: 0, label: "None" }, { value: 1, label: "WPA/WPA2/WPA3 Personal" }]
                        value: hiddenView.security
                        onSelected: v => hiddenView.security = v
                    }
                }
                InputField {
                    id: hiddenPsk
                    visible: hiddenView.security === 1
                    label: "Password"
                    icon: "key"
                    password: true
                    error: text.length > 0 && text.length < 8 ? "At least 8 characters" : ""
                    onAccepted: joinHidden.clicked(null)
                }
                RowLayout {
                    Item { Layout.fillWidth: true }
                    ActionButton { text: "Cancel"; onClicked: root.view = "main" }
                    ActionButton {
                        id: joinHidden
                        text: "Join"; icon: "login"; kind: "filled"
                        enabled: ssid.text.trim() !== "" && (hiddenView.security === 0 || hiddenPsk.text.length >= 8)
                        onClicked: {
                            if (!enabled) return;
                            nm.joinHidden(ssid.text.trim(), hiddenView.security === 1 ? hiddenPsk.text : "");
                            toast.show(`Joining ${ssid.text.trim()}…`);
                            ssid.text = "";
                            hiddenPsk.text = "";
                            root.view = "main";
                        }
                    }
                }
            }
        }
        Banner {
            text: "Hidden networks are slower to connect and don't hide your network from nearby devices."
        }
    }

    // ---- shared ----
    Dialog {
        id: forgetDialog
        property var target: null     // WifiNetwork or nmcli profile object
        readonly property string name: target?.name ?? ""
        icon: "delete"
        title: `Forget ${name}?`
        text: "The saved password and settings for this network will be removed. You'll need to enter the password again to reconnect."
        confirmText: "Forget"
        danger: true
        onConfirmed: {
            if (target?.uuid) nm.forget(target.uuid);
            else if (target && Exec.allow(`wifi forget ${name}`)) target.forget();
            root.selected = null;
            nm.refresh();
        }
    }

    Toast { id: toast }
}
