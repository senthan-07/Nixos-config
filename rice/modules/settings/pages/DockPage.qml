import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.settings
import "../widgets"
import qs.components
import qs.services
// qs.config last: its `Settings` singleton must win over modules/settings/Settings.qml.
import qs.config

SettingsPage {
    id: page

    title: "Dock"
    subtitle: "The app dock at the bottom of the screen: behaviour, size and the apps kept in it."

    // ---- Live preview ------------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.max(132, Dock.iconSize + 84)
        radius: Tokens.radius.xl
        color: Theme.surfaceLow
        clip: true

        Behavior on implicitHeight { Anim { duration: Motion.duration.short } }

        // Faux desktop.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(Theme.primaryContainer, 0.55) }
                GradientStop { position: 1; color: Theme.alpha(Theme.tertiaryContainer, 0.35) }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: !Dock.enabled
            text: "The dock is turned off"
            color: Theme.surfaceVariantFg
        }

        Rectangle {
            id: mini
            visible: Dock.enabled
            readonly property var keys: Dock.keys.slice(0, 12)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Dock.autohide ? -height + 6 : Dock.edgeGap
            width: row.implicitWidth + 18
            height: Dock.iconSize + Dock.padding * 2 + 6
            radius: Math.min(Tokens.radius.xl, height / 2)
            color: Theme.alpha(Theme.surface, 0.88)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.55)
            Behavior on anchors.bottomMargin { Anim {} }
            Behavior on width { Anim { duration: Motion.duration.short } }

            Row {
                id: row
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                spacing: 6

                Repeater {
                    model: mini.keys
                    Item {
                        required property string modelData
                        width: Dock.iconSize
                        height: Dock.iconSize
                        AppIcon {
                            anchors.fill: parent
                            size: Dock.iconSize
                            name: Dock.iconFor(parent.modelData)
                        }
                        Rectangle {
                            visible: Dock.windowsFor(parent.modelData).length > 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 3
                            width: 5; height: 5; radius: 2.5
                            color: Theme.alpha(Theme.surfaceFg, 0.7)
                        }
                    }
                }
                Rectangle {
                    visible: Dock.showFolder && mini.keys.length > 0
                    width: 1
                    height: Dock.iconSize * 0.8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.outlineVariant
                }
                Rectangle {
                    visible: Dock.showFolder
                    width: Dock.iconSize
                    height: Dock.iconSize
                    radius: width * 0.26
                    color: Theme.primaryContainer
                    Icon {
                        anchors.centerIn: parent
                        text: "download"
                        fill: 1
                        size: parent.width * 0.5
                        color: Theme.primaryContainerFg
                    }
                }
            }
        }

        StyledText {
            visible: Dock.enabled && Dock.autohide
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Tokens.space.l
            text: Dock.smartHide ? "Hides when a window touches it" : "Hidden until you point at the bottom edge"
            font.pixelSize: Tokens.font.s
            color: Theme.surfaceVariantFg
        }
    }

    // ---- Behaviour --------------------------------------------------------------------
    SettingsSection {
        title: "Behaviour"

        SettingsRow {
            icon: "dock_to_bottom"
            label: "Show the dock"
            description: "One dock on every screen."
            SettingsSwitch { checked: Dock.enabled; onToggled: Dock.setEnabled(!Dock.enabled) }
        }
        SettingsRow {
            icon: "visibility_off"
            label: "Automatically hide"
            description: "Slide the dock away and reveal it when the pointer reaches the bottom edge."
            SettingsSwitch { checked: Dock.autohide; onToggled: Dock.setAutohide(!Dock.autohide) }
        }
        SettingsRow {
            icon: "select_window"
            label: "Only hide when a window overlaps"
            description: "Keeps the dock visible on empty workspaces (Hyprland only)."
            enabled: Dock.autohide
            opacity: enabled ? 1 : 0.5
            SettingsSwitch { checked: Dock.smartHide; onToggled: if (Dock.autohide) Dock.setSmartHide(!Dock.smartHide) }
        }
        SettingsRow {
            icon: "filter_alt"
            label: "Show running apps only"
            description: "Pinned apps appear only while they have a window open."
            SettingsSwitch { checked: Dock.runningOnly; onToggled: Dock.setRunningOnly(!Dock.runningOnly) }
        }
        SettingsRow {
            icon: "preview"
            label: "Window previews"
            description: "Live thumbnails when hovering a running app. Off shows a title list."
            SettingsSwitch { checked: Dock.showPreviews; onToggled: Dock.setShowPreviews(!Dock.showPreviews) }
        }
    }

    // ---- Size ------------------------------------------------------------------------------
    SettingsSection {
        title: "Size"

        SliderRow {
            icon: "photo_size_select_large"
            label: "Icon size"
            from: 32
            to: 80
            stepSize: 2
            value: Dock.iconSize
            format: v => Math.round(v) + " px"
            fromLabel: "Small"
            toLabel: "Large"
            onMoved: v => Dock.setIconSize(v)
        }
        SettingsRow {
            icon: "zoom_in"
            label: "Magnification"
            description: "Icons grow under the pointer."
            SettingsSwitch { checked: Dock.magnification; onToggled: Dock.setMagnification(!Dock.magnification) }
        }
        SliderRow {
            icon: "open_in_full"
            label: "Magnification amount"
            enabled: Dock.magnification
            opacity: enabled ? 1 : 0.5
            from: 1.1
            to: 2
            stepSize: 0.05
            value: Dock.magnifyScale
            format: v => Math.round(v * 100) + "%"
            onMoved: v => Dock.setMagnifyScale(v)
        }
        SliderRow {
            icon: "padding"
            label: "Padding"
            description: "Space around the icons inside the dock."
            from: 4
            to: 32
            stepSize: 1
            value: Dock.padding
            format: v => Math.round(v) + " px"
            fromLabel: "Tight"
            toLabel: "Roomy"
            onMoved: v => Dock.setPadding(v)
        }
        SliderRow {
            icon: "vertical_align_bottom"
            label: "Gap from screen edge"
            description: "How far the dock floats above the bottom of the screen."
            from: 0
            to: 64
            stepSize: 1
            value: Dock.edgeGap
            format: v => Math.round(v) + " px"
            fromLabel: "Flush"
            toLabel: "Floating"
            onMoved: v => Dock.setEdgeGap(v)
        }
    }

    // ---- Folder stack --------------------------------------------------------------------
    SettingsSection {
        title: "Folder stack"

        SettingsRow {
            icon: "folder_special"
            label: "Show folder stack"
            description: "Recent files from a folder at the end of the dock. Click to fan them out."
            SettingsSwitch { checked: Dock.showFolder; onToggled: Dock.setShowFolder(!Dock.showFolder) }
        }
        SettingsRow {
            icon: "folder_open"
            label: "Folder"
            description: Dock.folderError ? Dock.folderError : `${Dock.fileTotal} item${Dock.fileTotal === 1 ? "" : "s"}`
            enabled: Dock.showFolder
            opacity: enabled ? 1 : 0.5

            InputField {
                id: folderField
                implicitWidth: 300
                icon: "folder"
                placeholder: Dock.defaultFolder
                text: Dock.folder === Dock.defaultFolder ? "" : Dock.folder
                clearable: false
                monospace: true
                error: Dock.folderError !== ""
                onAccepted: t => Dock.setFolder(t.trim())
            }
            ActionButton {
                style: "text"
                text: "Reset"
                visible: Dock.folder !== Dock.defaultFolder
                onClicked: { folderField.text = ""; Dock.setFolder(""); }
            }
        }
    }

    // ---- Pinned apps ---------------------------------------------------------------------
    SettingsSection {
        id: pinnedSection
        title: "Pinned apps"

        property bool adding: false
        property string query: ""
        readonly property var candidates: adding
            ? Apps.query(query).filter(e => !Dock.isPinned(e.id)).slice(0, 8) : []

        EmptyState {
            visible: Dock.pinned.length === 0
            icon: "keep"
            title: "Nothing pinned yet"
            body: "Add apps below, drag a running app to the left side of the dock, or right-click it and choose “Keep in dock”."
        }

        Repeater {
            model: ScriptModel { values: Dock.pinned }

            Surface {
                id: pinRow
                required property string modelData
                required property int index
                readonly property var entry: Dock.entryFor(modelData)
                readonly property int windows: Dock.windowsFor(modelData).length

                Layout.fillWidth: true
                implicitHeight: 56
                radius: Tokens.radius.m
                base: Theme.surfaceContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space.l
                    anchors.rightMargin: Tokens.space.s
                    spacing: Tokens.space.m

                    StyledText {
                        text: pinRow.index + 1
                        color: Theme.surfaceVariantFg
                        font.pixelSize: Tokens.font.s
                        font.features: { "tnum": 1 }
                        Layout.preferredWidth: 14
                    }
                    AppIcon {
                        size: 32
                        name: Dock.iconFor(pinRow.modelData)
                        opacity: pinRow.entry ? 1 : 0.5
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: pinRow.entry ? pinRow.entry.name : pinRow.modelData
                            font.weight: Font.Medium
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: !pinRow.entry ? `${pinRow.modelData} · not installed`
                                : pinRow.windows ? `${pinRow.modelData} · running` : pinRow.modelData
                            font.pixelSize: Tokens.font.s
                            color: pinRow.entry ? Theme.surfaceVariantFg : Theme.error
                        }
                    }
                    IconButton {
                        icon: "arrow_upward"
                        enabled: pinRow.index > 0
                        opacity: enabled ? 1 : 0.35
                        onClicked: Dock.movePinned(pinRow.modelData, pinRow.index - 1)
                    }
                    IconButton {
                        icon: "arrow_downward"
                        enabled: pinRow.index < Dock.pinned.length - 1
                        opacity: enabled ? 1 : 0.35
                        onClicked: Dock.movePinned(pinRow.modelData, pinRow.index + 1)
                    }
                    IconButton {
                        icon: "close"
                        content: hovered ? Theme.error : Theme.surfaceVariantFg
                        onClicked: Dock.unpin(pinRow.modelData)
                    }
                }
            }
        }

        // Add an app: search field + results.
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Tokens.space.s
            spacing: Tokens.space.s

            ActionButton {
                visible: !pinnedSection.adding
                style: "tonal"
                icon: "add"
                text: "Add app"
                onClicked: {
                    pinnedSection.query = "";
                    pinnedSection.adding = true;
                    Qt.callLater(() => search.focusInput());
                }
            }
            InputField {
                id: search
                visible: pinnedSection.adding
                Layout.fillWidth: true
                icon: "search"
                placeholder: "Search applications"
                onEdited: t => pinnedSection.query = t
                onAccepted: {
                    if (pinnedSection.candidates.length) Dock.pin(pinnedSection.candidates[0].id);
                }
            }
            ActionButton {
                visible: pinnedSection.adding
                style: "text"
                text: "Done"
                onClicked: pinnedSection.adding = false
            }
        }

        Repeater {
            model: pinnedSection.candidates

            Surface {
                id: cand
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Tokens.radius.m
                interactive: true
                base: Theme.alpha(Theme.surfaceContainer, 0)
                onClicked: Dock.pin(modelData.id)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space.l
                    anchors.rightMargin: Tokens.space.l
                    spacing: Tokens.space.m
                    AppIcon { size: 28; name: cand.modelData.icon || "" }
                    StyledText {
                        Layout.fillWidth: true
                        text: cand.modelData.name
                    }
                    Icon { text: "add"; color: Theme.primary }
                }
            }
        }

        StyledText {
            visible: pinnedSection.adding && pinnedSection.candidates.length === 0
            Layout.margins: Tokens.space.m
            text: pinnedSection.query ? `No apps match “${pinnedSection.query}”` : "Every app is already pinned"
            color: Theme.surfaceVariantFg
        }
    }

    StyledText {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font.pixelSize: Tokens.font.s
        color: Theme.surfaceVariantFg
        text: "Tip: drag icons to reorder them, drag a pinned icon up and out to remove it, and middle-click an app to open a new window. "
            + "Shell commands: rice ipc call dock toggle | toggleAutohide | pin <id> | unpin <id>."
    }
}
