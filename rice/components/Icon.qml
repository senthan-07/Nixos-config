import QtQuick
import qs.config

// Material Symbols Rounded glyph. `fill` animates between outlined and filled.
Text {
    id: root

    property real size: 20
    property real fill: 0

    font.family: Tokens.font.icons
    font.pixelSize: size
    font.variableAxes: ({ "FILL": fill, "opsz": Math.min(48, Math.max(20, size)), "wght": 450 })
    color: Theme.surfaceFg
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on fill { Anim {} }
    Behavior on color { ColorAnim {} }
}
