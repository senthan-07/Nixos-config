import QtQuick
import qs.config
import qs.components

// A single keyboard key. Named keys (arrows, media, mouse) render as glyphs.
//   Keycap { key: "SUPER" }   Keycap { key: "left" }   Keycap { key: "mouse:272" }
Rectangle {
    id: root

    property string key

    readonly property var glyph: root.glyphFor(key)
    readonly property string label: root.labelFor(key)

    implicitWidth: Math.max(30, glyph ? 32 : text.implicitWidth + 16)
    implicitHeight: 30
    radius: Tokens.radius.xs + 1
    color: Theme.outline

    // Face of the key sits 2px above its base, like a real keycap.
    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 2
        radius: parent.radius
        color: Theme.surfaceHighest
        border.width: 1
        border.color: Theme.alpha(Theme.outline, 0.35)

        StyledText {
            id: text
            anchors.centerIn: parent
            visible: !root.glyph
            text: root.label
            font.family: Tokens.font.mono
            font.pixelSize: Tokens.font.s
            font.weight: Font.DemiBold
        }
        Icon {
            anchors.centerIn: parent
            visible: !!root.glyph
            text: root.glyph || ""
            size: 18
        }
    }

    function glyphFor(k) {
        const m = {
            left: "arrow_back", right: "arrow_forward", up: "arrow_upward", down: "arrow_downward",
            "mouse:272": "left_click", "mouse:273": "right_click", "mouse:274": "mouse",
            mouse_down: "swipe_down", mouse_up: "swipe_up",
            xf86audioraisevolume: "volume_up", xf86audiolowervolume: "volume_down",
            xf86audiomute: "volume_off", xf86audiomicmute: "mic_off",
            xf86monbrightnessup: "brightness_high", xf86monbrightnessdown: "brightness_low",
            xf86audionext: "skip_next", xf86audioprev: "skip_previous",
            xf86audioplay: "play_arrow", xf86audiopause: "pause", xf86audiostop: "stop",
            print: "screenshot_region", return: "keyboard_return", enter: "keyboard_return",
            backspace: "backspace", tab: "keyboard_tab", space: "space_bar"
        };
        return m[String(k).toLowerCase()] || null;
    }

    function labelFor(k) {
        const m = {
            super: "Super", mod4: "Super", win: "Super", shift: "Shift", ctrl: "Ctrl", control: "Ctrl",
            alt: "Alt", mod1: "Alt", escape: "Esc", delete: "Del", grave: "`", comma: ",", period: ".",
            slash: "/", minus: "-", equal: "=", semicolon: ";", apostrophe: "'"
        };
        const s = String(k);
        return m[s.toLowerCase()] || (s.length === 1 ? s.toUpperCase() : s);
    }
}
