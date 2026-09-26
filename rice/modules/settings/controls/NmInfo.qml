import QtQuick
import Quickshell

// Read-only NetworkManager details via `nmcli -t` (terse, colon separated) plus the few
// profile-level actions Quickshell.Networking does not cover. All writes go through Exec.
Item {
    id: root

    property string iface: ""                 // device to describe
    property bool available: true             // nmcli present and NM answering
    property bool loadingProfiles: false
    property bool loadingDetails: false
    property var profiles: []                 // [{ name, uuid, type, kind, lastUsed, autoconnect, device }]
    property var devices: []                  // [{ device, type, state, connection }]
    property var details: ({})                // { mac, connection, ipv4:[], gateway, dns:[], ipv6:[], gateway6 }
    property var wifi: null                   // active AP { ssid, chan, freq, rate, signal, security }
    property string error: ""

    // Split one terse line on unescaped ':' and unescape "\:" / "\\".
    function fields(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) { cur += line[++i]; continue; }
            if (c === ":") { out.push(cur); cur = ""; continue; }
            cur += c;
        }
        out.push(cur);
        return out;
    }

    function kindOf(type) {
        if (type.includes("wireless")) return "wifi";
        if (type.includes("ethernet")) return "wired";
        if (type === "vpn" || type === "wireguard") return "vpn";
        if (type === "loopback") return "loopback";
        if (type === "bridge" || type === "bond") return "virtual";
        return type;
    }

    function refresh() {
        loadingProfiles = true;
        profilesQ.start(["nmcli", "-t", "-f", "NAME,UUID,TYPE,TIMESTAMP,AUTOCONNECT,DEVICE", "connection", "show"]);
        devicesQ.start(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]);
        refreshDetails();
    }

    function refreshDetails() {
        if (!iface) {
            details = ({});
            wifi = null;
            return;
        }
        loadingDetails = true;
        detailsQ.start(["nmcli", "-t", "-f", "GENERAL.HWADDR,GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY", "device", "show", iface]);
        apQ.start(["nmcli", "-t", "-f", "IN-USE,SSID,CHAN,FREQ,RATE,SIGNAL,SECURITY", "device", "wifi", "list", "ifname", iface, "--rescan", "no"]);
    }

    // ---- actions (never executed in dry-run) ----
    function forget(uuid) { Exec.run(["nmcli", "connection", "delete", "uuid", uuid]); settle.restart(); }
    function activate(uuid) { Exec.run(["nmcli", "connection", "up", "uuid", uuid]); settle.restart(); }
    function setAutoconnect(uuid, on) {
        Exec.run(["nmcli", "connection", "modify", "uuid", uuid, "connection.autoconnect", on ? "yes" : "no"]);
        settle.restart();
    }
    function joinHidden(ssid, password) {
        const argv = ["nmcli", "device", "wifi", "connect", ssid];
        if (password !== "") argv.push("password", password);
        argv.push("hidden", "yes");
        if (iface) argv.push("ifname", iface);
        Exec.run(argv);
        settle.restart();
    }

    onIfaceChanged: refreshDetails()
    Component.onCompleted: refresh()

    // Re-read a moment after an action so NM has applied it.
    Timer { id: settle; interval: 1500; onTriggered: root.refresh() }
    // Keep addresses fresh while the page is open (DHCP renewals, roaming).
    Timer { interval: 15000; running: root.visible; repeat: true; onTriggered: root.refreshDetails() }

    Query {
        id: profilesQ
        onFinished: (out, code) => {
            root.loadingProfiles = false;
            if (code !== 0) {
                root.available = false;
                root.error = out.trim() || "NetworkManager is not available";
                root.profiles = [];
                return;
            }
            root.available = true;
            root.error = "";
            root.profiles = out.split("\n").filter(l => l).map(l => {
                const f = root.fields(l);
                return { name: f[0], uuid: f[1], type: f[2], kind: root.kindOf(f[2]),
                         lastUsed: Number(f[3]) || 0, autoconnect: f[4] === "yes", device: f[5] || "" };
            }).filter(p => p.kind !== "loopback")
              .sort((a, b) => (b.device !== "") - (a.device !== "") || b.lastUsed - a.lastUsed);
        }
    }

    Query {
        id: devicesQ
        onFinished: (out, code) => {
            if (code !== 0) return;
            root.devices = out.split("\n").filter(l => l).map(l => {
                const f = root.fields(l);
                return { device: f[0], type: f[1], state: f[2], connection: f[3] || "" };
            }).filter(d => d.type !== "loopback" && !d.type.startsWith("wifi-p2p"));
        }
    }

    Query {
        id: detailsQ
        onFinished: (out, code) => {
            root.loadingDetails = false;
            if (code !== 0) { root.details = ({}); return; }
            const d = { mac: "", connection: "", ipv4: [], gateway: "", dns: [], ipv6: [], gateway6: "" };
            for (const line of out.split("\n")) {
                const i = line.indexOf(":");
                if (i < 0) continue;
                const key = line.slice(0, i).replace(/\[\d+\]$/, "");
                const val = line.slice(i + 1).trim();
                if (!val || val === "--") continue;
                if (key === "GENERAL.HWADDR") d.mac = val;
                else if (key === "GENERAL.CONNECTION") d.connection = val;
                else if (key === "IP4.ADDRESS") d.ipv4.push(val);
                else if (key === "IP4.GATEWAY") d.gateway = val;
                else if (key === "IP4.DNS") d.dns.push(val);
                else if (key === "IP6.ADDRESS" && !val.startsWith("fe80")) d.ipv6.push(val);
                else if (key === "IP6.GATEWAY") d.gateway6 = val;
            }
            root.details = d;
        }
    }

    Query {
        id: apQ
        onFinished: (out, code) => {
            if (code !== 0) { root.wifi = null; return; }
            const line = out.split("\n").find(l => l.startsWith("*"));
            if (!line) { root.wifi = null; return; }
            const f = root.fields(line);
            root.wifi = { ssid: f[1], chan: f[2], freq: f[3], rate: f[4], signal: Number(f[5]) || 0, security: f[6] || "Open" };
        }
    }
}
