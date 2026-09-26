import QtQuick
import Quickshell.Widgets
import qs.config
import qs.components

// Rounded album art with a cross-fade between tracks and a glyph placeholder.
ClippingRectangle {
    id: root

    property string source
    property real iconSize: Math.max(14, width * 0.42)
    property color placeholder: Theme.surfaceHighest
    property color placeholderFg: Theme.surfaceVariantFg

    color: placeholder
    radius: Tokens.radius.m

    property bool _front: true

    onSourceChanged: {
        const next = _front ? b : a;
        next.source = source;
        _front = !_front;
    }
    Component.onCompleted: a.source = source

    Icon {
        anchors.centerIn: parent
        text: "music_note"
        size: root.iconSize
        fill: 1
        color: root.placeholderFg
        opacity: a.status === Image.Ready || b.status === Image.Ready ? 0 : 1
        Behavior on opacity { Anim { duration: Motion.duration.short } }
    }

    component Art: Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Math.ceil(root.width * 2)
        sourceSize.height: Math.ceil(root.height * 2)
        asynchronous: true
        cache: true
        smooth: true
        Behavior on opacity { Anim { duration: Motion.duration.medium } }
    }

    Art { id: a; opacity: root._front && status === Image.Ready ? 1 : 0 }
    Art { id: b; opacity: !root._front && status === Image.Ready ? 1 : 0 }
}
