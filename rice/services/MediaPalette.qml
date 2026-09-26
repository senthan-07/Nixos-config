pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Colours picked from the active track's album art with ColorQuantizer, then
// nudged into readable Material-style roles for the current light/dark mode.
// Remote art (http/https) is downloaded to $XDG_RUNTIME_DIR first because the
// quantizer only reads local files.
Singleton {
    id: root

    readonly property string artUrl: Media.active?.trackArtUrl ?? ""
    readonly property bool dark: Theme.dark

    // Raw picks from the image.
    property color dominant: Theme.primary
    property color vibrant: Theme.primary
    property bool available: false

    // Derived roles (fall back to the shell theme when no art is available).
    readonly property color accent: available ? tone(vibrant, dark ? 0.74 : 0.40, 0.55) : Theme.primary
    readonly property color accentFg: available ? tone(vibrant, dark ? 0.16 : 0.98, 0.5) : Theme.primaryFg
    readonly property color container: available ? tone(dominant, dark ? 0.24 : 0.88, 0.35) : Theme.secondaryContainer
    readonly property color containerFg: available ? tone(dominant, dark ? 0.92 : 0.12, 0.25) : Theme.secondaryContainerFg
    readonly property color track: available ? Theme.alpha(accent, 0.24) : Theme.alpha(Theme.surfaceFg, 0.16)
    // A surface lightly washed with the art colour, for large backgrounds.
    readonly property color surface: available ? Qt.tint(Theme.surfaceContainer, Theme.alpha(dominant, dark ? 0.22 : 0.16)) : Theme.surfaceContainer

    readonly property string cacheDir: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/rice-art`
    property string localSource: ""

    // Re-tone a colour to lightness `l` and cap its saturation at `maxS`.
    function tone(c, l, maxS) {
        const hsl = c;
        const s = Math.min(maxS, Math.max(0.18, hsl.hslSaturation));
        return Qt.hsla(Math.max(0, hsl.hslHue), s, l, 1);
    }

    function hash(s) {
        let h = 5381;
        for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
        return (h >>> 0).toString(16);
    }

    function resolve() {
        const url = artUrl;
        if (!url) { localSource = ""; available = false; return; }
        if (/^https?:\/\//.test(url)) {
            const path = `${cacheDir}/${hash(url)}`;
            fetcher.target = path;
            fetcher.command = ["sh", "-c", 'mkdir -p "$1" && { [ -s "$2" ] || curl -fsSL --max-time 10 -o "$2.part" "$3" && mv "$2.part" "$2"; }',
                "sh", cacheDir, path, url];
            fetcher.running = false;
            fetcher.running = true;
        } else {
            localSource = url;
        }
    }

    function pick(colors) {
        if (!colors || !colors.length) { available = false; return; }
        let best = null, bestScore = -1;
        let dom = null, domScore = -1;
        for (const c of colors) {
            const s = c.hsvSaturation, v = c.hsvValue, l = c.hslLightness;
            // Vibrant: saturated and not too dark/light.
            const vib = s * (1 - Math.abs(v - 0.8)) * (l > 0.08 && l < 0.92 ? 1 : 0.2);
            if (vib > bestScore) { bestScore = vib; best = c; }
            // Dominant-ish: mid-tone, prefer some colour over pure greys.
            const d = (1 - Math.abs(l - 0.45)) * (0.4 + s);
            if (d > domScore) { domScore = d; dom = c; }
        }
        vibrant = bestScore > 0.05 ? best : dom;
        dominant = dom;
        available = true;
    }

    onArtUrlChanged: resolve()
    Component.onCompleted: resolve()

    Process {
        id: fetcher
        property string target
        onExited: code => {
            if (code === 0) root.localSource = "file://" + target;
            else root.available = false;
        }
    }

    ColorQuantizer {
        id: quantizer
        source: root.localSource
        depth: 3
        rescaleSize: 64
        onColorsChanged: root.pick(colors)
    }
}
