import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import qs.config
import qs.components

// Transient snackbar at the bottom of the settings window.  toast.show("Copied")
QC.Popup {
    id: root

    property string text
    property string icon: "check"

    function show(message, glyph) {
        text = message;
        icon = glyph ?? "check";
        open();
        hide.restart();
    }

    parent: QC.Overlay.overlay
    x: ((parent?.width ?? 0) - width) / 2
    y: (parent?.height ?? 0) - height - Tokens.space.xl
    padding: 0
    closePolicy: QC.Popup.NoAutoClose
    modal: false
    focus: false

    Timer { id: hide; interval: 2600; onTriggered: root.close() }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.duration.short }
            NumberAnimation { property: "y"; from: (root.parent?.height ?? 0); to: (root.parent?.height ?? 0) - root.height - Tokens.space.xl; duration: Motion.duration.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.emphasizedDecel }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.duration.short }
    }

    background: Rectangle {
        radius: Tokens.radius.s
        color: Theme.inverseSurface
    }
    contentItem: RowLayout {
        spacing: Tokens.space.m
        Item { implicitWidth: Tokens.space.s }
        Icon { text: root.icon; size: 18; color: Theme.inversePrimary }
        StyledText {
            Layout.maximumWidth: 480
            Layout.topMargin: Tokens.space.m
            Layout.bottomMargin: Tokens.space.m
            text: root.text
            color: Theme.inverseOnSurface
        }
        Item { implicitWidth: Tokens.space.s }
    }
}
