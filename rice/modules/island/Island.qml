import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Dynamic island: a pill just below the bar's centre that morphs between
// idle, now-playing, timer, volume/brightness, notification and the expanded
// hub. Only the pill itself takes input; the rest of the surface is
// click-through. Create one per screen; it only shows on the focused monitor.
PanelWindow {
    id: root

    readonly property bool onThisScreen: screen?.name === IslandState.screenName
    readonly property string mode: onThisScreen ? IslandState.mode : "idle"
    readonly property bool compact: mode === "media" || mode === "timer"
    readonly property Item content: mode === "hub" ? hub
        : mode === "osd" ? osd
        : mode === "notification" ? notif
        : mode === "media" ? media
        : mode === "timer" ? timer : null

    // Hover growth for the compact states (expressive "breathing" hint).
    readonly property bool hovering: compact && pillMouse.containsMouse
    readonly property real targetW: content ? content.implicitWidth + (hovering ? 16 : 0) : 72
    readonly property real targetH: content ? content.implicitHeight + (hovering ? 6 : 0) : 8
    readonly property real targetR: mode === "hub" ? Tokens.radius.xl + 4
        : mode === "notification" ? Tokens.radius.xl : targetH / 2

    anchors.top: true
    // Sits under the bar's exclusive zone; the window is big enough for the hub.
    exclusiveZone: 0
    implicitWidth: 900
    implicitHeight: 460
    color: "transparent"
    visible: onThisScreen && (mode !== "idle" || pill.opacity > 0)
    mask: Region { item: pill }

    WlrLayershell.namespace: "rice-island"
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand, like the sidebar: with Exclusive focus Hyprland never breaks the
    // focus grab, so outside clicks couldn't close the hub.
    WlrLayershell.keyboardFocus: mode === "hub" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    DelayedFocusGrab {
        windows: [root]
        want: root.mode === "hub"
        onCleared: IslandState.close()
    }

    onModeChanged: if (mode === "hub") Qt.callLater(() => hub.forceActiveFocus())

    // ---- Morph driver ----
    // Width/height are set imperatively so each change can pick the right
    // curve: a springy overshoot when growing, a quick settle when shrinking.
    property bool growW: true
    property bool growH: true
    onTargetWChanged: { growW = targetW >= pill.width; pill.width = targetW; }
    onTargetHChanged: { growH = targetH >= pill.height; pill.height = targetH; }

    RectangularShadow {
        anchors.fill: pill
        radius: pill.radius
        blur: 22
        spread: 0
        offset.y: 4
        color: Theme.alpha(Theme.shadow, Theme.dark ? 0.45 : 0.18)
        opacity: pill.opacity
    }

    // ClippingRectangle clips the contents (and the art wash) to the rounded shape.
    ClippingRectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.space.xs + 2
        width: 72
        height: 8
        radius: root.targetR
        opacity: root.mode === "idle" ? 0 : 1
        scale: root.mode === "idle" ? 0.9 : 1
        property color tint: root.mode === "hub" && IslandState.tab === "media" && Media.active ? MediaPalette.surface
            : root.mode === "notification" && notif.critical ? Theme.errorContainer
            : Theme.surfaceContainer
        color: tint
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.55)

        Behavior on width {
            NumberAnimation {
                duration: root.growW ? Motion.duration.long : Motion.duration.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.growW ? Motion.curve.springDefault : Motion.curve.emphasizedDecel
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: root.growH ? Motion.duration.long : Motion.duration.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.growH ? Motion.curve.springDefault : Motion.curve.emphasizedDecel
            }
        }
        Behavior on radius { Anim { duration: Motion.duration.medium } }
        Behavior on opacity { Anim { duration: root.mode === "idle" ? Motion.duration.medium : Motion.duration.short } }
        Behavior on scale { Anim { easing.bezierCurve: Motion.curve.springDefault } }
        Behavior on tint { ColorAnim { duration: Motion.duration.medium } }

        // Blurred art wash behind the media hub.
        Image {
            id: wash
            anchors.fill: parent
            source: root.mode === "hub" && IslandState.tab === "media" ? (Media.active?.trackArtUrl ?? "") : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 160
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wash
            visible: wash.status === Image.Ready
            opacity: root.mode === "hub" && IslandState.tab === "media" ? (Theme.dark ? 0.22 : 0.3) : 0
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.2
            Behavior on opacity { Anim {} }
        }

        // Compact interaction: click opens the hub, middle-click toggles
        // playback, scroll skips tracks.
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.compact
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: m => {
                if (m.button === Qt.MiddleButton) Media.active?.togglePlaying();
                else if (m.button === Qt.RightButton && root.mode === "timer") Timers.pause();
                else IslandState.open(root.mode === "media" ? "media" : "focus");
            }
            onWheel: w => {
                if (root.mode !== "media" || !Media.active) return;
                w.angleDelta.y > 0 ? Media.active.previous() : Media.active.next();
            }
        }

        // ---- Contents: each keeps its natural size and is clipped by the pill ----
        Slot { id: mediaSlot; name: "media"; CompactMedia { id: media } }
        Slot { id: timerSlot; name: "timer"; CompactTimer { id: timer } }
        Slot { id: osdSlot; name: "osd"; OsdContent { id: osd } }
        Slot { id: notifSlot; name: "notification"; NotificationContent { id: notif } }
        Slot { id: hubSlot; name: "hub"; Hub { id: hub } }
    }

    // Wrapper that fades its content in after the morph starts and out quickly.
    component Slot: Item {
        id: slot
        required property string name
        default property alias inner: holder.data
        readonly property bool current: root.mode === name
        readonly property Item item: holder.children[0] ?? null

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: item?.implicitWidth ?? 0
        height: item?.implicitHeight ?? 0
        opacity: current ? 1 : 0
        visible: current || opacity > 0
        scale: current ? 1 : 0.94
        transformOrigin: Item.Top

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: slot.current ? 110 : 0 }
                NumberAnimation {
                    duration: slot.current ? Motion.duration.medium : Motion.duration.tiny
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curve.standard
                }
            }
        }
        Behavior on scale { Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.emphasizedDecel } }

        Item {
            id: holder
            anchors.fill: parent
            // Children fill the slot.
            onChildrenChanged: { for (const c of children) c.anchors.fill = holder; }
        }
    }
}
