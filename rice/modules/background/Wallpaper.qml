import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Wallpaper layer with a cross-fade between images. Without a wallpaper a
// gradient built from the current scheme is shown instead.
PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.surfaceDim
    WlrLayershell.namespace: "rice-wallpaper"
    WlrLayershell.layer: WlrLayer.Background

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: Theme.primaryContainer }
            GradientStop { position: 1; color: Theme.surfaceDim }
        }
    }

    property Image front: a

    Connections {
        target: Wallpapers
        function onCurrentChanged() { root.swap(); }
    }
    Component.onCompleted: swap()

    function swap() {
        const next = front === a ? b : a;
        next.source = Wallpapers.current ? `file://${Wallpapers.current}` : "";
    }

    component Layer: Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(root.width * (root.screen?.devicePixelRatio ?? 1), root.height * (root.screen?.devicePixelRatio ?? 1))
        opacity: root.front === this ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.duration.long * 2; easing.type: Easing.InOutQuad } }
        onStatusChanged: if (status === Image.Ready && root.front !== this) root.front = this
    }

    Layer { id: a }
    Layer { id: b }
}
