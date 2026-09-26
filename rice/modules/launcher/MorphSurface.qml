pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config

// The search pill and its mode buttons, drawn as one gooey surface.
// `progress` 0 = a single wide pill, 1 = a narrower pill followed by
// `count` round buttons. Geometry is a pure function of progress, so an
// interrupted transition simply reverses from wherever it is.
//
// While the shapes are close, a blurred + thresholded copy (metaballs) is
// drawn under the crisp shapes so the buttons stretch out of the pill and
// snap free; at rest only the crisp shapes are rendered.
Item {
    id: root

    property real progress: 0
    property real mainLeft: 0
    property real collapsedWidth: 800
    property real expandedWidth: 460
    property real shapeHeight: 60
    property real diameter: 60
    property real gap: 10
    property int count: 5
    property color color: Theme.surfaceHigh
    property color shadowColor: Theme.alpha(Theme.shadow, 0.4)

    readonly property real centerY: height / 2
    readonly property real mainWidth: lerp(collapsedWidth, expandedWidth, spring(0, 6.4, 7.6))
    readonly property real expandedRight: mainLeft + expandedWidth
    readonly property bool gooActive: progress > 0.002 && progress < 0.998 && blend > 0.01
    // Blend strength: strong while buttons emerge, gone before they settle.
    readonly property real blend: Spot.smoothstep(progress / 0.12) * (1 - Spot.smoothstep((progress - 0.42) / 0.36))

    function lerp(a, b, t) { return a + (b - a) * t; }

    // Damped spring response normalised to reach exactly 1 at progress 1.
    function spring(delay, decay, freq) {
        const f = t => 1 - Math.exp(-decay * t) * (Math.cos(freq * t) + decay / freq * Math.sin(freq * t));
        const t = Math.max(0, Math.min(1, progress) - delay);
        return f(t) / f(1 - delay);
    }

    function growth(i) {
        return i === 0 ? spring(0.04, 9.5, 10.5) : spring(0.02 + i * 0.03, 6.8 - i * 0.5, 7.2 - i * 0.5);
    }

    function centerX(i) {
        const first = expandedRight + gap + diameter / 2 - diameter * 0.45 * (1 - growth(0));
        if (i === 0) return first;
        const travel = spring(0.07 + i * 0.025, 7.2 - i * 0.55, 8.4 - i * 0.7);
        return first + i * (diameter + gap) * travel;
    }

    function size(i) {
        return diameter * Math.max(0, growth(i));
    }

    function iconProgress(i) {
        return Spot.smoothstep((progress - 0.34 - i * 0.03) / 0.22);
    }

    component Shapes: Item {
        id: shapes
        property color fill: "white"
        anchors.fill: parent

        Rectangle {
            x: root.mainLeft
            y: root.centerY - height / 2
            width: root.mainWidth
            height: root.shapeHeight
            radius: height / 2
            color: shapes.fill
        }

        Repeater {
            model: root.count
            Rectangle {
                required property int index
                readonly property real d: root.size(index)
                visible: d > 0.5
                x: root.centerX(index) - d / 2
                y: root.centerY - d / 2
                width: d
                height: d
                radius: d / 2
                color: shapes.fill
            }
        }
    }

    Item {
        id: surface
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.shadowColor
            shadowBlur: 0.8
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
        }

        // --- metaball layer (only during transitions)
        Shapes {
            id: mask
            visible: false
            layer.enabled: root.gooActive
        }

        MultiEffect {
            id: blurred
            anchors.fill: parent
            source: mask
            visible: false
            layer.enabled: root.gooActive
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 22
            blur: root.blend
        }

        Rectangle {
            id: fill
            anchors.fill: parent
            color: root.color
            visible: false
            layer.enabled: root.gooActive
        }

        MultiEffect {
            anchors.fill: parent
            visible: root.gooActive
            source: fill
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: blurred
            maskThresholdMin: 0.48
            maskSpreadAtMin: 0.12
        }

        // --- crisp shapes
        Shapes {
            fill: root.color
        }
    }
}
