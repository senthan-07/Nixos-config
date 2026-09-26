import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.settings
import "../widgets"
import qs.components
import qs.services
// qs.config last: its `Settings` singleton must win over modules/settings/Settings.qml.
import qs.config

SettingsPage {
    id: page

    title: "General"
    subtitle: "Clock, default terminal, interface font and motion."

    readonly property var datePresets: [
        { value: "ddd, d MMM", label: "Short" },
        { value: "dddd, d MMMM", label: "Long" },
        { value: "d MMM yyyy", label: "Day month year" },
        { value: "d/M/yyyy", label: "Numeric (D/M)" },
        { value: "M/d/yyyy", label: "Numeric (M/D)" },
        { value: "yyyy-MM-dd", label: "ISO 8601" },
        { value: "__custom", label: "Custom…", icon: "edit" }
    ].map(p => p.value === "__custom" ? p
        : Object.assign({ hint: Qt.formatDate(Time.now, p.value) }, p))

    readonly property bool customDate: datePresets.findIndex(p => p.value === Settings.data.dateFormat) < 0
    property bool editingDate: false

    // ---- Clock -----------------------------------------------------------
    SettingsSection {
        title: "Clock"

        // Live preview of the bar clock.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 96
            radius: Tokens.radius.m
            color: Theme.primaryContainer

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.space.xl
                anchors.rightMargin: Tokens.space.xl
                spacing: Tokens.space.l

                Icon {
                    text: "schedule"
                    size: 40
                    fill: 1
                    color: Theme.primaryContainerFg
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: Time.time
                        color: Theme.primaryContainerFg
                        font.pixelSize: 34
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.formatDate(Time.now, Settings.data.dateFormat || "ddd, d MMM")
                        color: Theme.primaryContainerFg
                        opacity: 0.8
                    }
                }
                StyledText {
                    text: "Preview"
                    color: Theme.primaryContainerFg
                    opacity: 0.6
                    font.pixelSize: Tokens.font.s
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Tokens.space.m
                }
            }
        }

        SettingsRow {
            icon: "timer_10_select"
            label: "24-hour time"
            description: Settings.data.use24h ? "13:45" : "1:45 PM"
            SettingsSwitch {
                checked: Settings.data.use24h
                onToggled: Settings.data.use24h = !Settings.data.use24h
            }
        }

        SettingsRow {
            icon: "avg_pace"
            label: "Show seconds"
            description: "Ticks every second in the bar"
            SettingsSwitch {
                checked: Settings.data.showSeconds
                onToggled: Settings.data.showSeconds = !Settings.data.showSeconds
            }
        }

        SettingsRow {
            icon: "calendar_today"
            label: "Date format"
            description: page.customDate || page.editingDate
                ? "Qt format: d dd ddd dddd · M MM MMM MMMM · yy yyyy"
                : Qt.formatDate(Time.now, Settings.data.dateFormat)
            Dropdown {
                implicitWidth: 260
                model: page.datePresets
                value: page.customDate || page.editingDate ? "__custom" : Settings.data.dateFormat
                onActivated: v => {
                    if (v === "__custom") {
                        page.editingDate = true;
                        dateField.text = Settings.data.dateFormat;
                        dateField.focusInput();
                    } else {
                        page.editingDate = false;
                        Settings.data.dateFormat = v;
                    }
                }
            }
        }

        SettingsRow {
            visible: page.customDate || page.editingDate
            icon: "edit_calendar"
            label: "Custom format"
            description: dateField.text.trim() === "" ? "Enter a format"
                : "Shows as “" + Qt.formatDate(Time.now, dateField.text) + "”"
            InputField {
                id: dateField
                implicitWidth: 260
                monospace: true
                placeholder: "ddd, d MMM"
                text: Settings.data.dateFormat
                error: text.trim() === ""
                onEdited: t => { if (t.trim() !== "") dateCommit.restart(); }
                onAccepted: t => { if (t.trim() !== "") Settings.data.dateFormat = t; }
            }
            Timer {
                id: dateCommit
                interval: 400
                onTriggered: Settings.data.dateFormat = dateField.text
            }
        }
    }

    // ---- Apps ------------------------------------------------------------
    SettingsSection {
        title: "Apps"

        SettingsRow {
            icon: "terminal"
            label: "Terminal"
            description: terminals.running ? "Looking for installed terminals…"
                : terminals.found.length === 0 ? "No known terminal found in PATH"
                : "Used by the launcher and “Open terminal” actions"
            Dropdown {
                implicitWidth: 220
                icon: "terminal"
                model: {
                    const list = terminals.found.map(t => ({ value: t, label: t, icon: "terminal" }));
                    const cur = Settings.data.terminal;
                    if (cur && !terminals.found.includes(cur))
                        list.unshift({ value: cur, label: cur, icon: "terminal", hint: "custom" });
                    list.push({ value: "__custom", label: "Other…", icon: "edit" });
                    return list;
                }
                value: termField.visible ? "__custom" : Settings.data.terminal
                onActivated: v => {
                    if (v === "__custom") {
                        termField.visible = true;
                        termField.text = "";
                        termField.focusInput();
                    } else {
                        termField.visible = false;
                        Settings.data.terminal = v;
                    }
                }
            }
            ActionButton {
                style: "text"
                icon: "open_in_new"
                text: "Try"
                enabled: Settings.data.terminal !== ""
                onClicked: Quickshell.execDetached(["sh", "-c", Settings.data.terminal])
            }
        }

        SettingsRow {
            visible: termField.visible
            icon: "keyboard_command_key"
            label: "Terminal command"
            description: "Any command in PATH, e.g. “foot” or “wezterm start”. Enter to save."
            InputField {
                id: termField
                visible: false
                implicitWidth: 260
                monospace: true
                placeholder: "command"
                onAccepted: t => {
                    if (t.trim() === "") return;
                    Settings.data.terminal = t.trim();
                    visible = false;
                }
            }
        }
    }

    // ---- Interface -------------------------------------------------------
    SettingsSection {
        title: "Interface"

        SettingsRow {
            icon: "match_case"
            label: "Interface font"
            description: fonts.running ? "Loading installed fonts…"
                : fonts.families.length + " font families installed"
            Dropdown {
                id: fontDropdown
                implicitWidth: 260
                searchable: true
                popupMaxHeight: 360
                model: fonts.families.length ? fonts.families.map(f => ({ value: f, label: f, font: f }))
                    : [{ value: Settings.data.uiFont, label: Settings.data.uiFont }]
                value: Settings.data.uiFont
                onActivated: v => Settings.data.uiFont = v
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: fontPreview.implicitHeight + Tokens.space.l * 2
            radius: Tokens.radius.m
            color: Theme.surfaceLow

            ColumnLayout {
                id: fontPreview
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.space.xl
                spacing: Tokens.space.xs
                StyledText {
                    Layout.fillWidth: true
                    text: "The quick brown fox jumps over the lazy dog"
                    font.family: Settings.data.uiFont
                    font.pixelSize: Tokens.font.xl
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "0123456789 · Aa Bb Cc · Settings, launcher, bar and panels"
                    font.family: Settings.data.uiFont
                    color: Theme.surfaceVariantFg
                }
            }
        }

        SettingsRow {
            icon: "animation"
            label: "Animations"
            description: Settings.data.animationScale === 0 ? "Motion is off; panels appear instantly"
                : Settings.data.animationScale < 1 ? "Snappier transitions"
                : Settings.data.animationScale > 1 ? "Relaxed, slower transitions"
                : "Material 3 standard timing"
            SegmentedButtons {
                model: [
                    { value: 0, label: "Off" },
                    { value: 0.5, label: "Fast" },
                    { value: 1, label: "Normal" },
                    { value: 1.5, label: "Relaxed" }
                ]
                value: Settings.data.animationScale
                onActivated: v => Settings.data.animationScale = v
            }
        }
    }

    // ---- data sources ----------------------------------------------------
    Process {
        id: terminals
        property var found: []
        running: true
        command: ["sh", "-c", "for t in kitty foot alacritty wezterm ghostty konsole gnome-terminal ptyxis xfce4-terminal st xterm; do command -v \"$t\" >/dev/null 2>&1 && echo \"$t\"; done"]
        stdout: StdioCollector {
            onStreamFinished: terminals.found = text.split("\n").filter(l => l)
        }
    }

    Process {
        id: fonts
        property var families: []
        running: true
        command: ["fc-list", "--format", "%{family[0]}\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                for (const l of text.split("\n")) {
                    const f = l.trim();
                    if (f && !f.startsWith(".")) seen[f] = true;
                }
                fonts.families = Object.keys(seen).sort((a, b) => a.localeCompare(b));
            }
        }
    }
}
