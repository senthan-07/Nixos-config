pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Material 3 colour roles. Values come from a matugen-generated scheme
// (see services/Wallpapers.qml); until one exists a built-in violet seed is used.
Singleton {
    id: root

    readonly property bool dark: Settings.data.darkMode

    // role -> [dark, light]
    readonly property var fallback: ({
        primary: ["#c9beff", "#605790"],
        on_primary: ["#31285f", "#ffffff"],
        primary_container: ["#483f77", "#e6deff"],
        on_primary_container: ["#e6deff", "#1c1149"],
        secondary: ["#c9c3dc", "#605c71"],
        on_secondary: ["#312e41", "#ffffff"],
        secondary_container: ["#484459", "#e6dff9"],
        on_secondary_container: ["#e6dff9", "#1c192b"],
        tertiary: ["#edb8cd", "#7c5264"],
        on_tertiary: ["#482535", "#ffffff"],
        tertiary_container: ["#623b4c", "#ffd8e6"],
        on_tertiary_container: ["#ffd8e6", "#301120"],
        error: ["#ffb4ab", "#ba1a1a"],
        on_error: ["#690005", "#ffffff"],
        error_container: ["#93000a", "#ffdad6"],
        on_error_container: ["#ffdad6", "#410002"],
        surface: ["#141318", "#fdf8ff"],
        on_surface: ["#e5e1e9", "#1c1b20"],
        on_surface_variant: ["#c9c5d0", "#48454e"],
        surface_container_lowest: ["#0e0d13", "#ffffff"],
        surface_container_low: ["#1c1b20", "#f7f2fa"],
        surface_container: ["#201f25", "#f1ecf4"],
        surface_container_high: ["#2b292f", "#ebe6ee"],
        surface_container_highest: ["#36343a", "#e5e1e9"],
        surface_bright: ["#3a383e", "#fdf8ff"],
        surface_dim: ["#141318", "#ddd8e0"],
        outline: ["#938f99", "#79757f"],
        outline_variant: ["#48454e", "#c9c5d0"],
        shadow: ["#000000", "#000000"],
        scrim: ["#000000", "#000000"],
        inverse_surface: ["#e5e1e9", "#312f36"],
        inverse_on_surface: ["#312f36", "#f4eff7"],
        inverse_primary: ["#605790", "#c9beff"]
    })

    // Generated scheme, same shape as `fallback`.
    property var generated: ({})

    function role(name) {
        const entry = generated[name] || fallback[name];
        return entry[dark ? 0 : 1];
    }

    readonly property color primary: role("primary")
    readonly property color primaryFg: role("on_primary")
    readonly property color primaryContainer: role("primary_container")
    readonly property color primaryContainerFg: role("on_primary_container")
    readonly property color secondary: role("secondary")
    readonly property color secondaryFg: role("on_secondary")
    readonly property color secondaryContainer: role("secondary_container")
    readonly property color secondaryContainerFg: role("on_secondary_container")
    readonly property color tertiary: role("tertiary")
    readonly property color tertiaryFg: role("on_tertiary")
    readonly property color tertiaryContainer: role("tertiary_container")
    readonly property color tertiaryContainerFg: role("on_tertiary_container")
    readonly property color error: role("error")
    readonly property color errorFg: role("on_error")
    readonly property color errorContainer: role("error_container")
    readonly property color errorContainerFg: role("on_error_container")
    readonly property color surface: role("surface")
    readonly property color surfaceFg: role("on_surface")
    readonly property color surfaceVariantFg: role("on_surface_variant")
    readonly property color surfaceLowest: role("surface_container_lowest")
    readonly property color surfaceLow: role("surface_container_low")
    readonly property color surfaceContainer: role("surface_container")
    readonly property color surfaceHigh: role("surface_container_high")
    readonly property color surfaceHighest: role("surface_container_highest")
    readonly property color surfaceBright: role("surface_bright")
    readonly property color surfaceDim: role("surface_dim")
    readonly property color outline: role("outline")
    readonly property color outlineVariant: role("outline_variant")
    readonly property color shadow: role("shadow")
    readonly property color scrim: role("scrim")
    readonly property color inverseSurface: role("inverse_surface")
    readonly property color inverseOnSurface: role("inverse_on_surface")
    readonly property color inversePrimary: role("inverse_primary")

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // M3 state layers: hover 8%, press 10%, drag 16%.
    function stateLayer(base, content, hovered, pressed) {
        const amount = pressed ? 0.12 : hovered ? 0.08 : 0;
        return Qt.tint(base, alpha(content, amount));
    }

    function applyMatugen(json) {
        const colors = json.colors || {};
        const out = {};
        for (const name in fallback) {
            const c = colors[name];
            if (c && c.dark && c.light)
                out[name] = [c.dark.color, c.light.color];
        }
        saveScheme(out);
    }

    FileView {
        id: schemeFile
        path: Paths.schemeFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.generated = JSON.parse(text());
            } catch (e) {
                console.warn("rice: bad scheme file", e);
            }
        }
    }

    function saveScheme(scheme) {
        generated = scheme;
        schemeFile.setText(JSON.stringify(scheme, null, 2));
    }
}
