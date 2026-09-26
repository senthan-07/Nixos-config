import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.settings
import "../widgets"
import "../widgets/binds.js" as Binds
import qs.components
import qs.services
// qs.config last: its `Settings` singleton must win over modules/settings/Settings.qml.
import qs.config

SettingsPage {
    id: page

    title: "Shortcuts"
    subtitle: "Every keybinding, grouped by what it does. Edit them in your Hyprland config."

    readonly property bool hyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""
    property var fileRows: []
    property var liveRows: null
    property string configDir: ""
    property bool filesLoaded: false
    property bool liveFailed: false
    property string query: ""

    readonly property bool loading: !filesLoaded || (hyprland && liveRows === null && !liveFailed)
    readonly property bool usingLive: liveRows !== null && liveRows.length > 0
    readonly property var rows: usingLive ? liveRows : fileRows
    readonly property var groups: Binds.group(rows, query)
    readonly property int matchCount: groups.reduce((n, g) => n + g.items.length, 0)

    function reload() {
        filesLoaded = false;
        liveRows = null;
        liveFailed = false;
        files.running = false;
        files.running = true;
    }

    Component.onCompleted: {
        reload();
        search.focusInput();
    }

    // ---- Search + source ---------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.space.s

        InputField {
            id: search
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 24
            icon: "search"
            placeholder: "Search shortcuts, keys or commands"
            onEdited: t => page.query = t
        }
        IconButton {
            size: 48
            icon: "refresh"
            filled: true
            onClicked: page.reload()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !page.loading
        spacing: Tokens.space.s

        Chip {
            implicitHeight: 28
            base: page.usingLive ? Theme.primaryContainer : Theme.secondaryContainer
            Icon {
                text: page.usingLive ? "sensors" : "description"
                size: 16
                color: page.usingLive ? Theme.primaryContainerFg : Theme.secondaryContainerFg
            }
            StyledText {
                text: page.usingLive ? "Live from Hyprland" : "Parsed from config files"
                font.pixelSize: Tokens.font.s
                font.weight: Font.Medium
                color: page.usingLive ? Theme.primaryContainerFg : Theme.secondaryContainerFg
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: page.query !== ""
                ? page.matchCount + " of " + page.rows.length + " shortcuts"
                : page.rows.length + " shortcuts" + (page.usingLive ? "" : page.configDir ? " in " + page.configDir.replace(Paths.home, "~") : "")
            color: Theme.surfaceVariantFg
            font.pixelSize: Tokens.font.s
        }
    }

    // Friendly note when Hyprland isn't reachable (e.g. another compositor or a test session).
    Rectangle {
        Layout.fillWidth: true
        visible: !page.loading && !page.usingLive && page.fileRows.length > 0
        implicitHeight: note.implicitHeight + Tokens.space.m * 2
        radius: Tokens.radius.m
        color: Theme.alpha(Theme.tertiaryContainer, 0.6)

        RowLayout {
            id: note
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.space.l
            anchors.rightMargin: Tokens.space.l
            spacing: Tokens.space.m
            Icon { text: "info"; color: Theme.tertiaryContainerFg }
            StyledText {
                Layout.fillWidth: true
                text: page.hyprland
                    ? "Couldn't read binds from hyprctl, so these were parsed from your config. Loops and helpers are expanded, but dynamic binds may be missing."
                    : "Hyprland isn't running in this session. These binds were parsed from your config files and may differ from what's active."
                color: Theme.tertiaryContainerFg
                font.pixelSize: Tokens.font.s
                wrapMode: Text.Wrap
            }
        }
    }

    // ---- States ------------------------------------------------------------------
    EmptyState {
        visible: page.loading
        busy: true
        icon: "keyboard"
        title: "Reading keybindings…"
    }

    EmptyState {
        visible: !page.loading && page.rows.length === 0
        icon: "keyboard_off"
        title: "No keybindings found"
        body: page.configDir
            ? "Nothing that looks like hl.bind(…) or bind = … was found in " + page.configDir.replace(Paths.home, "~") + "."
            : "No Hyprland config directory was found in ~/.config/hypr."
        ActionButton { style: "tonal"; icon: "refresh"; text: "Try again"; onClicked: page.reload() }
    }

    EmptyState {
        visible: !page.loading && page.rows.length > 0 && page.matchCount === 0
        icon: "search_off"
        title: "No shortcuts match “" + page.query + "”"
        body: "Try a key name like “super”, an action like “workspace”, or a command."
    }

    // ---- Groups --------------------------------------------------------------------
    Repeater {
        model: page.loading ? [] : page.groups

        ColumnLayout {
            id: groupCol
            required property var modelData
            Layout.fillWidth: true
            spacing: Tokens.space.s

            RowLayout {
                Layout.leftMargin: Tokens.space.s
                spacing: Tokens.space.s
                Icon { text: groupCol.modelData.icon; size: 18; fill: 1; color: Theme.primary }
                StyledText {
                    text: groupCol.modelData.name
                    color: Theme.primary
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    implicitWidth: countText.implicitWidth + 12
                    implicitHeight: 18
                    radius: 9
                    color: Theme.alpha(Theme.primary, 0.14)
                    StyledText {
                        id: countText
                        anchors.centerIn: parent
                        text: groupCol.modelData.items.length
                        color: Theme.primary
                        font.pixelSize: Tokens.font.xs
                        font.weight: Font.Bold
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: list.implicitHeight + Tokens.space.s * 2
                radius: Tokens.radius.l
                color: Theme.surfaceContainer

                ColumnLayout {
                    id: list
                    x: Tokens.space.s
                    y: Tokens.space.s
                    width: parent.width - Tokens.space.s * 2
                    spacing: 2

                    Repeater {
                        model: groupCol.modelData.items

                        Surface {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property var r: modelData

                            Layout.fillWidth: true
                            implicitHeight: Math.max(52, rowContent.implicitHeight + Tokens.space.m * 2)
                            radius: Tokens.radius.m
                            interactive: r.command !== ""
                            base: Theme.surfaceContainer
                            content: Theme.surfaceFg
                            // Clicking a command row copies the command.
                            onClicked: {
                                Quickshell.clipboardText = r.command;
                                copied.restart();
                            }

                            RowLayout {
                                id: rowContent
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.space.l
                                anchors.rightMargin: Tokens.space.m
                                spacing: Tokens.space.l

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: row.r.description
                                        font.weight: Font.Medium
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: row.r.command !== ""
                                        text: copied.running ? "Copied to clipboard" : row.r.command
                                        color: copied.running ? Theme.primary : Theme.surfaceVariantFg
                                        font.family: Tokens.font.mono
                                        font.pixelSize: Tokens.font.xs
                                        Timer { id: copied; interval: 1200 }
                                    }
                                }

                                Icon {
                                    visible: !!row.r.flags.locked
                                    text: "lock"
                                    size: 16
                                    color: Theme.surfaceVariantFg
                                    opacity: 0.7
                                }

                                Row {
                                    spacing: Tokens.space.xs
                                    Repeater {
                                        model: row.r.mods.concat([row.r.key])
                                        Row {
                                            required property string modelData
                                            required property int index
                                            spacing: Tokens.space.xs
                                            StyledText {
                                                visible: index > 0
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "+"
                                                color: Theme.surfaceVariantFg
                                                font.pixelSize: Tokens.font.s
                                            }
                                            Keycap { key: modelData }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- sources -------------------------------------------------------------------
    Process {
        id: files
        command: ["sh", "-c",
            "d=\"${XDG_CONFIG_HOME:-$HOME/.config}/hypr\"; "
            + "[ -d \"$d\" ] || d=\"$HOME/Modules/nixos/rice/Dotfiles/hypr\"; "
            + "[ -d \"$d\" ] || exit 0; echo \"@@DIR $d\"; "
            + "find -L \"$d\" -maxdepth 3 -type f \\( -name '*.lua' -o -name '*.conf' \\) 2>/dev/null | sort | "
            + "while IFS= read -r f; do grep -qE 'hl\\.bind|^[[:space:]]*bind[a-z]*[[:space:]]*=' \"$f\" 2>/dev/null || continue; "
            + "printf '\\n@@FILE %s\\n' \"$f\"; cat \"$f\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = text.match(/^@@DIR (.*)$/m);
                page.configDir = dir ? dir[1] : "";
                const list = [];
                for (const chunk of text.split("\n@@FILE ").slice(1)) {
                    const nl = chunk.indexOf("\n");
                    list.push({ path: chunk.slice(0, nl), text: chunk.slice(nl + 1) });
                }
                try {
                    page.fileRows = Binds.parseFiles(list);
                } catch (e) {
                    console.warn("rice settings: could not parse keybinds:", e);
                    page.fileRows = [];
                }
                page.filesLoaded = true;
                if (page.hyprland) live.running = true;
            }
        }
    }

    Process {
        id: live
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = Binds.parseLive(text, page.fileRows);
                if (rows === null) page.liveFailed = true;
                else page.liveRows = rows;
            }
        }
        onExited: code => { if (code !== 0) page.liveFailed = true; }
    }
}
