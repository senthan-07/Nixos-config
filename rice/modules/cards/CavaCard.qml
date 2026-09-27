import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Audio visualiser (cava, via services/Spectrum): rounded bars rising from
// the bottom, bass on the left, with the playing track in the header.
// cava only runs while this card is on screen and something is playing.
CardFrame {
    id: root

    property bool running: true
    readonly property bool playing: Spectrum.playing
    readonly property string token: `card-cava-${Math.random().toString(36).slice(2, 8)}`

    icon: "graphic_eq"
    title: Media.active?.trackTitle || "Visualizer"
    subtitle: playing ? (Media.active?.trackArtist || Media.active?.identity || "") : "Nothing playing"

    implicitWidth: 368
    implicitHeight: 176

    onRunningChanged: running ? Spectrum.acquire(token) : Spectrum.release(token)
    Component.onCompleted: if (running) Spectrum.acquire(token)
    Component.onDestruction: Spectrum.release(token)

    Item {
        id: area
        // CardFrame's body is a plain Item, so fill it with anchors.
        anchors.fill: parent
        anchors.topMargin: Tokens.space.xs

        // Spectrum has 16 bands; each is drawn as a pair of bars, the second
        // blended towards the next band so the curve looks smooth.
        readonly property int count: 32
        readonly property real gap: width / count * 0.3
        readonly property real barWidth: (width - gap * (count - 1)) / count

        function level(i) {
            const v = Spectrum.values;
            if (!root.playing || !v || !v.length) return 0;
            const pos = i / (count - 1) * (v.length - 1);
            const lo = Math.floor(pos), t = pos - lo;
            return (v[lo] ?? 0) * (1 - t) + (v[Math.min(v.length - 1, lo + 1)] ?? 0) * t;
        }

        Repeater {
            model: area.count
            Rectangle {
                required property int index
                readonly property real v: area.level(index)
                x: index * (area.barWidth + area.gap)
                width: area.barWidth
                height: Math.max(width, area.height * v)
                anchors.bottom: parent.bottom
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.primary }
                    GradientStop { position: 1; color: Theme.alpha(Theme.tertiary, 0.55) }
                }
                opacity: root.playing ? 1 : 0.35
                Behavior on height { NumberAnimation { duration: Spectrum.live ? 60 : 120; easing.type: Easing.OutQuad } }
                Behavior on opacity { Anim { duration: Motion.duration.short } }
            }
        }
    }
}
