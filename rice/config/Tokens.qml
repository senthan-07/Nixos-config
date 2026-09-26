pragma Singleton

import QtQuick
import Quickshell

// Static layout tokens in logical pixels.
Singleton {
    readonly property QtObject space: QtObject {
        readonly property int xxs: 2
        readonly property int xs: 4
        readonly property int s: 8
        readonly property int m: 12
        readonly property int l: 16
        readonly property int xl: 24
        readonly property int xxl: 32
    }

    readonly property QtObject radius: QtObject {
        readonly property int xs: 6
        readonly property int s: 10
        readonly property int m: 16
        readonly property int l: 22
        readonly property int xl: 28
        readonly property int full: 999
    }

    readonly property QtObject font: QtObject {
        readonly property string sans: Settings.data.uiFont || "Inter"
        readonly property string mono: "JetBrainsMono Nerd Font"
        readonly property string icons: "Material Symbols Rounded"

        readonly property int xs: 10
        readonly property int s: 12
        readonly property int m: 13
        readonly property int l: 15
        readonly property int xl: 18
        readonly property int xxl: 24
        readonly property int display: 96
    }

    readonly property QtObject bar: QtObject {
        readonly property int height: 40
        readonly property int gap: 6        // distance from screen edge when floating
        readonly property int chipHeight: 30
    }

    readonly property int sidebarWidth: 420
    readonly property int launcherWidth: 620
    readonly property int notificationWidth: 380
}
