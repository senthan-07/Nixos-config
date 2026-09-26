import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Region selector for one output. The output is frozen with a ScreencopyView
// (everything drawn on top stays transparent until the frame arrives, so the
// overlay never captures itself). Screenshots are cropped from that frame.
PanelWindow {
    id: root

    required property ShellScreen targetScreen
    readonly property string name: targetScreen?.name ?? ""
    readonly property real dpr: targetScreen?.devicePixelRatio || 1

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "rice-capture"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: !Capture.active ? WlrKeyboardFocus.None
        : (Capture.focusScreen === name || Quickshell.screens.length === 1) ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.OnDemand

    // ---------------------------------------------------------------- state

    readonly property bool frozen: shot.hasContent
    property bool freezeFailed: false
    readonly property bool ready: frozen || freezeFailed
    readonly property bool shown: ready && Capture.active
    readonly property bool isPointerScreen: Capture.pointerScreen === name
    readonly property string action: Capture.action
    readonly property string mode: action === "pick" ? "pick" : Capture.mode

    // Pointer (logical, window-local).
    property real px: width / 2
    property real py: height / 2
    property bool pointerSeen: false

    // Selection (logical, window-local); owned by one screen at a time.
    property real sx: 0
    property real sy: 0
    property real sw: 0
    property real sh: 0
    readonly property bool owns: Capture.selScreen === name
    readonly property bool hasSel: owns && sw >= 1 && sh >= 1

    // "" | "new" | "move" | "resize"
    property string dragKind: ""
    readonly property bool dragging: dragKind !== ""
    property real ax: 0
    property real ay: 0
    property var grab: ({ l: false, r: false, t: false, b: false })
    property var startSel: ({ x: 0, y: 0, w: 0, h: 0 })
    property bool pressMoved: false
    property bool animateSel: false

    // Keyboard-selected window in window mode (-1: follow pointer).
    property int kbWindow: -1

    // Hyprland windows on this output, clipped, window-local.
    readonly property var localWindows: {
        const out = [];
        const sx0 = targetScreen?.x ?? 0, sy0 = targetScreen?.y ?? 0;
        for (const w of Capture.windows) {
            const x1 = Math.max(w.x - sx0, 0), y1 = Math.max(w.y - sy0, 0);
            const x2 = Math.min(w.x - sx0 + w.w, width), y2 = Math.min(w.y - sy0 + w.h, height);
            if (x2 - x1 >= 2 && y2 - y1 >= 2)
                out.push({ x: x1, y: y1, w: x2 - x1, h: y2 - y1, title: w.title, appClass: w.appClass });
        }
        return out;
    }

    function windowAt(x, y) {
        for (const w of localWindows)
            if (x >= w.x && x < w.x + w.w && y >= w.y && y < w.y + w.h) return w;
        return null;
    }

    readonly property var hoverWindow: pointerSeen && isPointerScreen ? windowAt(px, py) : null
    readonly property var pickedWindow: kbWindow >= 0 && kbWindow < localWindows.length ? localWindows[kbWindow] : hoverWindow

    // The rectangle that confirm() would capture, or null.
    readonly property var target: {
        if (mode === "screen") return isPointerScreen ? { x: 0, y: 0, w: width, h: height } : null;
        if (mode === "window") return isPointerScreen ? pickedWindow : null;
        if (mode === "region" && hasSel) return { x: sx, y: sy, w: sw, h: sh };
        return null;
    }

    // What to outline: the target, or the window under the pointer as a hint.
    readonly property var outline: target ?? (mode === "region" && !dragging && isPointerScreen ? hoverWindow : null)
    readonly property bool outlineIsHint: target === null && outline !== null

    function physical(v) {
        return Math.round(v * dpr);
    }

    // ---------------------------------------------------------------- selection helpers

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    // Snap a coordinate to nearby window / screen edges.
    function snap(v, horizontal, disabled) {
        if (disabled) return v;
        const lines = horizontal ? [0, width] : [0, height];
        for (const w of localWindows) {
            if (horizontal) lines.push(w.x, w.x + w.w);
            else lines.push(w.y, w.y + w.h);
        }
        let best = v, dist = 10;
        for (const l of lines) {
            const d = Math.abs(l - v);
            if (d < dist) { dist = d; best = l; }
        }
        return best;
    }

    function setSel(x, y, w, h, animate) {
        animateSel = !!animate;
        Capture.selScreen = name;
        sx = Math.round(x);
        sy = Math.round(y);
        sw = Math.round(w);
        sh = Math.round(h);
    }

    function clearSel() {
        sw = 0;
        sh = 0;
    }

    function pressAt(mx, my, alt) {
        pressMoved = false;
        ax = mx;
        ay = my;
        startSel = { x: sx, y: sy, w: sw, h: sh };
        if (mode !== "region") return;
        if (hasSel && mx >= sx && mx <= sx + sw && my >= sy && my <= sy + sh) {
            dragKind = "move";
        } else {
            dragKind = "new";
            ax = snap(mx, true, alt);
            ay = snap(my, false, alt);
        }
    }

    function dragTo(mx, my, alt) {
        if (!dragging) return;
        if (Math.abs(mx - ax) > 3 || Math.abs(my - ay) > 3) pressMoved = true;
        if (!pressMoved) return;
        if (dragKind === "new") {
            const x = clamp(snap(mx, true, alt), 0, width), y = clamp(snap(my, false, alt), 0, height);
            setSel(Math.min(ax, x), Math.min(ay, y), Math.abs(x - ax), Math.abs(y - ay));
        } else if (dragKind === "move") {
            const s = startSel;
            let nx = clamp(s.x + mx - ax, 0, width - s.w), ny = clamp(s.y + my - ay, 0, height - s.h);
            // Snap whichever edge is closer to a line.
            if (!alt) {
                const lx = snap(nx, true, false), rx = snap(nx + s.w, true, false) - s.w;
                nx = lx !== nx ? lx : rx !== nx ? rx : nx;
                const ty = snap(ny, false, false), by = snap(ny + s.h, false, false) - s.h;
                ny = ty !== ny ? ty : by !== ny ? by : ny;
            }
            setSel(nx, ny, s.w, s.h);
        } else if (dragKind === "resize") {
            const s = startSel;
            let l = s.x, t = s.y, r = s.x + s.w, b = s.y + s.h;
            const x = clamp(snap(mx, true, alt), 0, width), y = clamp(snap(my, false, alt), 0, height);
            if (grab.l) l = x;
            if (grab.r) r = x;
            if (grab.t) t = y;
            if (grab.b) b = y;
            setSel(Math.min(l, r), Math.min(t, b), Math.abs(r - l), Math.abs(b - t));
        }
    }

    function release(mx, my) {
        const kind = dragKind;
        dragKind = "";
        if (mode === "window") {
            if (pickedWindow) confirm();
            return;
        }
        if (mode === "screen") {
            confirm();
            return;
        }
        if (kind === "new" && !pressMoved) {
            // A click: snap to the window under the pointer, or the whole screen.
            const w = windowAt(mx, my);
            if (w) setSel(w.x, w.y, w.w, w.h, true);
            else setSel(0, 0, width, height, true);
        } else if (kind !== "" && hasSel && (sw < 4 || sh < 4)) {
            clearSel();
        }
    }

    function nudge(dx, dy, resize) {
        if (mode === "pick" || !hasSel) {
            px = clamp(px + dx, 0, width - 1 / dpr);
            py = clamp(py + dy, 0, height - 1 / dpr);
            pointerSeen = true;
            Capture.pointerScreen = name;
            return;
        }
        if (resize)
            setSel(sx, sy, clamp(sw + dx, 1, width - sx), clamp(sh + dy, 1, height - sy));
        else
            setSel(clamp(sx + dx, 0, width - sw), clamp(sy + dy, 0, height - sh), sw, sh);
    }

    function cycleWindow(step) {
        const n = localWindows.length;
        if (!n) return;
        kbWindow = kbWindow < 0 ? (step > 0 ? 0 : n - 1) : (kbWindow + step + n) % n;
        Capture.pointerScreen = name;
    }

    // ---------------------------------------------------------------- confirm

    function confirm() {
        if (!Capture.active || cropper.busy) return;
        if (mode === "pick") {
            pickNow();
            return;
        }
        let r = target;
        if (!r && mode === "region" && isPointerScreen) r = { x: 0, y: 0, w: width, h: height };
        if (!r || r.w < 2 || r.h < 2) return;

        const g = { x: (targetScreen?.x ?? 0) + r.x, y: (targetScreen?.y ?? 0) + r.y, w: r.w, h: r.h };
        const full = r.x <= 0 && r.y <= 0 && r.w >= width && r.h >= height;
        if (action === "record") {
            Capture.finishRecord(g, name, full);
            return;
        }
        if (!frozen) {
            Capture.finish();
            Capture.grimCapture(action, g);
            return;
        }
        cropper.start(r, action);
    }

    function pickNow() {
        if (!pixel.ready) return;
        swatch.color = pixel.color;
        swatch.hex = pixel.hex;
        swatch.save();
    }

    // ---------------------------------------------------------------- lifecycle

    Timer {
        // Give up on freezing (no screencopy support): work on the live screen instead.
        interval: 800
        running: true
        onTriggered: if (!root.frozen) root.freezeFailed = true
    }

    Connections {
        target: Capture
        function onModeChanged() { root.kbWindow = -1; }
        function onActionChanged() { if (root.action === "pick") pixel.load(); }
    }

    onFrozenChanged: if (frozen && action === "pick") pixel.load()

    // ---------------------------------------------------------------- frozen frame

    ScreencopyView {
        id: shot
        anchors.fill: parent
        captureSource: root.targetScreen
        live: false
        paintCursor: false
    }

    // Everything visible is inside the stage, which fades in once frozen.
    Item {
        id: stage
        anchors.fill: parent
        opacity: root.shown ? 1 : 0
        Behavior on opacity { Anim { duration: Motion.duration.short } }

        // ---- dim outside the target
        readonly property color scrim: Theme.alpha(Theme.scrim, root.mode === "pick" ? 0 : 0.42)
        readonly property var cut: root.target && !root.outlineIsHint ? root.target : null

        Rectangle {
            visible: !stage.cut
            anchors.fill: parent
            color: stage.scrim
        }
        Item {
            visible: !!stage.cut
            anchors.fill: parent
            readonly property real cx: stage.cut?.x ?? 0
            readonly property real cy: stage.cut?.y ?? 0
            readonly property real cw: stage.cut?.w ?? 0
            readonly property real ch: stage.cut?.h ?? 0
            Rectangle { x: 0; y: 0; width: parent.width; height: parent.cy; color: stage.scrim }
            Rectangle { x: 0; y: parent.cy + parent.ch; width: parent.width; height: Math.max(0, parent.height - y); color: stage.scrim }
            Rectangle { x: 0; y: parent.cy; width: parent.cx; height: parent.ch; color: stage.scrim }
            Rectangle { x: parent.cx + parent.cw; y: parent.cy; width: Math.max(0, parent.width - x); height: parent.ch; color: stage.scrim }
        }

        // ---- crosshair guides (region mode, before a selection exists)
        Item {
            anchors.fill: parent
            visible: root.mode === "region" && !root.hasSel && root.pointerSeen && root.isPointerScreen
            Rectangle { x: Math.round(root.px); width: 1; height: parent.height; color: Theme.alpha(Theme.primary, 0.55) }
            Rectangle { y: Math.round(root.py); height: 1; width: parent.width; color: Theme.alpha(Theme.primary, 0.55) }

            Rectangle {
                x: root.px + 14 + width > parent.width ? root.px - width - 14 : root.px + 14
                y: root.py + 14 + height > parent.height ? root.py - height - 14 : root.py + 14
                width: coords.implicitWidth + Tokens.space.m * 2
                height: 26
                radius: height / 2
                color: Theme.alpha(Theme.inverseSurface, 0.9)
                StyledText {
                    id: coords
                    anchors.centerIn: parent
                    text: `${root.physical(root.px)}, ${root.physical(root.py)}`
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.xs
                    color: Theme.inverseOnSurface
                }
            }
        }

        // ---- outline of the target / hovered window
        Rectangle {
            id: frame
            visible: root.outline !== null && root.mode !== "pick"
            readonly property bool animated: root.animateSel || root.mode !== "region" || root.outlineIsHint
            x: root.outline?.x ?? 0
            y: root.outline?.y ?? 0
            width: root.outline?.w ?? 0
            height: root.outline?.h ?? 0
            color: root.outlineIsHint ? Theme.alpha(Theme.primary, 0.08) : "transparent"
            border.width: root.outlineIsHint ? 1 : 2
            border.color: root.action === "record" ? Theme.error : Theme.primary
            radius: root.mode === "window" || root.outlineIsHint ? Tokens.radius.xs : 0

            Behavior on x { enabled: frame.animated; Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.emphasizedDecel } }
            Behavior on y { enabled: frame.animated; Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.emphasizedDecel } }
            Behavior on width { enabled: frame.animated; Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.emphasizedDecel } }
            Behavior on height { enabled: frame.animated; Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.emphasizedDecel } }
        }

        // ---- size / window label
        Rectangle {
            id: sizeTag
            visible: root.outline !== null && root.mode !== "pick" && (root.mode !== "screen" || root.isPointerScreen)
            // Prefer above the frame, then below, then inside its top-left
            // corner; never under the hint pill or the toolbar.
            readonly property var spot: {
                const w = tagRow.implicitWidth + Tokens.space.m * 2, h = 32, m = Tokens.space.m, gap = Tokens.space.s;
                const fx = frame.x, fy = frame.y, fw = frame.width, fh = frame.height;
                const x = Math.max(m, Math.min(fx, root.width - w - m));
                const blocked = (cx, cy) => {
                    for (const b of [hint, toolbar]) {
                        if (!b.visible) continue;
                        if (cx < b.x + b.width + gap && cx + w + gap > b.x && cy < b.y + b.height + gap && cy + h + gap > b.y)
                            return true;
                    }
                    return cy < 4 || cy + h > root.height - 4;
                };
                const inX = Math.max(m, fx + m), inY = Math.max(m, fy + m);
                const candidates = [[x, fy - h - gap], [x, fy + fh + gap], [inX, inY],
                                    [Math.max(m, Math.min(fx + fw - w - m, root.width - w - m)), Math.min(fy + fh, root.height) - h - m]];
                for (const c of candidates)
                    if (!blocked(c[0], c[1])) return c;
                return candidates[2];
            }
            x: spot[0]
            y: spot[1]
            width: tagRow.implicitWidth + Tokens.space.m * 2
            height: 32
            radius: height / 2
            color: Theme.surfaceHighest
            Behavior on y { enabled: frame.animated; Anim { duration: Motion.duration.short } }

            RowLayout {
                id: tagRow
                anchors.centerIn: parent
                spacing: Tokens.space.s

                Icon {
                    text: root.outlineIsHint || root.mode === "window" ? "web_asset" : root.mode === "screen" ? "desktop_windows" : "crop_free"
                    size: 16
                    color: root.action === "record" ? Theme.error : Theme.primary
                }
                StyledText {
                    visible: (root.outlineIsHint || root.mode === "window") && text !== ""
                    Layout.maximumWidth: 260
                    text: root.outline?.appClass ?? ""
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: `${root.physical(frame.width)} × ${root.physical(frame.height)}`
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.s
                    color: Theme.surfaceVariantFg
                }
            }
        }

        // ---- main pointer area
        MouseArea {
            id: pointerArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: root.mode === "pick" || root.mode === "region" && !(root.hasSel && root.px >= root.sx && root.px <= root.sx + root.sw && root.py >= root.sy && root.py <= root.sy + root.sh)
                ? Qt.CrossCursor : root.mode === "region" ? Qt.SizeAllCursor : Qt.PointingHandCursor

            function track(m) {
                root.px = m.x;
                root.py = m.y;
                root.pointerSeen = true;
                if (Capture.pointerScreen !== root.name) Capture.pointerScreen = root.name;
                if (root.kbWindow >= 0 && root.mode === "window") root.kbWindow = -1;
            }

            onPositionChanged: m => {
                track(m);
                root.dragTo(m.x, m.y, m.modifiers & Qt.AltModifier);
            }
            onPressed: m => {
                keys.forceActiveFocus();
                track(m);
                if (m.button === Qt.RightButton) return;
                if (root.mode === "pick") return;
                root.pressAt(m.x, m.y, m.modifiers & Qt.AltModifier);
            }
            onReleased: m => {
                if (m.button === Qt.RightButton) {
                    // Right click: drop the selection, or cancel when there is none.
                    if (root.hasSel) root.clearSel();
                    else Capture.cancel();
                    return;
                }
                if (root.mode === "pick") {
                    root.pickNow();
                    return;
                }
                root.release(m.x, m.y);
            }
            onDoubleClicked: m => {
                if (m.button === Qt.LeftButton && root.hasSel && root.mode === "region") root.confirm();
            }
        }

        // ---- resize handles
        Repeater {
            model: [
                { l: true, t: true, cur: Qt.SizeFDiagCursor }, { t: true, cur: Qt.SizeVerCursor },
                { r: true, t: true, cur: Qt.SizeBDiagCursor }, { r: true, cur: Qt.SizeHorCursor },
                { r: true, b: true, cur: Qt.SizeFDiagCursor }, { b: true, cur: Qt.SizeVerCursor },
                { l: true, b: true, cur: Qt.SizeBDiagCursor }, { l: true, cur: Qt.SizeHorCursor }
            ]

            Item {
                id: handle
                required property var modelData
                readonly property bool corner: !!(modelData.l || modelData.r) && !!(modelData.t || modelData.b)
                visible: root.hasSel && root.mode === "region" && root.dragKind !== "new"
                width: 24
                height: 24
                // Kept on screen so a full-screen selection stays resizable.
                x: root.clamp((modelData.l ? root.sx : modelData.r ? root.sx + root.sw : root.sx + root.sw / 2) - width / 2, -4, root.width - width + 4)
                y: root.clamp((modelData.t ? root.sy : modelData.b ? root.sy + root.sh : root.sy + root.sh / 2) - height / 2, -4, root.height - height + 4)

                Rectangle {
                    anchors.centerIn: parent
                    width: handle.corner ? 14 : (handle.modelData.t || handle.modelData.b ? 22 : 6)
                    height: handle.corner ? 14 : (handle.modelData.l || handle.modelData.r ? 22 : 6)
                    radius: Math.min(width, height) / 2
                    color: root.action === "record" ? Theme.error : Theme.primary
                    border.width: 2
                    border.color: Theme.surface
                    scale: hm.containsMouse || hm.pressed ? 1.25 : 1
                    Behavior on scale { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.springFast } }
                }

                MouseArea {
                    id: hm
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: handle.modelData.cur
                    onPressed: m => {
                        keys.forceActiveFocus();
                        const p = mapToItem(stage, m.x, m.y);
                        root.startSel = { x: root.sx, y: root.sy, w: root.sw, h: root.sh };
                        root.grab = { l: !!handle.modelData.l, r: !!handle.modelData.r, t: !!handle.modelData.t, b: !!handle.modelData.b };
                        root.ax = p.x;
                        root.ay = p.y;
                        root.pressMoved = true;
                        root.dragKind = "resize";
                    }
                    onPositionChanged: m => {
                        if (!pressed) return;
                        const p = mapToItem(stage, m.x, m.y);
                        root.px = p.x;
                        root.py = p.y;
                        root.dragTo(p.x, p.y, m.modifiers & Qt.AltModifier);
                    }
                    onReleased: root.dragKind = ""
                }
            }
        }

        // ---- hint pill
        Rectangle {
            id: hint
            visible: root.isPointerScreen
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.shown ? Tokens.space.xl : -height
            width: hintRow.implicitWidth + Tokens.space.l * 2
            height: 40
            radius: height / 2
            color: root.action === "record" ? Theme.errorContainer : Theme.primaryContainer
            Behavior on y { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }
            Behavior on width { Anim { duration: Motion.duration.short } }

            readonly property color fg: root.action === "record" ? Theme.errorContainerFg : Theme.primaryContainerFg
            readonly property var content: {
                if (root.mode === "pick") return ["colorize", "Click to copy a colour  ·  Arrows to nudge  ·  Esc to cancel"];
                if (root.mode === "window")
                    return Capture.windowsLoaded && root.localWindows.length === 0
                        ? ["info", "No windows on this screen  ·  Try Region or Screen"]
                        : ["web_asset", "Click a window  ·  Tab to cycle  ·  Esc to cancel"];
                if (root.mode === "screen") return ["desktop_windows", "Click or press Enter to capture this screen"];
                if (root.hasSel) return ["drag_pan", `Drag to adjust  ·  Alt disables snapping  ·  Enter to ${root.action === "record" ? "record" : "capture"}`];
                return ["crop_free", "Drag to select  ·  Click a window to snap  ·  Esc to cancel"];
            }

            RowLayout {
                id: hintRow
                anchors.centerIn: parent
                spacing: Tokens.space.s
                Icon {
                    text: hint.content[0]
                    size: 18
                    color: hint.fg
                }
                StyledText {
                    text: hint.content[1]
                    color: hint.fg
                }
            }
        }

        // ---- toolbar
        CaptureToolbar {
            id: toolbar
            visible: root.isPointerScreen
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.shown ? parent.height - height - Tokens.space.xxl : parent.height + 8
            canConfirm: root.target !== null || (root.mode === "region" && root.isPointerScreen)
            onConfirmRequested: root.confirm()
            onCancelRequested: Capture.cancel()
            Behavior on y { Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.springDefault } }
        }

        // ---- colour picker loupe
        Loupe {
            id: loupe
            visible: root.mode === "pick" && root.pointerSeen && root.isPointerScreen && root.frozen
            source: shot
            px: root.px
            py: root.py
            dpr: root.dpr
            picked: pixel.color
            hex: pixel.hex
            readonly property real off: 28
            x: root.px + off + width > root.width ? root.px - off - width : root.px + off
            y: root.py + off + height > root.height ? root.py - off - height : root.py + off
        }
    }

    // ---------------------------------------------------------------- keyboard

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: e => {
            const step = e.modifiers & Qt.ShiftModifier ? 10 : 1;
            const resize = !!(e.modifiers & Qt.ControlModifier);
            switch (e.key) {
            case Qt.Key_Escape:
                if (root.dragging) { root.dragKind = ""; root.setSel(root.startSel.x, root.startSel.y, root.startSel.w, root.startSel.h); }
                else Capture.cancel();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.confirm();
                break;
            case Qt.Key_Left: root.nudge(-step, 0, resize); break;
            case Qt.Key_Right: root.nudge(step, 0, resize); break;
            case Qt.Key_Up: root.nudge(0, -step, resize); break;
            case Qt.Key_Down: root.nudge(0, step, resize); break;
            case Qt.Key_Tab: if (root.mode === "window") root.cycleWindow(1); break;
            case Qt.Key_Backtab: if (root.mode === "window") root.cycleWindow(-1); break;
            case Qt.Key_R: Capture.setMode("region"); break;
            case Qt.Key_W: Capture.setMode("window"); break;
            case Qt.Key_S: Capture.setMode("screen"); break;
            case Qt.Key_C: Capture.setAction("screenshot"); break;
            case Qt.Key_T: Capture.setAction("ocr"); break;
            case Qt.Key_V: Capture.setAction("record"); break;
            case Qt.Key_P: Capture.setAction("pick"); break;
            case Qt.Key_A: if (root.action === "record") Capture.setAudio(!Capture.recordAudio); break;
            case Qt.Key_Delete:
            case Qt.Key_Backspace:
                root.clearSel();
                break;
            default:
                return;
            }
            e.accepted = true;
        }
    }

    Component.onCompleted: keys.forceActiveFocus()

    // ---------------------------------------------------------------- off-screen helpers

    // Crops the frozen frame at native resolution and saves it as PNG.
    Item {
        id: cropper
        property bool busy: false
        property rect cropRect: Qt.rect(0, 0, 1, 1)
        property string kind
        property string path
        readonly property size pixels: Qt.size(Math.max(1, Math.round(cropRect.width * root.dpr)), Math.max(1, Math.round(cropRect.height * root.dpr)))

        x: root.width + 64
        width: cropRect.width
        height: cropRect.height

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: cropper.busy ? shot : null
            sourceRect: cropper.cropRect
            textureSize: cropper.pixels
            hideSource: false
            live: true
        }

        function start(r, k) {
            cropper.busy = true;
            cropper.cropRect = Qt.rect(r.x, r.y, r.w, r.h);
            cropper.kind = k;
            cropper.path = k === "ocr" ? `${Capture.tempDir}/ocr-${Date.now()}.png` : Capture.nextScreenshotPath();
            cropTimer.restart();
        }

        Timer {
            id: cropTimer
            interval: 32   // let the effect source render once
            onTriggered: {
                const size = cropper.pixels, kind = cropper.kind, path = cropper.path;
                // grabToImage renders at the window's device pixel ratio, so ask
                // for the logical size to get native-resolution pixels.
                const logical = Qt.size(cropper.cropRect.width, cropper.cropRect.height);
                const ok = cropper.grabToImage(res => {
                    cropper.busy = false;
                    if (res.saveToFile(path))
                        Capture.finishImage(kind, path, size.width, size.height);
                    else
                        Capture.notifyError("Screenshot failed", `Could not write ${Capture.escapeHtml(path)}`);
                    Capture.finish();
                }, logical);
                if (!ok) {
                    cropper.busy = false;
                    Capture.notifyError("Screenshot failed", "Could not read the frozen frame.");
                    Capture.finish();
                }
            }
        }
    }

    // Reads pixels of the frozen frame for the colour picker.
    Canvas {
        id: pixel
        property bool ready: false
        property string url
        property color color: "black"
        property string hex: "#000000"

        x: -8
        width: 1
        height: 1
        canvasSize: Qt.size(1, 1)
        renderTarget: Canvas.Image

        function load() {
            if (!root.frozen || ready) return;
            shot.grabToImage(res => {
                pixel.url = res.url;
                // Grab results load synchronously and don't emit imageLoaded.
                if (!pixel.isImageLoaded(res.url)) pixel.loadImage(res.url);
                if (pixel.isImageLoaded(res.url)) pixel.imageLoaded();
            }, Qt.size(root.width, root.height));
        }

        function sample() {
            if (!ready || !available) return;
            const ctx = getContext("2d");
            // Source rect is in image pixels (native resolution).
            ctx.drawImage(url, Math.floor(root.px * root.dpr), Math.floor(root.py * root.dpr), 1, 1, 0, 0, 1, 1);
            const d = ctx.getImageData(0, 0, 1, 1).data;
            pixel.color = Qt.rgba(d[0] / 255, d[1] / 255, d[2] / 255, 1);
            const h = n => n.toString(16).padStart(2, "0");
            pixel.hex = `#${h(d[0])}${h(d[1])}${h(d[2])}`;
        }

        onImageLoaded: {
            pixel.ready = true;
            sample();
        }

        Connections {
            target: root
            enabled: root.mode === "pick"
            function onPxChanged() { pixel.sample(); }
            function onPyChanged() { pixel.sample(); }
        }
    }

    // Colour swatch rendered to a PNG for the picker notification.
    Rectangle {
        id: swatch
        property string hex
        x: root.width + 64
        y: root.height + 64
        width: 96
        height: 96
        radius: 24
        border.width: 2
        border.color: Qt.rgba(0.5, 0.5, 0.5, 0.35)

        function save() {
            const hexNow = hex, path = `${Capture.tempDir}/swatch-${hexNow.slice(1)}.png`;
            const ok = grabToImage(res => {
                const saved = res.saveToFile(path);
                Capture.finishPick(hexNow, saved ? path : "");
                Capture.finish();
            });
            if (!ok) {
                Capture.finishPick(hexNow, "");
                Capture.finish();
            }
        }
    }
}
