pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User preferences, persisted as JSON under $XDG_STATE_HOME/rice.
Singleton {
    id: root

    property alias data: adapter

    Process {
        running: true
        command: ["mkdir", "-p", Paths.state]
        onExited: file.reload()
    }

    FileView {
        id: file
        path: Paths.settingsFile
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property string wallpaper: ""
            property bool darkMode: true
            // Any matugen scheme: scheme-tonal-spot, scheme-expressive, scheme-vibrant, ...
            property string scheme: "scheme-tonal-spot"
            property bool doNotDisturb: false
            property bool floatingBar: true
            property bool showSeconds: false
            property bool use24h: true
            property string terminal: "kitty"

            // --- Added by the settings app (modules/settings/pages) ---
            // UI font family for all text (Tokens.font.sans should follow it).
            property string uiFont: "Inter"
            // Qt date format used by the bar/sidebar date (Time.date should follow it).
            property string dateFormat: "ddd, d MMM"
            // Multiplier for Motion.duration.*: 0 = animations off, 0.5 fast, 1 normal, 1.5 relaxed.
            property real animationScale: 1
            // Bar placement: "top" | "bottom".
            property string barPosition: "top"
            // Per-module bar visibility.
            property bool barShowWindowTitle: true
            property bool barShowMedia: true
            property bool barShowResources: true
            property bool barShowTray: true
            // Background opacity of the bar and panels (sidebar, launcher, menus), 0.5..1.
            property real surfaceOpacity: 0.9
            // Wallpaper folder; "" = Paths.wallpaperDir (~/Pictures/Wallpapers).
            property string wallpaperDir: ""
            // Which of the wallpaper's dominant colours seeds the scheme (matugen --source-color-index).
            property int sourceColorIndex: 0
            // matugen --contrast, -1..1 (0 = standard).
            property real schemeContrast: 0
        }
    }
}
