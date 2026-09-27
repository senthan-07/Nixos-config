import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Info tab: profile header over the wallpaper, a greeting clock, live system
// gauges and a short system summary.
Item {
    id: root

    property bool active: false

    // Filled once from /etc/os-release, /proc and DMI.
    property var sys: ({})
    property string avatar: ""
    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string fullName: sys.name || user
    readonly property string greeting: {
        const h = Time.now.getHours();
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : h < 22 ? "Good evening" : "Good night";
    }

    onActiveChanged: if (active) enter.restart()

    function scrollBy(dy) {
        infoFlick.contentY = Math.max(0, Math.min(infoFlick.contentHeight - infoFlick.height, infoFlick.contentY + dy));
    }

    ParallelAnimation {
        id: enter
        NumberAnimation { target: column; property: "opacity"; from: 0; to: 1; duration: Motion.duration.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.standardDecel }
        NumberAnimation { target: column; property: "y"; from: 24; to: 0; duration: Motion.duration.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.emphasizedDecel }
    }

    Process {
        running: true
        command: ["sh", "-c", `
            . /etc/os-release 2>/dev/null
            printf 'os\\t%s\\n' "\${PRETTY_NAME:-\${NAME:-Linux}}"
            printf 'logo\\t%s\\n' "\${LOGO:-}"
            printf 'kernel\\t%s\\n' "$(cat /proc/sys/kernel/osrelease)"
            printf 'host\\t%s\\n' "$(cat /proc/sys/kernel/hostname)"
            printf 'model\\t%s\\n' "$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)"
            printf 'cpu\\t%s\\n' "$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//; s/([^)]*)//g; s/ CPU//; s/ with .*//; s/ w\\/.*//; s/ \\+/ /g')"
            printf 'cores\\t%s\\n' "$(grep -c ^processor /proc/cpuinfo)"
            printf 'name\\t%s\\n' "$(getent passwd "$USER" 2>/dev/null | cut -d: -f5 | cut -d, -f1)"
            printf 'shell\\t%s\\n' "$(basename "\${SHELL:-sh}")"
            for f in "$HOME/.face" "$HOME/.face.icon" "/var/lib/AccountsService/icons/$USER"; do
                [ -s "$f" ] && { printf 'avatar\\t%s\\n' "$f"; break; }
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("\t");
                    if (i > 0 && line.slice(i + 1).trim()) out[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                root.avatar = out.avatar || "";
                root.sys = out;
            }
        }
    }

    Flickable {
        id: infoFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            spacing: Tokens.space.m

            // ---- profile ----
            ClippingRectangle {
                Layout.fillWidth: true
                implicitHeight: 254
                radius: Tokens.radius.xl
                color: Theme.surfaceContainer

                Image {
                    id: banner
                    width: parent.width
                    height: 150
                    source: Wallpapers.current ? "file://" + Wallpapers.current : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 900
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { Anim {} }
                }
                // Fallback banner / tint when there is no wallpaper.
                Rectangle {
                    width: parent.width
                    height: 150
                    visible: banner.status !== Image.Ready
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.primaryContainer }
                        GradientStop { position: 1; color: Theme.tertiaryContainer }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 150
                    gradient: Gradient {
                        GradientStop { position: 0.4; color: "transparent" }
                        GradientStop { position: 1; color: Theme.alpha(Theme.surfaceContainer, 0.55) }
                    }
                }

                // Distro chip on the banner.
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Tokens.space.m
                    implicitWidth: distroRow.implicitWidth + Tokens.space.m * 2
                    implicitHeight: 28
                    radius: 14
                    color: Theme.alpha(Theme.surface, 0.72)
                    visible: !!root.sys.os
                    Row {
                        id: distroRow
                        anchors.centerIn: parent
                        spacing: Tokens.space.xs
                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 16
                            source: root.sys.logo ? Quickshell.iconPath(root.sys.logo, true) : ""
                            visible: source != ""
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.sys.os || ""
                            font.pixelSize: Tokens.font.s
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // Avatar overlapping the banner edge.
                Rectangle {
                    id: avatarRing
                    x: Tokens.space.l
                    y: 150 - height / 2 - 6
                    width: 92
                    height: 92
                    radius: width / 2
                    color: Theme.surfaceContainer

                    ClippingRectangle {
                        anchors.centerIn: parent
                        width: parent.width - 10
                        height: width
                        radius: width / 2
                        color: Theme.tertiaryContainer

                        StyledText {
                            anchors.centerIn: parent
                            visible: avatarImage.status !== Image.Ready
                            text: root.fullName.charAt(0).toUpperCase()
                            font.pixelSize: 36
                            font.weight: Font.Bold
                            color: Theme.tertiaryContainerFg
                        }
                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            source: Avatar.source
                            cache: false
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 180
                            asynchronous: true
                        }
                    }

                    // Edit badge: opens the profile picture picker.
                    Surface {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 30; height: 30; radius: 15
                        interactive: true
                        base: Theme.primary
                        content: Theme.primaryFg
                        border.width: 3
                        border.color: Theme.surfaceContainer
                        onClicked: Avatar.pick()
                        Icon { anchors.centerIn: parent; text: "edit"; size: 15; fill: 1; color: Theme.primaryFg }
                    }
                }

                ColumnLayout {
                    anchors.left: avatarRing.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 156
                    anchors.leftMargin: Tokens.space.m
                    anchors.rightMargin: Tokens.space.l
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: root.fullName
                        font.pixelSize: Tokens.font.xl
                        font.weight: Font.Bold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: `${root.user}@${root.sys.host || "localhost"}`
                        font.family: Tokens.font.mono
                        font.pixelSize: Tokens.font.s
                        color: Theme.surfaceVariantFg
                    }
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.space.m
                    anchors.leftMargin: Tokens.space.l
                    spacing: Tokens.space.s

                    InfoChip { icon: "schedule"; text: "up " + (SysStats.uptime || "…") }
                    InfoChip { icon: "terminal"; text: root.sys.shell || "sh" }
                    Item { Layout.fillWidth: true }
                    IconButton {
                        size: 34
                        iconSize: 18
                        icon: "settings"
                        filled: true
                        onClicked: {
                            DashboardState.close();
                            Quickshell.execDetached(["qs", "-p", Quickshell.shellDir, "ipc", "call", "settings", "open"]);
                        }
                    }
                    IconButton {
                        size: 34
                        iconSize: 18
                        icon: "lock"
                        filled: true
                        onClicked: { DashboardState.close(); Panels.closeAll(); Panels.locked = true; }
                    }
                    IconButton {
                        size: 34
                        iconSize: 18
                        icon: "power_settings_new"
                        base: Theme.errorContainer
                        content: Theme.errorContainerFg
                        onClicked: Panels.toggle("power")
                    }
                }
            }

            // ---- greeting + clock ----
            Surface {
                Layout.fillWidth: true
                implicitHeight: 104
                radius: Tokens.radius.xl
                base: Theme.primaryContainer

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.space.l + 2
                    spacing: 0
                    StyledText {
                        text: `${root.greeting}, ${root.fullName.split(" ")[0]}`
                        font.pixelSize: Tokens.font.l
                        font.weight: Font.DemiBold
                        color: Theme.primaryContainerFg
                    }
                    StyledText {
                        text: Time.time
                        font.pixelSize: 44
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                        color: Theme.primaryContainerFg
                    }
                }
                ColumnLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Tokens.space.l + 2
                    spacing: 2
                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        text: Time.format("dddd")
                        font.weight: Font.DemiBold
                        color: Theme.primaryContainerFg
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        text: Time.format("d MMMM yyyy")
                        color: Theme.alpha(Theme.primaryContainerFg, 0.8)
                    }
                    // Tiny weather summary; jumps to the weather tab.
                    Surface {
                        Layout.alignment: Qt.AlignRight
                        Layout.topMargin: Tokens.space.xs
                        visible: Weather.ready && Weather.current !== null
                        implicitWidth: wx.implicitWidth + Tokens.space.m * 2
                        implicitHeight: 28
                        radius: 14
                        interactive: true
                        base: Theme.alpha(Theme.primaryContainerFg, 0.1)
                        content: Theme.primaryContainerFg
                        onClicked: DashboardState.setView("weather")
                        Row {
                            id: wx
                            anchors.centerIn: parent
                            spacing: Tokens.space.xs
                            Icon { anchors.verticalCenter: parent.verticalCenter; text: Weather.current?.icon ?? "cloud"; size: 16; fill: 1; color: Theme.primaryContainerFg }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Weather.current ? `${Weather.fmtTemp(Weather.current.temp)} ${Weather.current.description}` : ""
                                font.pixelSize: Tokens.font.s
                                font.weight: Font.DemiBold
                                color: Theme.primaryContainerFg
                            }
                        }
                    }
                }
            }

            // ---- the week ahead (with the forecast when available) ----
            Surface {
                Layout.fillWidth: true
                implicitHeight: 108
                radius: Tokens.radius.xl
                base: Theme.surfaceContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.space.s
                    spacing: Tokens.space.xs

                    Repeater {
                        model: 7
                        Rectangle {
                            id: dayCell
                            required property int index
                            readonly property date day: new Date(Time.now.getFullYear(), Time.now.getMonth(), Time.now.getDate() + index)
                            readonly property var forecast: Weather.daily.length > index ? Weather.daily[index] : null
                            readonly property bool today: index === 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Tokens.radius.l
                            color: today ? Theme.primary : "transparent"

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Qt.formatDate(dayCell.day, "ddd")
                                    font.pixelSize: Tokens.font.xs
                                    font.weight: Font.DemiBold
                                    color: dayCell.today ? Theme.primaryFg : Theme.surfaceVariantFg
                                }
                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dayCell.day.getDate()
                                    font.pixelSize: Tokens.font.l
                                    font.weight: Font.Bold
                                    color: dayCell.today ? Theme.primaryFg : Theme.surfaceFg
                                }
                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dayCell.forecast ? dayCell.forecast.icon : ""
                                    visible: dayCell.forecast !== null
                                    size: 18
                                    fill: 1
                                    color: dayCell.today ? Theme.primaryFg : Theme.surfaceVariantFg
                                }
                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: dayCell.forecast !== null
                                    text: dayCell.forecast ? Weather.fmtTemp(dayCell.forecast.max) : ""
                                    font.pixelSize: Tokens.font.xs
                                    color: dayCell.today ? Theme.primaryFg : Theme.surfaceVariantFg
                                }
                            }
                        }
                    }
                }
            }

            // ---- live stats ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.s

                StatTile { icon: "memory"; label: "CPU"; value: SysStats.cpu; text: Math.round(SysStats.cpu * 100) + "%"; accent: Theme.primary }
                StatTile { icon: "memory_alt"; label: "Memory"; value: SysStats.memory; text: Math.round(SysStats.memory * 100) + "%"; accent: Theme.secondary }
                StatTile { icon: "hard_drive"; label: "Disk"; value: SysStats.disk; text: Math.round(SysStats.disk * 100) + "%"; accent: Theme.tertiary }
                StatTile { icon: "device_thermostat"; label: "Temp"; value: SysStats.temperature / 100; text: Math.round(SysStats.temperature) + "°"; accent: SysStats.temperature > 85 ? Theme.error : "#ff8c3a" }
            }

            // ---- system ----
            Surface {
                Layout.fillWidth: true
                implicitHeight: sysCol.implicitHeight + Tokens.space.l * 2
                radius: Tokens.radius.xl
                base: Theme.surfaceContainer

                ColumnLayout {
                    id: sysCol
                    anchors.fill: parent
                    anchors.margins: Tokens.space.l
                    spacing: Tokens.space.s

                    RowLayout {
                        spacing: Tokens.space.s
                        Icon { text: "computer"; size: 17; fill: 1; color: Theme.primary }
                        StyledText { text: "System"; font.pixelSize: Tokens.font.s; font.weight: Font.DemiBold; color: Theme.surfaceVariantFg }
                    }

                    InfoRow { icon: "laptop_chromebook"; label: "Device"; value: root.sys.model || root.sys.host || "—" }
                    InfoRow { icon: "deployed_code"; label: "OS"; value: root.sys.os || "—" }
                    InfoRow { icon: "settings_suggest"; label: "Kernel"; value: root.sys.kernel || "—" }
                    InfoRow { icon: "developer_board"; label: "CPU"; value: root.sys.cpu ? `${root.sys.cpu} (${root.sys.cores} threads)` : "—" }
                    InfoRow { icon: "memory_alt"; label: "Memory"; value: `${SysStats.memUsedGiB.toFixed(1)} / ${SysStats.memTotalGiB.toFixed(1)} GiB` }
                    InfoRow { icon: "desktop_windows"; label: "Session"; value: (Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland") + " · " + Quickshell.screens.map(s => `${s.width}×${s.height}`).join(", ") }
                }
            }
        }
    }

    component InfoChip: Rectangle {
        id: ic
        property string icon
        property string text
        implicitWidth: icRow.implicitWidth + Tokens.space.m * 2
        implicitHeight: 28
        radius: 14
        color: Theme.surfaceHigh
        Row {
            id: icRow
            anchors.centerIn: parent
            spacing: Tokens.space.xs
            Icon { anchors.verticalCenter: parent.verticalCenter; text: ic.icon; size: 15; color: Theme.primary }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: ic.text; font.pixelSize: Tokens.font.s }
        }
    }

    component StatTile: Surface {
        id: st
        property string icon
        property string label
        property string text
        property real value
        property color accent
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 118
        radius: Tokens.radius.xl
        base: Theme.surfaceContainer

        Item {
            id: ringBox
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Tokens.space.m
            width: 60
            height: 60
            Ring {
                anchors.fill: parent
                thickness: 6
                value: root.active ? st.value : 0
                color: st.accent
                track: Theme.alpha(st.accent, 0.16)
            }
            StyledText {
                anchors.centerIn: parent
                text: st.text
                font.pixelSize: Tokens.font.m
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: ringBox.bottom
            anchors.topMargin: Tokens.space.s
            spacing: Tokens.space.xs
            Icon { anchors.verticalCenter: parent.verticalCenter; text: st.icon; size: 14; color: st.accent }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: st.label; font.pixelSize: Tokens.font.s; color: Theme.surfaceVariantFg }
        }
    }

    component InfoRow: RowLayout {
        property string icon
        property string label
        property string value
        Layout.fillWidth: true
        spacing: Tokens.space.m
        Icon { text: parent.icon; size: 18; color: Theme.surfaceVariantFg }
        StyledText { Layout.preferredWidth: 64; text: parent.label; color: Theme.surfaceVariantFg; font.pixelSize: Tokens.font.s }
        StyledText { Layout.fillWidth: true; text: parent.value; font.weight: Font.Medium; horizontalAlignment: Text.AlignRight }
    }
}
