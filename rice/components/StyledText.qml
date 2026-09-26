import QtQuick
import qs.config

Text {
    color: Theme.surfaceFg
    font.family: Tokens.font.sans
    font.pixelSize: Tokens.font.m
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight

    Behavior on color { ColorAnim {} }
}
