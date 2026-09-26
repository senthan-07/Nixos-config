import QtQuick
import qs.config
import qs.components

// Scaled arrangement of monitors. Drag to move (edges snap to neighbours), click or Tab to
// select, arrow keys nudge the selected output (Shift = 10 px, Ctrl = 100 px).
//   outputs: [{ name, label, x, y, w, h }]  (logical px)
Rectangle {
    id: root

    property var outputs: []
    property string selected
    signal select(string name)
    signal moved(string name, int x, int y)

    property bool dragging: false
    property string dragName
    property point dragPos
    property var frozen: null            // bounds held steady during a drag
    property var snap: null

    readonly property var bounds: {
        if (dragging && frozen) return frozen;
        let l = Infinity, t = Infinity, r = -Infinity, b = -Infinity;
        for (const o of outputs) {
            l = Math.min(l, o.x); t = Math.min(t, o.y);
            r = Math.max(r, o.x + o.w); b = Math.max(b, o.y + o.h);
        }
        if (!isFinite(l)) return { l: 0, t: 0, w: 1920, h: 1080 };
        // generous margin so a monitor can be dragged beyond the current arrangement
        const mx = (r - l) * 0.25, my = (b - t) * 0.25;
        return { l: l - mx, t: t - my, w: r - l + mx * 2, h: b - t + my * 2 };
    }
    readonly property real k: Math.max(0.0001, Math.min((width - 48) / bounds.w, (height - 48) / bounds.h))
    readonly property real ox: (width - bounds.w * k) / 2 - bounds.l * k
    readonly property real oy: (height - bounds.h * k) / 2 - bounds.t * k

    function snapTo(o, x, y) {
        const tol = 16 / k;
        let sx = x, sy = y, bx = tol, by = tol;
        for (const other of outputs) {
            if (other.name === o.name) continue;
            for (const e of [other.x, other.x + other.w, other.x - o.w, other.x + other.w - o.w]) {
                if (Math.abs(x - e) < bx) { bx = Math.abs(x - e); sx = e; }
            }
            for (const e of [other.y, other.y + other.h, other.y - o.h, other.y + other.h - o.h]) {
                if (Math.abs(y - e) < by) { by = Math.abs(y - e); sy = e; }
            }
        }
        return Qt.point(Math.round(sx), Math.round(sy));
    }

    implicitHeight: 300
    radius: Tokens.radius.l
    color: Theme.surfaceLowest
    clip: true

    // dotted grid backdrop
    Grid {
        anchors.fill: parent
        anchors.margins: 12
        columns: Math.max(1, Math.floor(width / 24))
        spacing: 22
        opacity: 0.35
        Repeater {
            model: Math.max(0, Math.floor((root.width - 24) / 24)) * Math.max(0, Math.floor((root.height - 24) / 24))
            Rectangle { width: 2; height: 2; radius: 1; color: Theme.outlineVariant }
        }
    }

    // snap preview outline
    Rectangle {
        visible: root.dragging && root.snap !== null
        x: root.ox + (root.snap?.x ?? 0) * root.k
        y: root.oy + (root.snap?.y ?? 0) * root.k
        width: (root.snap?.w ?? 0) * root.k
        height: (root.snap?.h ?? 0) * root.k
        radius: Tokens.radius.s
        color: Theme.alpha(Theme.primary, 0.08)
        border.width: 2
        border.color: Theme.alpha(Theme.primary, 0.7)
    }

    Repeater {
        model: root.outputs

        Rectangle {
            id: mon
            required property var modelData
            required property int index
            readonly property bool active: root.selected === modelData.name
            readonly property bool held: root.dragging && root.dragName === modelData.name

            x: root.ox + (held ? root.dragPos.x : modelData.x) * root.k
            y: root.oy + (held ? root.dragPos.y : modelData.y) * root.k
            width: modelData.w * root.k
            height: modelData.h * root.k
            z: held ? 3 : active ? 2 : 1
            radius: Tokens.radius.s
            color: active ? Theme.primaryContainer : Theme.surfaceHigh
            border.width: activeFocus ? 3 : active ? 2 : 1
            border.color: active || activeFocus ? Theme.primary : Theme.outlineVariant
            scale: held ? 1.02 : 1
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: modelData.label

            Behavior on x { enabled: !mon.held; Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }
            Behavior on y { enabled: !mon.held; Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }
            Behavior on scale { Anim { duration: Motion.duration.short } }
            Behavior on color { ColorAnim {} }

            onActiveFocusChanged: if (activeFocus) root.select(modelData.name)
            Keys.onPressed: e => {
                const step = e.modifiers & Qt.ControlModifier ? 100 : e.modifiers & Qt.ShiftModifier ? 10 : 1;
                const d = { [Qt.Key_Left]: [-step, 0], [Qt.Key_Right]: [step, 0], [Qt.Key_Up]: [0, -step], [Qt.Key_Down]: [0, step] }[e.key];
                if (!d) return;
                root.moved(modelData.name, modelData.x + d[0], modelData.y + d[1]);
                e.accepted = true;
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 12
                spacing: 2
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: mon.modelData.name
                    font.weight: Font.DemiBold
                    font.pixelSize: Math.max(10, Math.min(Tokens.font.l, mon.height / 5))
                    color: mon.active ? Theme.primaryContainerFg : Theme.surfaceFg
                }
                StyledText {
                    width: parent.width
                    visible: mon.height > 60
                    horizontalAlignment: Text.AlignHCenter
                    text: mon.modelData.label
                    font.pixelSize: Tokens.font.s
                    color: mon.active ? Theme.alpha(Theme.primaryContainerFg, 0.8) : Theme.surfaceVariantFg
                }
            }

            // focused-monitor dot
            Rectangle {
                visible: mon.modelData.focused ?? false
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                width: 8; height: 8; radius: 4
                color: Theme.tertiary
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point startPointer
                property point startPos
                onPressed: m => {
                    mon.forceActiveFocus();
                    root.select(mon.modelData.name);
                    root.frozen = root.bounds;
                    startPointer = mapToItem(root, m.x, m.y);
                    startPos = Qt.point(mon.modelData.x, mon.modelData.y);
                    root.dragPos = startPos;
                    root.dragName = mon.modelData.name;
                    root.snap = null;
                    root.dragging = true;
                }
                onPositionChanged: m => {
                    if (!root.dragging) return;
                    const p = mapToItem(root, m.x, m.y);
                    const raw = Qt.point(startPos.x + (p.x - startPointer.x) / root.k, startPos.y + (p.y - startPointer.y) / root.k);
                    root.dragPos = raw;
                    const s = root.snapTo(mon.modelData, raw.x, raw.y);
                    root.snap = { x: s.x, y: s.y, w: mon.modelData.w, h: mon.modelData.h };
                }
                onReleased: finish()
                onCanceled: finish()
                function finish() {
                    if (!root.dragging) return;
                    const s = root.snap;
                    root.dragging = false;
                    root.frozen = null;
                    root.snap = null;
                    if (s && (s.x !== mon.modelData.x || s.y !== mon.modelData.y)) root.moved(mon.modelData.name, s.x, s.y);
                }
            }
        }
    }
}
