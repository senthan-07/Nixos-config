import QtQuick
import QtQuick.Layouts
import qs.modules.settings
import "../widgets"
import qs.components
import qs.services
// qs.config last: its `Settings` singleton must win over modules/settings/Settings.qml.
import qs.config

SettingsPage {
    id: page

    title: "Bar"
    subtitle: "Where the bar sits, how it looks and which modules it shows."

    readonly property bool atTop: Settings.data.barPosition !== "bottom"
    readonly property bool isFloating: Settings.data.floatingBar

    component Pill: Rectangle {
        property bool shown: true
        implicitHeight: 18
        radius: 9
        color: Theme.surfaceContainer
        visible: opacity > 0
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.6
        Behavior on opacity { Anim { duration: Motion.duration.short } }
        Behavior on scale { Anim { duration: Motion.duration.short } }
    }

    // ---- Live preview ------------------------------------------------------
    Rectangle {
        id: preview
        Layout.fillWidth: true
        implicitHeight: 320
        radius: Tokens.radius.xl
        color: Theme.surfaceLow
        clip: true

        // Miniature desktop: wallpaper (or a tonal gradient) with the bar drawn over it.
        Rectangle {
            id: screen
            anchors.centerIn: parent
            height: parent.height - Tokens.space.l * 2
            width: Math.min(parent.width - Tokens.space.l * 2, height * 16 / 9)
            radius: Tokens.radius.l
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.primaryContainer }
                GradientStop { position: 1; color: Theme.tertiaryContainer }
            }

            Image {
                anchors.fill: parent
                source: Settings.data.wallpaper ? "file://" + Settings.data.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 960
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { Anim {} }
            }

            // A pretend window so docked vs floating reads clearly.
            Rectangle {
                x: parent.width * 0.18
                width: parent.width * 0.64
                y: page.atTop ? bar.y + bar.height + 14 : 14
                height: parent.height - bar.height - 28 - (page.isFloating ? 6 : 0)
                radius: Tokens.radius.m
                color: Theme.alpha(Theme.surface, 0.92)
                border.width: 1
                border.color: Theme.alpha(Theme.outlineVariant, 0.6)
                Behavior on y { Anim { easing.bezierCurve: Motion.curve.emphasizedDecel } }

                Row {
                    x: 12; y: 10
                    spacing: 6
                    Repeater {
                        model: 3
                        Rectangle { width: 9; height: 9; radius: 5; color: Theme.outlineVariant }
                    }
                }
                Column {
                    x: 16; y: 34
                    spacing: 8
                    Repeater {
                        model: [0.55, 0.8, 0.4, 0.7]
                        Rectangle {
                            required property real modelData
                            width: (parent.parent.width - 32) * modelData
                            height: 8
                            radius: 4
                            color: Theme.alpha(Theme.surfaceVariantFg, 0.25)
                        }
                    }
                }
            }

            Rectangle {
                id: bar
                readonly property int gap: page.isFloating ? 8 : 0
                x: gap * 1.5
                width: parent.width - gap * 3
                height: 30
                y: page.atTop ? gap : parent.height - height - gap
                radius: page.isFloating ? Tokens.radius.m : 0
                color: Theme.alpha(Theme.surface, Settings.data.surfaceOpacity)
                border.width: page.isFloating ? 1 : 0
                border.color: Theme.alpha(Theme.outlineVariant, 0.5)

                Behavior on y { Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.emphasizedDecel } }
                Behavior on x { Anim {} }
                Behavior on width { Anim {} }
                Behavior on radius { Anim {} }

                RowLayout {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Rectangle { implicitWidth: 18; implicitHeight: 18; radius: 9; color: Theme.primaryContainer }
                    Pill {
                        implicitWidth: 52
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle { width: 16; height: 8; radius: 4; color: Theme.primary }
                            Repeater { model: 3; Rectangle { width: 5; height: 5; radius: 3; y: 1.5; color: Theme.outline } }
                        }
                    }
                    Pill {
                        shown: Settings.data.barShowWindowTitle
                        implicitWidth: shown ? 70 : 0
                        color: "transparent"
                        Behavior on implicitWidth { Anim { duration: Motion.duration.short } }
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Theme.alpha(Theme.surfaceFg, 0.35) }
                    }
                }

                Pill {
                    anchors.centerIn: parent
                    implicitWidth: 64
                    StyledText {
                        anchors.centerIn: parent
                        text: Time.format("HH:mm")
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }

                RowLayout {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Pill {
                        shown: Settings.data.barShowMedia
                        implicitWidth: shown ? 58 : 0
                        color: Theme.secondaryContainer
                        Behavior on implicitWidth { Anim { duration: Motion.duration.short } }
                        Icon { x: 4; anchors.verticalCenter: parent.verticalCenter; text: "music_note"; size: 11; color: Theme.secondaryContainerFg }
                    }
                    Pill {
                        shown: Settings.data.barShowResources
                        implicitWidth: shown ? 52 : 0
                        Behavior on implicitWidth { Anim { duration: Motion.duration.short } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 3
                            Repeater {
                                model: 3
                                Rectangle { width: 11; height: 11; radius: 6; color: "transparent"; border.width: 2; border.color: Theme.primary }
                            }
                        }
                    }
                    Pill {
                        shown: Settings.data.barShowTray
                        implicitWidth: shown ? 40 : 0
                        color: "transparent"
                        Behavior on implicitWidth { Anim { duration: Motion.duration.short } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Repeater { model: 3; Rectangle { width: 9; height: 9; radius: 3; color: Theme.outline } }
                        }
                    }
                    Pill {
                        implicitWidth: 44
                        Row {
                            anchors.centerIn: parent
                            spacing: 3
                            Repeater { model: 3; Rectangle { width: 7; height: 7; radius: 4; color: Theme.surfaceVariantFg } }
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.left: screen.right
            anchors.leftMargin: Tokens.space.m
            anchors.bottom: screen.bottom
            visible: (preview.width - screen.width) / 2 > implicitWidth + Tokens.space.xl
            implicitWidth: tag.implicitWidth + Tokens.space.m * 2
            implicitHeight: 24
            radius: 12
            color: Theme.alpha(Theme.inverseSurface, 0.85)
            StyledText {
                id: tag
                anchors.centerIn: parent
                text: "Preview"
                color: Theme.inverseOnSurface
                font.pixelSize: Tokens.font.xs
                font.weight: Font.DemiBold
            }
        }
    }

    // ---- Layout ------------------------------------------------------------
    SettingsSection {
        title: "Layout"

        SettingsRow {
            icon: page.atTop ? "vertical_align_top" : "vertical_align_bottom"
            label: "Position"
            description: "Screen edge the bar is attached to"
            SegmentedButtons {
                model: [
                    { value: "top", label: "Top", icon: "vertical_align_top" },
                    { value: "bottom", label: "Bottom", icon: "vertical_align_bottom" }
                ]
                value: page.atTop ? "top" : "bottom"
                onActivated: v => Settings.data.barPosition = v
            }
        }

        SettingsRow {
            icon: page.isFloating ? "rounded_corner" : "crop_square"
            label: "Style"
            description: page.isFloating ? "Detached, rounded island with a gap to the screen edge"
                : "Full-width strip flush with the screen edge"
            SegmentedButtons {
                model: [
                    { value: true, label: "Floating", icon: "rounded_corner" },
                    { value: false, label: "Docked", icon: "crop_square" }
                ]
                value: page.isFloating
                onActivated: v => Settings.data.floatingBar = v
            }
        }
    }

    // ---- Modules -----------------------------------------------------------
    SettingsSection {
        title: "Modules"

        SettingsRow {
            icon: "title"
            label: "Window title"
            description: "App icon and title of the focused window"
            SettingsSwitch {
                checked: Settings.data.barShowWindowTitle
                onToggled: Settings.data.barShowWindowTitle = !checked
            }
        }
        SettingsRow {
            icon: "music_note"
            label: "Media"
            description: "Now playing, with play/pause on click"
            SettingsSwitch {
                checked: Settings.data.barShowMedia
                onToggled: Settings.data.barShowMedia = !checked
            }
        }
        SettingsRow {
            icon: "memory"
            label: "Resources"
            description: "CPU, memory and temperature rings"
            SettingsSwitch {
                checked: Settings.data.barShowResources
                onToggled: Settings.data.barShowResources = !checked
            }
        }
        SettingsRow {
            icon: "apps"
            label: "System tray"
            description: "Status icons from background apps"
            SettingsSwitch {
                checked: Settings.data.barShowTray
                onToggled: Settings.data.barShowTray = !checked
            }
        }
        SettingsRow {
            icon: "lock"
            label: "Workspaces, clock and status"
            description: "Always shown"
            opacity: 0.7
        }
    }
}
