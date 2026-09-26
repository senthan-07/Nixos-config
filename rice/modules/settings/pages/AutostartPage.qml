import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.settings
import "../controls"
import qs.components
import qs.services
import qs.config

// Autostart: XDG autostart entries in ~/.config/autostart. Add installed apps or custom
// commands, switch entries on/off (Hidden=true) and remove them. System-wide entries can
// be disabled through a per-user override.
SettingsPage {
    id: root

    property var pendingRemove: null

    title: "Autostart"
    subtitle: "Apps and commands that start when you log in"

    AutostartStore { id: store }

    Banner {
        visible: store.error !== ""
        tone: "error"
        text: store.error
        ActionButton { text: "Retry"; onClicked: store.refresh() }
    }

    // ---- add ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: addRow.implicitHeight + Tokens.space.xl * 2
        radius: Tokens.radius.xl
        color: Theme.primaryContainer

        RowLayout {
            id: addRow
            anchors.fill: parent
            anchors.margins: Tokens.space.xl
            spacing: Tokens.space.l

            Rectangle {
                implicitWidth: 64
                implicitHeight: 64
                radius: 22
                color: Theme.primary
                Icon { anchors.centerIn: parent; text: "rocket_launch"; size: 32; fill: 1; color: Theme.primaryFg }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    text: store.loading ? "Loading…" : `${store.entries.filter(e => e.enabled).length} of ${store.entries.length} start at login`
                    font.pixelSize: Tokens.font.xl
                    font.weight: Font.DemiBold
                    color: Theme.primaryContainerFg
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Fewer startup apps means a faster login."
                    color: Theme.alpha(Theme.primaryContainerFg, 0.8)
                }
            }
            ActionButton { text: "Add command"; icon: "terminal"; kind: "outlined"; onClicked: commandDialog.open() }
            ActionButton { text: "Add app"; icon: "add"; kind: "filled"; onClicked: picker.open() }
        }
    }

    // ---- user entries ----
    SettingsSection {
        title: "Startup applications"

        EmptyState {
            visible: store.entries.length === 0
            loading: store.loading
            icon: "rocket_launch"
            title: store.loading ? "Reading autostart entries…" : "Nothing starts automatically"
            text: store.loading ? "" : "Add an app or a command to launch it every time you log in."
        }

        Repeater {
            model: store.entries

            ListRow {
                id: row
                required property var modelData
                readonly property var e: modelData
                appIcon: e.icon || "application-x-executable"
                title: e.valid ? e.name : `${e.name} (invalid)`
                subtitle: e.valid ? e.exec : "Missing Exec= line"
                subtitleColor: e.valid ? Theme.surfaceVariantFg : Theme.error
                mono: e.valid
                opacity: e.enabled ? 1 : 0.7

                SettingsSwitch {
                    checked: row.e.enabled && row.e.valid
                    opacity: row.e.valid ? 1 : 0.4
                    onToggled: if (row.e.valid) store.setEnabled(row.e, !row.e.enabled)
                }
                IconButton {
                    icon: "delete"
                    onClicked: { root.pendingRemove = row.e; removeDialog.open(); }
                }
            }
        }
    }

    // ---- system entries ----
    SettingsSection {
        title: "System"
        visible: store.system.length > 0

        Repeater {
            model: store.system
            ListRow {
                id: sysRow
                required property var modelData
                appIcon: modelData.icon || "application-x-executable"
                title: modelData.name
                subtitle: modelData.overridden ? "Disabled for your account" : modelData.comment || modelData.exec
                opacity: modelData.enabled ? 1 : 0.7
                SettingsSwitch {
                    checked: sysRow.modelData.enabled
                    onToggled: store.setEnabled(sysRow.modelData, !sysRow.modelData.enabled)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.space.s
        spacing: Tokens.space.s
        Icon { text: "folder_open"; size: 16; color: Theme.surfaceVariantFg }
        StyledText {
            Layout.fillWidth: true
            text: `Entries live in ${store.dir}. Hyprland exec-once lines are not shown here.`
            font.pixelSize: Tokens.font.s
            color: Theme.surfaceVariantFg
            wrapMode: Text.Wrap
        }
        ActionButton {
            text: "Refresh"
            icon: "refresh"
            onClicked: store.refresh()
        }
    }

    AppPicker {
        id: picker
        title: "Add an app to autostart"
        exclude: store.entries.map(e => e.file.replace(/\.desktop$/, ""))
        onPicked: entry => {
            store.addApplication(entry);
            toast.show(`${entry.name} will start at login`, "rocket_launch");
        }
    }

    Dialog {
        id: commandDialog
        icon: "terminal"
        title: "Add a startup command"
        text: "The command runs once when you log in, like a shell command without a terminal."
        confirmText: "Add"
        confirmEnabled: cmdName.text.trim() !== "" && cmdLine.text.trim() !== ""
        onOpened: { cmdName.text = ""; cmdLine.text = ""; cmdName.focusField(); }
        onConfirmed: {
            store.addCommand(cmdName.text.trim(), cmdLine.text.trim());
            toast.show(`Added ${cmdName.text.trim()}`, "rocket_launch");
        }

        InputField { id: cmdName; label: "Name"; icon: "label"; surfaceColor: Theme.surfaceHigh }
        InputField {
            id: cmdLine
            label: "Command"
            surfaceColor: Theme.surfaceHigh
            icon: "terminal"
            mono: true
            helper: "e.g. nm-applet --indicator"
            onAccepted: if (commandDialog.confirmEnabled) { commandDialog.close(); commandDialog.confirmed(); }
        }
    }

    Dialog {
        id: removeDialog
        icon: "delete"
        title: `Remove ${root.pendingRemove?.name ?? ""}?`
        text: "It will no longer start when you log in. The application itself stays installed."
        confirmText: "Remove"
        danger: true
        onConfirmed: {
            if (root.pendingRemove) store.remove(root.pendingRemove);
            root.pendingRemove = null;
        }
    }

    Toast { id: toast }
}
