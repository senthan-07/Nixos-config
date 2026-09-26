import QtQuick
import QtQuick.Layouts
import qs.modules.settings
import "../controls"
import qs.components
import qs.services
import qs.config

// Default applications: which app opens links, folders, documents and media
// (xdg-mime / mimeapps.list), plus the terminal rice launches.
SettingsPage {
    id: root

    readonly property var groups: ["Internet", "Utilities", "Documents", "Multimedia"]

    title: "Default apps"
    subtitle: "Choose which applications open links, folders, documents and media"

    MimeDefaults { id: mime }

    Banner {
        visible: !mime.available
        tone: "error"
        text: mime.error
    }
    Banner {
        visible: mime.loading
        busy: true
        text: "Reading installed applications…"
    }

    Repeater {
        model: root.groups

        SettingsSection {
            id: group
            required property string modelData
            title: modelData

            Repeater {
                model: mime.roles.filter(r => r.group === group.modelData)

                SettingsRow {
                    id: row
                    required property var modelData
                    readonly property var options: mime.loading ? [] : mime.candidates(modelData)
                    readonly property string value: mime.current[modelData.id] ?? ""
                    icon: modelData.icon
                    label: modelData.title
                    description: mime.loading ? ""
                        : options.length === 0 ? "No installed application handles this"
                        : modelData.id === "terminal" ? "Used by the launcher and \"Open in terminal\" actions"
                        : value === "" ? "Not set — the first matching app is used" : ""

                    Select {
                        implicitWidth: 280
                        enabled: !mime.loading && row.options.length > 0
                        options: row.options
                        value: row.value
                        placeholder: mime.loading ? "Loading…" : row.options.length ? "Not set" : "None available"
                        onSelected: v => {
                            mime.setDefault(row.modelData, v);
                            const o = row.options.find(x => x.value === v);
                            toast.show(`${o?.label ?? v} is now the default ${row.modelData.title.toLowerCase()}`);
                        }
                    }
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.space.s
        text: "Choices are saved to ~/.config/mimeapps.list and apply to every application that follows the freedesktop standard."
        font.pixelSize: Tokens.font.s
        color: Theme.surfaceVariantFg
        wrapMode: Text.Wrap
    }

    Toast { id: toast }
}
