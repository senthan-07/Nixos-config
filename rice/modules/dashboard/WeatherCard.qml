import QtQuick
import qs.config
import qs.components

// Card used throughout the weather view. It reveals itself (fade, rise and a
// slight settle in scale) the first time it scrolls into view and exposes
// `progress` (0 → 1) so gauges inside can sweep in after it.
Item {
    id: root

    property string title
    property string icon
    property Flickable flick
    property real contentTop: y              // position inside the flickable's content
    property int stagger: 0
    property bool active: true        // view is on screen; replays the reveal each time
    property color accent: Theme.primary
    default property alias content: body.data
    property alias body: body
    readonly property real headerHeight: title ? 34 : 0

    property bool revealed: false
    property real progress: 0
    property real rise: 36

    readonly property bool inView: active && flick !== null
        && contentTop + 40 < flick.contentY + flick.height && contentTop + height > flick.contentY

    onInViewChanged: if (inView && !revealed) reveal()
    onActiveChanged: {
        if (active) {
            Qt.callLater(() => { if (inView && !revealed) reveal(); });
        } else {
            enter.stop();
            revealed = false;
            progress = 0;
            card.opacity = 0;
            rise = 36;
        }
    }

    function reveal() {
        revealed = true;
        enter.restart();
    }

    SequentialAnimation {
        id: enter
        PauseAnimation { duration: root.stagger * 70 }
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Motion.duration.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.standardDecel }
            NumberAnimation { target: root; property: "rise"; from: 36; to: 0; duration: Motion.duration.long + 100; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.springDefault }
            NumberAnimation { target: root; property: "progress"; from: 0; to: 1; duration: 1100; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.emphasizedDecel }
        }
    }

    Rectangle {
        id: card
        width: root.width
        height: root.height
        y: root.rise
        opacity: 0
        scale: 1 - root.rise / 36 * 0.03
        radius: Tokens.radius.xl
        color: Theme.alpha(Theme.surfaceContainer, 0.94)
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.35)

        Row {
            visible: root.title !== ""
            x: Tokens.space.l
            y: Tokens.space.m + 2
            spacing: Tokens.space.s
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                size: 17
                fill: 1
                color: root.accent
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                font.pixelSize: Tokens.font.s
                font.weight: Font.DemiBold
                font.letterSpacing: 0.3
                color: Theme.surfaceVariantFg
            }
        }

        Item {
            id: body
            anchors.fill: parent
            anchors.topMargin: root.headerHeight + Tokens.space.xs
            anchors.margins: Tokens.space.l
        }
    }
}
