import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.settings
import "../widgets"
import qs.components
import qs.services
// qs.config last: its `Settings` singleton must win over modules/settings/Settings.qml.
import qs.config

SettingsPage {
    id: page

    title: "About"
    subtitle: "This computer and the software running the shell."

    property var info: ({})
    property bool loaded: false
    property real uptimeSec: 0
    property var mem: ({ total: 0, available: 0 })

    function v(k, fallback) { return info[k] !== undefined && info[k] !== "" ? info[k] : (fallback ?? "Unknown"); }

    function fmtUptime(s) {
        if (!s) return "…";
        const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
        const parts = [];
        if (d) parts.push(d + (d === 1 ? " day" : " days"));
        if (h) parts.push(h + (h === 1 ? " hour" : " hours"));
        if (!d && (m || !parts.length)) parts.push(m + (m === 1 ? " minute" : " minutes"));
        return parts.join(", ");
    }

    function fmtKib(kib) {
        const g = kib / 1048576;
        return g >= 10 ? Math.round(g) + " GB" : g.toFixed(1) + " GB";
    }

    readonly property string displayName: v("fullname", "") || v("user", "")
    readonly property string screensText: Quickshell.screens.map(s =>
        `${s.name} ${Math.round(s.width * s.devicePixelRatio)}×${Math.round(s.height * s.devicePixelRatio)}`
        + (s.devicePixelRatio !== 1 ? ` @${Math.round(s.devicePixelRatio * 100) / 100}x` : "")).join(" · ")

    function summaryText() {
        return [
            "OS: " + v("os"),
            "Kernel: " + v("kernel") + " (" + v("arch") + ")",
            "Desktop: " + v("desktop"),
            "CPU: " + v("cpu") + " (" + v("threads") + " threads)",
            "GPU: " + v("gpu").split("\n").join("; "),
            "Memory: " + (mem.total ? fmtKib(mem.total) : "?"),
            "Displays: " + screensText,
            "Quickshell: " + v("quickshell"),
            "Shell: rice (" + Quickshell.shellDir + ")"
        ].join("\n");
    }

    Component.onCompleted: {
        probe.running = true;
        live.running = true;
    }

    // ---- Hero ----------------------------------------------------------------------
    ClippingRectangle {
        Layout.fillWidth: true
        implicitHeight: 168
        radius: Tokens.radius.xl
        color: Theme.primaryContainer

        // Decorative blobs.
        Rectangle {
            x: parent.width - 180; y: -60
            width: 240; height: 240; radius: 120
            color: Theme.alpha(Theme.primary, 0.12)
        }
        Rectangle {
            x: parent.width - 300; y: 90
            width: 140; height: 140; radius: 40
            rotation: 20
            color: Theme.alpha(Theme.tertiary, 0.12)
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.space.xl
            spacing: Tokens.space.xl

            Item {
                implicitWidth: 104
                implicitHeight: 104

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 52
                    color: Theme.primary

                    StyledText {
                        anchors.centerIn: parent
                        visible: avatar.status !== Image.Ready
                        text: (page.displayName || "?").charAt(0).toUpperCase()
                        color: Theme.primaryFg
                        font.pixelSize: 48
                        font.weight: Font.Bold
                    }
                    Image {
                        id: avatar
                        anchors.fill: parent
                        source: Avatar.source
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 208
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { Anim {} }
                    }
                }

                // Edit badge: opens the profile picture picker.
                Surface {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 34; height: 34; radius: 17
                    interactive: true
                    base: Theme.primary
                    content: Theme.primaryFg
                    border.width: 3
                    border.color: Theme.primaryContainer
                    onClicked: Avatar.pick()
                    Icon { anchors.centerIn: parent; text: "edit"; size: 16; fill: 1; color: Theme.primaryFg }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.xs

                StyledText {
                    Layout.fillWidth: true
                    text: page.loaded ? page.displayName : "…"
                    color: Theme.primaryContainerFg
                    font.pixelSize: Tokens.font.xxl + 4
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: page.loaded ? page.v("user") + "@" + page.v("hostname") : ""
                    color: Theme.primaryContainerFg
                    opacity: 0.8
                    font.family: Tokens.font.mono
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.space.s
                    spacing: Tokens.space.s

                    Repeater {
                        model: [
                            { icon: "ac_unit", text: page.v("osShort", "") },
                            { icon: "schedule", text: page.uptimeSec ? "Up " + page.fmtUptime(page.uptimeSec) : "" },
                            { icon: "desktop_windows", text: page.v("desktop", "") }
                        ].filter(c => c.text)

                        Chip {
                            required property var modelData
                            implicitHeight: 28
                            base: Theme.alpha(Theme.surface, 0.5)
                            Icon { text: modelData.icon; size: 16; color: Theme.primaryContainerFg }
                            StyledText {
                                text: modelData.text
                                color: Theme.primaryContainerFg
                                font.pixelSize: Tokens.font.s
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }

    EmptyState {
        visible: !page.loaded
        busy: true
        icon: "info"
        title: "Gathering system information…"
    }

    // ---- System ------------------------------------------------------------------------
    component InfoRow: SettingsRow {
        id: infoRow
        property string value
        property bool copyable: true
        interactive: copyable && value !== ""
        base: Theme.surfaceContainer
        onClicked: {
            Quickshell.clipboardText = value;
            copiedTimer.restart();
        }
        StyledText {
            Layout.maximumWidth: Math.max(160, infoRow.width * 0.55)
            horizontalAlignment: Text.AlignRight
            text: copiedTimer.running ? "Copied" : infoRow.value
            color: copiedTimer.running ? Theme.primary : Theme.surfaceVariantFg
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            font.features: { "tnum": 1 }
            Timer { id: copiedTimer; interval: 1100 }
        }
    }

    SettingsSection {
        visible: page.loaded
        title: "System"

        InfoRow { icon: "ac_unit"; label: "Operating system"; value: page.v("os"); description: page.v("osBuild", "") }
        InfoRow { icon: "memory_alt"; label: "Kernel"; value: page.v("kernel") + " · " + page.v("arch") }
        InfoRow { icon: "desktop_windows"; label: "Desktop"; value: page.v("desktop") }
        InfoRow { icon: "monitor"; label: "Displays"; value: page.screensText || "None detected" }
        InfoRow { icon: "schedule"; label: "Uptime"; value: page.fmtUptime(page.uptimeSec); copyable: false }
    }

    // ---- Hardware ----------------------------------------------------------------------
    SettingsSection {
        visible: page.loaded
        title: "Hardware"

        InfoRow { icon: "developer_board"; label: "Processor"; value: page.v("cpu"); description: page.v("threads", "?") + " threads" }
        InfoRow {
            icon: "videogame_asset"
            label: page.v("gpu", "").split("\n").length > 1 ? "Graphics (" + page.v("gpu").split("\n").length + ")" : "Graphics"
            value: page.v("gpu")
        }

        // Memory with a usage meter.
        SettingsRow {
            icon: "memory"
            label: "Memory"
            description: page.mem.total
                ? page.fmtKib(page.mem.total - page.mem.available) + " used of " + page.fmtKib(page.mem.total)
                : "…"
            Rectangle {
                implicitWidth: 200
                implicitHeight: 8
                radius: 4
                color: Theme.surfaceHighest
                Rectangle {
                    width: page.mem.total ? parent.width * (1 - page.mem.available / page.mem.total) : 0
                    height: parent.height
                    radius: 4
                    color: Theme.primary
                    Behavior on width { Anim {} }
                }
            }
        }

        SettingsRow {
            icon: "hard_drive"
            label: "Storage (/)"
            description: page.v("diskUsed", "") ? page.v("diskUsed") + " used of " + page.v("diskSize") : "Unknown"
            Rectangle {
                implicitWidth: 200
                implicitHeight: 8
                radius: 4
                color: Theme.surfaceHighest
                Rectangle {
                    width: parent.width * (parseInt(page.v("diskPct", "0")) / 100)
                    height: parent.height
                    radius: 4
                    color: parseInt(page.v("diskPct", "0")) > 90 ? Theme.error : Theme.primary
                    Behavior on width { Anim {} }
                }
            }
        }
    }

    // ---- Shell ----------------------------------------------------------------------------
    SettingsSection {
        visible: page.loaded
        title: "Shell"

        InfoRow { icon: "nest_eco_leaf"; label: "rice"; value: Quickshell.shellDir.replace(Paths.home, "~"); description: "Material 3 shell for Hyprland" }
        InfoRow { icon: "code"; label: "Quickshell"; value: page.v("quickshell") }
        InfoRow { icon: "palette"; label: "matugen"; value: page.v("matugen", "Not installed") }
    }

    // ---- Links ----------------------------------------------------------------------------
    SettingsSection {
        title: "Links"

        Flow {
            Layout.fillWidth: true
            Layout.margins: Tokens.space.s
            spacing: Tokens.space.s

            Repeater {
                model: [
                    { icon: "menu_book", text: "Quickshell docs", url: "https://quickshell.org/docs/" },
                    { icon: "water_drop", text: "Hyprland wiki", url: "https://wiki.hypr.land/" },
                    { icon: "ac_unit", text: "NixOS search", url: "https://search.nixos.org/" },
                    { icon: "palette", text: "Material 3", url: "https://m3.material.io/" },
                    { icon: "format_paint", text: "matugen", url: "https://github.com/InioX/matugen" },
                    { icon: "folder_open", text: "Open rice folder", url: "file://" + Quickshell.shellDir }
                ]
                ActionButton {
                    required property var modelData
                    style: "tonal"
                    icon: modelData.icon
                    text: modelData.text
                    onClicked: Qt.openUrlExternally(modelData.url)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: page.loaded
        Item { Layout.fillWidth: true }
        ActionButton {
            id: copyAll
            style: "outlined"
            icon: copyAllTimer.running ? "check" : "content_copy"
            text: copyAllTimer.running ? "Copied" : "Copy system info"
            onClicked: {
                Quickshell.clipboardText = page.summaryText();
                copyAllTimer.restart();
            }
            Timer { id: copyAllTimer; interval: 1500 }
        }
    }

    // ---- probes ----------------------------------------------------------------------------
    // One-shot facts, printed as key=value lines (multi-line values joined with \n escapes).
    Process {
        id: probe
        command: ["sh", "-c", `
            kv() { printf '%s=%s\\n' "$1" "$(printf '%s' "$2" | sed ':a;N;$!ba;s/\\n/\\\\n/g')"; }
            u=$(id -un); kv user "$u"
            kv fullname "$(getent passwd "$u" 2>/dev/null | cut -d: -f5 | cut -d, -f1)"
            for f in "$HOME/.face" "$HOME/.face.icon" "/var/lib/AccountsService/icons/$u"; do
                [ -s "$f" ] && { kv avatar "$f"; break; }
            done
            kv hostname "$(cat /proc/sys/kernel/hostname 2>/dev/null || hostname)"
            if [ -r /etc/os-release ]; then
                . /etc/os-release
                kv os "\${PRETTY_NAME:-$NAME}"
                kv osShort "\${NAME:-Linux} \${VERSION_ID}"
                [ -n "$BUILD_ID" ] && kv osBuild "Build $BUILD_ID"
            fi
            kv kernel "$(uname -r)"; kv arch "$(uname -m)"
            kv cpu "$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -1)"
            kv threads "$(nproc 2>/dev/null)"
            if command -v lspci >/dev/null 2>&1; then
                kv gpu "$(lspci -mm 2>/dev/null | grep -Ei '"(VGA|3D|Display)' | awk -F'" "' '{ v=$2; d=$3; sub(/ Corporation| Inc\\.?|, Inc\\.?/, "", v); sub(/".*/, "", d); print v " " d }')"
            else
                g=""
                for c in /sys/class/drm/card[0-9]; do
                    [ -r "$c/device/uevent" ] || continue
                    drv=$(sed -n 's/^DRIVER=//p' "$c/device/uevent"); id=$(sed -n 's/^PCI_ID=//p' "$c/device/uevent")
                    case "\${id%%:*}" in 10DE) ven=NVIDIA;; 1002) ven=AMD;; 8086) ven=Intel;; *) ven="GPU";; esac
                    g="$g\${g:+
}$ven ($drv, $id)"
                done
                kv gpu "$g"
            fi
            set -- $(df -h / 2>/dev/null | awk 'NR==2 { print $2, $3, $5 }')
            kv diskSize "$1"; kv diskUsed "$2"; kv diskPct "\${3%\\%}"
            d="\${XDG_CURRENT_DESKTOP:-\${XDG_SESSION_DESKTOP:-}}"
            if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null 2>&1; then
                hv=$(hyprctl version 2>/dev/null | sed -n 's/^Hyprland \\([0-9.]*\\).*/\\1/p' | head -1)
                d="Hyprland\${hv:+ $hv}"
            fi
            kv desktop "\${d:-Wayland}"
            qv=$(quickshell --version 2>/dev/null || qs --version 2>/dev/null)
            [ -z "$qv" ] && qv=$(readlink "/proc/$PPID/exe" 2>/dev/null | sed -n 's|.*-quickshell-\\([0-9][^/]*\\)/.*|quickshell \\1|p')
            kv quickshell "$(printf '%s' "$qv" | head -1)"
            kv matugen "$(matugen --version 2>/dev/null | head -1)"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0) out[line.slice(0, i)] = line.slice(i + 1).replace(/\\n/g, "\n").trim();
                }
                page.info = out;
                page.loaded = true;
            }
        }
    }

    // Changing facts: uptime and memory, refreshed every 30 s while the page is open.
    Process {
        id: live
        command: ["sh", "-c", "cut -d' ' -f1 /proc/uptime; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                page.uptimeSec = parseFloat(lines[0]) || 0;
                const m = {};
                for (const l of lines.slice(1)) {
                    const x = l.match(/^(\w+):\s+(\d+)/);
                    if (x) m[x[1]] = parseInt(x[2]);
                }
                page.mem = { total: m.MemTotal || 0, available: m.MemAvailable || 0 };
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: live.running = true
    }
}
