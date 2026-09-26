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

    title: "Wallpaper"
    subtitle: "Your wallpaper also seeds the colour scheme of the whole shell."

    readonly property string folder: Settings.data.wallpaperDir || Paths.wallpaperDir
    readonly property string current: Settings.data.wallpaper
    property var images: []
    property bool scanned: false
    property bool folderMissing: false
    property string query: ""
    readonly property var shown: query === "" ? images
        : images.filter(p => baseName(p).toLowerCase().includes(query.toLowerCase()))

    function baseName(p) { return String(p).split("/").pop(); }
    function prettyName(p) { return baseName(p).replace(/\.[^.]+$/, "").replace(/[-_]+/g, " "); }

    function apply(path) {
        if (path && path !== current) Wallpapers.set(path);
    }

    function random() {
        const pool = images.filter(p => p !== current);
        if (pool.length) apply(pool[Math.floor(Math.random() * pool.length)]);
    }

    function rescan() {
        scanner.running = false;
        scanned = false;
        scanner.running = true;
    }

    onFolderChanged: rescan()
    Component.onCompleted: {
        rescan();
        if (current) sources.running = true;
    }

    // ---- Current wallpaper ---------------------------------------------------------
    ClippingRectangle {
        Layout.fillWidth: true
        implicitHeight: 260
        radius: Tokens.radius.xl
        color: Theme.surfaceContainer

        Image {
            id: hero
            anchors.fill: parent
            source: page.current ? "file://" + page.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 1280
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { Anim { duration: Motion.duration.long } }
        }

        EmptyState {
            anchors.centerIn: parent
            width: parent.width
            visible: !page.current || hero.status === Image.Error
            icon: hero.status === Image.Error ? "broken_image" : "wallpaper"
            title: hero.status === Image.Error ? "Can't show the current wallpaper" : "No wallpaper yet"
            body: hero.status === Image.Error ? page.current : "Pick one below or roll a random one."
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 96
            visible: hero.status === Image.Ready
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.6) }
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.space.l
            spacing: Tokens.space.s

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                visible: hero.status === Image.Ready
                StyledText {
                    Layout.fillWidth: true
                    text: page.prettyName(page.current)
                    color: "white"
                    font.pixelSize: Tokens.font.l
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: page.baseName(page.current)
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: Tokens.font.s
                }
            }
            Item { Layout.fillWidth: true; visible: hero.status !== Image.Ready }
            ActionButton {
                icon: "shuffle"
                text: "Random"
                style: "filled"
                enabled: page.images.length > 1 || (page.images.length === 1 && page.images[0] !== page.current)
                onClicked: page.random()
            }
        }
    }

    // ---- Source colour ---------------------------------------------------------------
    SettingsSection {
        title: "Colours"

        SettingsRow {
            icon: "colorize"
            label: "Source colour"
            description: !page.current ? "Set a wallpaper to extract its colours"
                : sources.running ? "Extracting dominant colours…"
                : sources.colors.length === 0 ? "Couldn't extract colours (is matugen installed?)"
                : sources.colors.length === 1 ? "This wallpaper has a single dominant colour"
                : "Which dominant colour of the wallpaper seeds the palette"

            Repeater {
                model: sources.colors

                Rectangle {
                    id: seed
                    required property string modelData
                    required property int index
                    readonly property bool active: Math.min(Settings.data.sourceColorIndex, sources.colors.length - 1) === index

                    implicitWidth: 40
                    implicitHeight: 40
                    radius: active ? Tokens.radius.m : 20
                    color: modelData
                    border.width: active ? 3 : 0
                    border.color: Theme.surfaceFg
                    scale: seedMouse.pressed ? 0.9 : seedMouse.containsMouse ? 1.08 : 1
                    activeFocusOnTab: true
                    Behavior on radius { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }
                    Behavior on scale { Anim { duration: Motion.duration.short } }

                    function choose() {
                        if (Settings.data.sourceColorIndex === index) return;
                        Settings.data.sourceColorIndex = index;
                        Wallpapers.regenerate();
                    }
                    Keys.onSpacePressed: choose()
                    Keys.onReturnPressed: choose()

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: parent.radius + 4
                        color: "transparent"
                        border.width: seed.activeFocus ? 2 : 0
                        border.color: Theme.primary
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: seed.active
                        text: "check"
                        size: 20
                        color: Qt.colorEqual(seed.color, "transparent") ? Theme.surfaceFg
                            : (seed.color.hslLightness > 0.55 ? "black" : "white")
                    }
                    MouseArea {
                        id: seedMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seed.choose()
                    }
                }
            }
        }
    }

    // ---- Library ---------------------------------------------------------------------
    SettingsSection {
        title: "Library"

        SettingsRow {
            icon: "folder"
            label: "Folder"
            description: page.folderMissing ? "This folder doesn't exist"
                : !page.scanned ? "Scanning…"
                : page.images.length + (page.images.length === 1 ? " image" : " images") + " (jpg, png, webp; two levels deep)"

            InputField {
                id: folderField
                implicitWidth: 300
                icon: "folder_open"
                monospace: true
                clearable: false
                error: page.folderMissing
                text: page.folder
                onAccepted: t => {
                    const v = t.trim().replace(/^~(?=\/|$)/, Paths.home).replace(/\/+$/, "");
                    Settings.data.wallpaperDir = (v === Paths.wallpaperDir) ? "" : v;
                    page.rescan();
                }
            }
            IconButton {
                icon: "restart_alt"
                visible: Settings.data.wallpaperDir !== ""
                onClicked: { Settings.data.wallpaperDir = ""; folderField.text = Paths.wallpaperDir; }
            }
            IconButton {
                icon: "refresh"
                onClicked: page.rescan()
            }
        }

        InputField {
            Layout.fillWidth: true
            Layout.margins: Tokens.space.xs
            visible: page.images.length > 8
            icon: "search"
            placeholder: "Filter by name"
            onEdited: t => page.query = t
        }

        // Grid of thumbnails.
        Flow {
            id: grid
            readonly property int cols: Math.max(2, Math.floor((width + spacing) / 220))
            readonly property real cell: (width - spacing * (cols - 1)) / cols

            Layout.fillWidth: true
            Layout.margins: Tokens.space.xs
            visible: page.shown.length > 0
            spacing: Tokens.space.s

            Repeater {
                model: page.shown

                Item {
                    id: thumb
                    required property string modelData
                    required property int index
                    readonly property bool active: modelData === page.current
                    readonly property bool hovered: thumbMouse.containsMouse

                    width: grid.cell
                    height: Math.round(grid.cell * 0.625)
                    activeFocusOnTab: true
                    Keys.onReturnPressed: page.apply(modelData)
                    Keys.onSpacePressed: page.apply(modelData)

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: thumb.active ? Tokens.radius.xl : Tokens.radius.m
                        color: Theme.surfaceHigh
                        Behavior on radius { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }

                        Image {
                            id: img
                            anchors.fill: parent
                            source: "file://" + thumb.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 400
                            sourceSize.height: 250
                            opacity: status === Image.Ready ? 1 : 0
                            scale: thumb.hovered ? 1.06 : 1
                            Behavior on opacity { Anim {} }
                            Behavior on scale { Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.emphasizedDecel } }
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: img.status !== Image.Ready
                            text: img.status === Image.Error ? "broken_image" : "image"
                            size: 28
                            color: Theme.surfaceVariantFg
                            opacity: 0.6
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 36
                            opacity: thumb.hovered || thumb.activeFocus ? 1 : 0
                            Behavior on opacity { Anim { duration: Motion.duration.short } }
                            gradient: Gradient {
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.65) }
                            }
                            StyledText {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.space.m
                                anchors.rightMargin: Tokens.space.m
                                text: page.prettyName(thumb.modelData)
                                color: "white"
                                font.pixelSize: Tokens.font.s
                            }
                        }
                    }

                    // Selection / focus ring drawn outside the clip.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -1
                        radius: (thumb.active ? Tokens.radius.xl : Tokens.radius.m) + 1
                        color: "transparent"
                        border.width: thumb.active ? 3 : thumb.activeFocus ? 2 : 0
                        border.color: Theme.primary
                        Behavior on radius { Anim { duration: Motion.duration.medium } }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Tokens.space.s
                        width: 28; height: 28; radius: 14
                        color: Theme.primary
                        scale: thumb.active ? 1 : 0
                        Behavior on scale { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springFast } }
                        Icon { anchors.centerIn: parent; text: "check"; size: 18; color: Theme.primaryFg }
                    }

                    MouseArea {
                        id: thumbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { thumb.forceActiveFocus(); page.apply(thumb.modelData); }
                    }
                }
            }
        }

        EmptyState {
            visible: page.shown.length === 0
            busy: !page.scanned
            icon: !page.scanned ? "hourglass_top"
                : page.folderMissing ? "folder_off"
                : page.images.length ? "search_off" : "hide_image"
            accent: page.folderMissing ? Theme.error : Theme.primary
            title: !page.scanned ? "Looking for wallpapers…"
                : page.folderMissing ? "Folder not found"
                : page.images.length ? "No matches" : "No images here yet"
            body: !page.scanned ? ""
                : page.folderMissing ? page.folder + " doesn't exist. Create it or choose another folder above."
                : page.images.length ? "Nothing matches “" + page.query + "”."
                : "Drop .jpg, .png or .webp files into " + page.folder + " and press refresh."

            ActionButton {
                visible: page.scanned && page.folderMissing
                style: "tonal"
                icon: "create_new_folder"
                text: "Create folder"
                onClicked: mkdir.running = true
            }
            ActionButton {
                visible: page.scanned && !page.folderMissing && page.images.length === 0
                style: "tonal"
                icon: "refresh"
                text: "Refresh"
                onClicked: page.rescan()
            }
        }
    }

    // ---- processes -------------------------------------------------------------------
    Process {
        id: scanner
        environment: ({ RICE_DIR: page.folder })
        command: ["sh", "-c",
            "[ -d \"$RICE_DIR\" ] || { echo '@@missing'; exit 0; }; "
            + "find -L \"$RICE_DIR\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l);
                page.folderMissing = lines[0] === "@@missing";
                page.images = page.folderMissing ? [] : lines;
                page.scanned = true;
            }
        }
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", page.folder]
        onExited: page.rescan()
    }

    Process {
        id: sources
        property var colors: []
        environment: ({ RICE_WP: page.current })
        command: ["sh", "-c", "[ -f \"$RICE_WP\" ] && matugen image \"$RICE_WP\" --show-source-colors 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: sources.colors = text.split("\n").map(l => l.trim())
                .filter(l => /^#[0-9a-fA-F]{6}$/.test(l)).slice(0, 5)
        }
    }

    Connections {
        target: Settings.data
        function onWallpaperChanged() { sources.running = false; sources.colors = []; sources.running = !!page.current; }
    }
}
