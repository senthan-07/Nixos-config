pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Launcher layout, colour and motion constants.
Singleton {
    // Search pill and mode rail
    readonly property int searchWidth: 860
    readonly property int searchHeight: 60
    readonly property int railButton: 60
    readonly property int railGap: 10
    readonly property int bleed: 28                 // room for the shadow around shapes

    // Results panel
    readonly property int panelGap: 12
    readonly property int panelPadding: 10
    readonly property int panelRadius: Tokens.radius.xl
    readonly property int listMaxHeight: 468
    readonly property int rowHeight: 58
    readonly property int subRowHeight: 46
    readonly property int headerHeight: 32
    readonly property int iconSize: 38
    readonly property int footerHeight: 40
    readonly property int answerHeight: 112

    readonly property int gridWidth: 920
    readonly property int gridCell: 128
    readonly property int gridCellHeight: 118
    readonly property int wallWidth: 1100
    readonly property int clipWidth: 1060
    readonly property int clipHeight: 520
    readonly property int emojiWidth: 800
    readonly property int emojiCell: 56

    // Colours
    readonly property color surface: Theme.surfaceHigh
    readonly property color panel: Theme.surfaceContainer
    readonly property color selected: Theme.secondaryContainer
    readonly property color selectedFg: Theme.secondaryContainerFg
    readonly property color hover: Theme.alpha(Theme.surfaceFg, 0.06)
    readonly property color shadow: Theme.alpha(Theme.shadow, Theme.dark ? 0.45 : 0.22)

    // Motion
    readonly property int openDuration: 260
    readonly property int closeDuration: 180
    readonly property int railDuration: 640
    readonly property int panelDuration: 320

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
    function smoothstep(v) { const c = clamp(v, 0, 1); return c * c * (3 - 2 * c); }
}
