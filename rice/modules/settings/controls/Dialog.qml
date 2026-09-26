import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import qs.config
import qs.components

// M3 basic dialog centred on the settings window.
//   Dialog { id: d; title: "Forget?"; text: "…"; confirmText: "Forget"; danger: true; onConfirmed: … }
//   d.open()
// Extra content (fields) can be added as children; they go between text and buttons.
QC.Popup {
    id: root

    property string icon
    property string title
    property string text
    property string confirmText: "OK"
    property string cancelText: "Cancel"
    property bool danger: false
    property bool confirmEnabled: true
    default property alias body: extra.data

    signal confirmed()
    signal cancelled()

    parent: QC.Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(440, (parent?.width ?? 480) - 48)
    modal: true
    focus: true
    padding: Tokens.space.xl
    closePolicy: QC.Popup.CloseOnEscape | QC.Popup.CloseOnPressOutside

    QC.Overlay.modal: Rectangle { color: Theme.alpha(Theme.scrim, 0.4) }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.duration.short }
            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Motion.duration.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.emphasizedDecel }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.duration.tiny }
    }

    background: Rectangle {
        radius: Tokens.radius.xl
        color: Theme.surfaceHigh
    }

    contentItem: ColumnLayout {
        spacing: Tokens.space.l

        Icon {
            Layout.alignment: Qt.AlignHCenter
            visible: root.icon !== ""
            text: root.icon
            size: 28
            color: root.danger ? Theme.error : Theme.secondary
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: root.icon !== "" ? Text.AlignHCenter : Text.AlignLeft
            text: root.title
            font.pixelSize: Tokens.font.xxl
            wrapMode: Text.Wrap
        }
        StyledText {
            Layout.fillWidth: true
            visible: root.text !== ""
            text: root.text
            color: Theme.surfaceVariantFg
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        ColumnLayout {
            id: extra
            Layout.fillWidth: true
            spacing: Tokens.space.m
            visible: children.length > 0
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.space.s
            spacing: Tokens.space.s
            Item { Layout.fillWidth: true }
            ActionButton {
                text: root.cancelText
                onClicked: root.reject()
            }
            ActionButton {
                text: root.confirmText
                kind: root.danger ? "danger" : "filled"
                enabled: root.confirmEnabled
                onClicked: { root.close(); root.confirmed(); }
            }
        }
    }

    function reject() {
        close();
        cancelled();
    }
}
