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

    title: "Appearance"
    subtitle: "Light or dark, how colours are derived from your wallpaper, and surface transparency."

    readonly property var schemes: [
        { value: "scheme-tonal-spot", label: "Tonal spot", hint: "Calm and balanced; the Android default" },
        { value: "scheme-content", label: "Content", hint: "Stays close to the wallpaper's colours" },
        { value: "scheme-expressive", label: "Expressive", hint: "Playful, hue-shifted accents" },
        { value: "scheme-fidelity", label: "Fidelity", hint: "Faithful to the source colour" },
        { value: "scheme-fruit-salad", label: "Fruit salad", hint: "Bold rotation across hues" },
        { value: "scheme-rainbow", label: "Rainbow", hint: "Chromatic accents, neutral surfaces" },
        { value: "scheme-vibrant", label: "Vibrant", hint: "Maximum colourfulness" },
        { value: "scheme-neutral", label: "Neutral", hint: "Barely tinted greys" },
        { value: "scheme-monochrome", label: "Monochrome", hint: "Pure greyscale" },
        { value: "scheme-smart", label: "Smart", hint: "Adapts to the wallpaper automatically" }
    ]

    // role -> colour for a given mode, straight from the active scheme.
    function roleFor(name, dark) {
        const entry = Theme.generated[name] || Theme.fallback[name];
        return entry[dark ? 0 : 1];
    }

    // ---- Theme mode ------------------------------------------------------------
    component ModeCard: Surface {
        id: card
        required property bool dark
        required property string label
        readonly property bool active: Settings.data.darkMode === dark
        function c(n) { return page.roleFor(n, dark); }

        Layout.fillWidth: true
        implicitHeight: 196
        radius: Tokens.radius.l
        interactive: true
        activeFocusOnTab: true
        base: active ? Theme.primary : Theme.surfaceHigh
        content: active ? Theme.primaryFg : Theme.surfaceFg
        scale: pressed ? 0.98 : 1
        Behavior on scale { Anim { duration: Motion.duration.tiny } }
        onClicked: Settings.data.darkMode = dark
        Keys.onSpacePressed: Settings.data.darkMode = dark

        // Miniature shell drawn in that mode's colours.
        Rectangle {
            id: mock
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.space.m
            height: parent.height - 52
            radius: Tokens.radius.m
            color: card.c("surface")
            clip: true

            Rectangle {
                x: 10; y: 10
                width: parent.width - 20; height: 18; radius: 9
                color: card.c("surface_container")
                Rectangle { x: 4; y: 4; width: 10; height: 10; radius: 5; color: card.c("primary") }
                Rectangle { x: 20; y: 6; width: 30; height: 6; radius: 3; color: card.c("secondary_container") }
                Rectangle { anchors.centerIn: parent; width: 36; height: 8; radius: 4; color: card.c("on_surface_variant"); opacity: 0.6 }
            }
            Rectangle {
                x: 10; y: 36
                width: parent.width * 0.42; height: parent.height - 46; radius: Tokens.radius.s
                color: card.c("surface_container_high")
                Column {
                    x: 8; y: 8; spacing: 6
                    Rectangle { width: 26; height: 26; radius: 13; color: card.c("primary_container") }
                    Rectangle { width: mock.width * 0.3; height: 6; radius: 3; color: card.c("on_surface"); opacity: 0.7 }
                    Rectangle { width: mock.width * 0.2; height: 6; radius: 3; color: card.c("on_surface_variant"); opacity: 0.5 }
                }
            }
            Column {
                x: parent.width * 0.42 + 20; y: 40; spacing: 8
                Repeater {
                    model: ["primary", "tertiary", "secondary"]
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: (mock.width * 0.5 - 12) * (1 - index * 0.2); height: 12; radius: 6
                        color: card.c(modelData)
                    }
                }
                Rectangle { width: 44; height: 22; radius: 11; color: card.c("primary")
                    Rectangle { anchors.centerIn: parent; width: 20; height: 5; radius: 3; color: card.c("on_primary") }
                }
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.space.m
            height: 28
            spacing: Tokens.space.s

            Icon {
                text: card.active ? "check_circle" : (card.dark ? "dark_mode" : "light_mode")
                fill: card.active ? 1 : 0
                color: card.content
            }
            StyledText {
                Layout.fillWidth: true
                text: card.label
                color: card.content
                font.weight: Font.DemiBold
            }
        }
    }

    SettingsSection {
        title: "Mode"

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Tokens.space.xs
            spacing: Tokens.space.m
            ModeCard { dark: false; label: "Light" }
            ModeCard { dark: true; label: "Dark" }
        }
    }

    // ---- Scheme type -------------------------------------------------------
    SettingsSection {
        title: "Colour scheme"

        SettingsRow {
            icon: "palette"
            label: "Scheme style"
            description: !Settings.data.wallpaper ? "Pick a wallpaper first; colours are generated from it."
                : previews.running ? "Generating previews…"
                : previews.failed ? "matugen failed; is it installed?"
                : "matugen scheme type applied to the whole shell"
            ActionButton {
                style: "text"
                icon: "refresh"
                text: "Regenerate"
                enabled: !!Settings.data.wallpaper
                onClicked: { Wallpapers.regenerate(); previews.refresh(); }
            }
        }

        GridLayout {
            id: schemeGrid
            Layout.fillWidth: true
            Layout.margins: Tokens.space.xs
            columns: width >= 700 ? 5 : 2
            rowSpacing: Tokens.space.s
            columnSpacing: Tokens.space.s

            Repeater {
                model: page.schemes

                Surface {
                    id: tile
                    required property var modelData
                    readonly property bool active: Settings.data.scheme === modelData.value
                    readonly property var colors: previews.results[modelData.value] || null

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 104
                    radius: active ? Tokens.radius.xl : Tokens.radius.m
                    interactive: true
                    activeFocusOnTab: true
                    base: active ? Theme.secondaryContainer : Theme.surfaceHigh
                    content: active ? Theme.secondaryContainerFg : Theme.surfaceFg
                    border.width: active || activeFocus ? 2 : 0
                    border.color: Theme.primary
                    Behavior on radius { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }

                    function choose() {
                        if (active) return;
                        Settings.data.scheme = modelData.value;
                        Wallpapers.regenerate();
                    }
                    onClicked: choose()
                    Keys.onSpacePressed: choose()
                    Keys.onReturnPressed: choose()

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.space.m
                        spacing: Tokens.space.xs

                        // Four-colour flower: primary, secondary, tertiary, surface.
                        RowLayout {
                            spacing: -6
                            Repeater {
                                model: ["primary", "secondary", "tertiary", "primary_container"]
                                Rectangle {
                                    required property string modelData
                                    required property int index
                                    z: 4 - index
                                    implicitWidth: 26; implicitHeight: 26; radius: 13
                                    border.width: 2
                                    border.color: tile.color
                                    color: tile.colors ? tile.colors[modelData] : Theme.alpha(Theme.outline, 0.25)
                                    Behavior on color { ColorAnim { duration: Motion.duration.medium } }
                                    SequentialAnimation on opacity {
                                        running: !tile.colors && previews.running
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.35; duration: 500 }
                                        NumberAnimation { to: 1; duration: 500 }
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Icon {
                                visible: tile.active
                                text: "check_circle"
                                fill: 1
                                color: Theme.primary
                            }
                        }
                        Item { Layout.fillHeight: true }
                        StyledText {
                            Layout.fillWidth: true
                            text: tile.modelData.label
                            color: tile.content
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: tile.modelData.hint
                            color: Theme.surfaceVariantFg
                            font.pixelSize: Tokens.font.xs
                        }
                    }
                }
            }
        }

        SliderRow {
            icon: "contrast"
            label: "Contrast"
            description: "Tone separation between colour roles"
            from: -1; to: 1; stepSize: 0.1
            value: Settings.data.schemeContrast
            format: v => Math.abs(v) < 0.05 ? "Standard" : (v > 0 ? "+" : "") + Math.round(v * 100) + "%"
            fromLabel: "Softer"
            toLabel: "Crisper"
            onMoved: v => {
                Settings.data.schemeContrast = Math.round(v * 10) / 10;
                Wallpapers.regenerate();
                previews.refresh();
            }
        }
    }

    // ---- Palette -------------------------------------------------------------
    SettingsSection {
        title: "Current palette"

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.space.m
            Layout.topMargin: Tokens.space.xs
            text: "Material 3 colour roles in use right now. Click a swatch to copy its hex value."
            color: Theme.surfaceVariantFg
            font.pixelSize: Tokens.font.s
            wrapMode: Text.Wrap
        }

        Repeater {
            model: [
                { name: "Accent", roles: [["primary", "primary", "primaryFg"], ["on primary", "primaryFg", "primary"],
                    ["primary container", "primaryContainer", "primaryContainerFg"], ["on primary container", "primaryContainerFg", "primaryContainer"]] },
                { name: "", roles: [["secondary", "secondary", "secondaryFg"], ["secondary container", "secondaryContainer", "secondaryContainerFg"],
                    ["tertiary", "tertiary", "tertiaryFg"], ["tertiary container", "tertiaryContainer", "tertiaryContainerFg"]] },
                { name: "Surfaces", roles: [["surface dim", "surfaceDim", "surfaceFg"], ["surface", "surface", "surfaceFg"],
                    ["container low", "surfaceLow", "surfaceFg"], ["container", "surfaceContainer", "surfaceFg"],
                    ["container high", "surfaceHigh", "surfaceFg"], ["container highest", "surfaceHighest", "surfaceFg"]] },
                { name: "", roles: [["error", "error", "errorFg"], ["error container", "errorContainer", "errorContainerFg"],
                    ["outline", "outline", "surface"], ["outline variant", "outlineVariant", "surfaceFg"],
                    ["inverse surface", "inverseSurface", "inverseOnSurface"], ["inverse primary", "inversePrimary", "surface"]] }
            ]

            RowLayout {
                id: swatchRow
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.space.xs
                Layout.rightMargin: Tokens.space.xs
                spacing: 3

                Repeater {
                    model: swatchRow.modelData.roles

                    Rectangle {
                        id: swatch
                        required property var modelData
                        required property int index
                        readonly property color fill: Theme[modelData[1]]
                        readonly property color ink: Theme[modelData[2]]
                        readonly property bool first: index === 0
                        readonly property bool last: index === swatchRow.modelData.roles.length - 1

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 64
                        topLeftRadius: first ? Tokens.radius.m : Tokens.radius.xs
                        bottomLeftRadius: first ? Tokens.radius.m : Tokens.radius.xs
                        topRightRadius: last ? Tokens.radius.m : Tokens.radius.xs
                        bottomRightRadius: last ? Tokens.radius.m : Tokens.radius.xs
                        color: fill
                        border.width: swatchMouse.containsMouse ? 2 : 0
                        border.color: Theme.primary
                        Behavior on color { ColorAnim {} }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.space.s
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: swatch.modelData[0]
                                color: swatch.ink
                                font.pixelSize: Tokens.font.xs
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                            }
                            Item { Layout.fillHeight: true }
                            StyledText {
                                Layout.fillWidth: true
                                text: String(swatch.fill).toUpperCase()
                                color: swatch.ink
                                opacity: 0.8
                                font.family: Tokens.font.mono
                                font.pixelSize: Tokens.font.xs
                            }
                        }

                        MouseArea {
                            id: swatchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.copy(String(swatch.fill))
                        }
                    }
                }
            }
        }

        Item { implicitHeight: Tokens.space.xs }
    }

    // ---- Transparency --------------------------------------------------------
    SettingsSection {
        title: "Surfaces"

        SliderRow {
            icon: "opacity"
            label: "Bar and panel opacity"
            description: "Background opacity of the bar, sidebar, launcher and menus"
            from: 0.5; to: 1; stepSize: 0.05
            value: Settings.data.surfaceOpacity
            format: v => Math.round(v * 100) + "%"
            fromLabel: "See-through"
            toLabel: "Solid"
            onMoved: v => Settings.data.surfaceOpacity = Math.round(v * 100) / 100
        }
    }

    // ---- Copy feedback ----------------------------------------------------------
    function copy(hex) {
        Quickshell.clipboardText = hex;
        snack.text = "Copied " + hex.toUpperCase();
        snack.shown = true;
        snackTimer.restart();
    }

    Timer {
        id: snackTimer
        interval: 1800
        onTriggered: snack.shown = false
    }

    Rectangle {
        id: snack
        property alias text: snackText.text
        property bool shown: false
        // Parent to the Flickable itself (not its content) so it stays put while scrolling.
        parent: page
        anchors.horizontalCenter: parent.horizontalCenter
        y: shown ? page.height - height - Tokens.space.xl : page.height + Tokens.space.s
        z: 10
        implicitWidth: snackText.implicitWidth + Tokens.space.xl * 2
        implicitHeight: 44
        radius: Tokens.radius.s
        color: Theme.inverseSurface
        opacity: shown ? 1 : 0
        Behavior on y { Anim { easing.bezierCurve: Motion.curve.emphasizedDecel } }
        Behavior on opacity { Anim { duration: Motion.duration.short } }

        StyledText {
            id: snackText
            anchors.centerIn: parent
            color: Theme.inverseOnSurface
            font.weight: Font.Medium
        }
    }

    // ---- Scheme previews (one matugen dry-run per scheme type) ---------------------
    Process {
        id: previews

        property var results: ({})
        property bool failed: false
        property string key: ""

        function refresh() {
            const wp = Settings.data.wallpaper;
            if (!wp) { results = {}; return; }
            const k = [wp, Settings.data.darkMode, Settings.data.sourceColorIndex, Settings.data.schemeContrast].join("|");
            if (k === key && (running || Object.keys(results).length)) return;
            key = k;
            running = false;
            debounce.restart();
        }

        environment: ({
            RICE_WP: Settings.data.wallpaper,
            RICE_MODE: Settings.data.darkMode ? "dark" : "light",
            RICE_IDX: String(Settings.data.sourceColorIndex),
            RICE_CONTRAST: String(Settings.data.schemeContrast),
            RICE_SCHEMES: page.schemes.map(s => s.value).join(" ")
        })
        command: ["sh", "-c",
            "for t in $RICE_SCHEMES; do echo \"@@$t\"; "
            + "matugen image \"$RICE_WP\" --json hex --dry-run -q -m \"$RICE_MODE\" -t \"$t\" --contrast \"$RICE_CONTRAST\" --source-color-index \"$RICE_IDX\" 2>/dev/null "
            + "|| matugen image \"$RICE_WP\" --json hex --dry-run -q -m \"$RICE_MODE\" -t \"$t\" --contrast \"$RICE_CONTRAST\" --source-color-index 0 2>/dev/null; echo; done"]
        stdout: SplitParser {
            splitMarker: "@@"
            onRead: chunk => {
                const nl = chunk.indexOf("\n");
                if (nl < 0) return;
                const name = chunk.slice(0, nl).trim();
                try {
                    const colors = JSON.parse(chunk.slice(nl + 1)).colors;
                    const mode = Settings.data.darkMode ? "dark" : "light";
                    const pick = {};
                    for (const r of ["primary", "secondary", "tertiary", "primary_container"])
                        pick[r] = colors[r][mode].color;
                    const next = Object.assign({}, previews.results);
                    next[name] = pick;
                    previews.results = next;
                } catch (e) {
                    previews.failed = true;
                }
            }
        }
        onStarted: { failed = false; results = {}; }
    }

    Timer {
        id: debounce
        interval: 250
        onTriggered: previews.running = true
    }

    Connections {
        target: Settings.data
        function onWallpaperChanged() { previews.refresh(); }
        function onDarkModeChanged() { previews.refresh(); }
        function onSourceColorIndexChanged() { previews.refresh(); }
    }

    Component.onCompleted: previews.refresh()
}
