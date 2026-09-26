import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.settings
import "../controls"
import qs.components
import qs.services
import qs.config

// Displays: draggable arrangement canvas plus resolution / refresh / scale / rotation for
// the selected output. Changes are applied live through `hyprctl eval 'hl.monitor({...})'`
// with a 15 s confirm-or-revert window, and can be copied as Lua for hypr/Monitors/monitor.lua.
SettingsPage {
    id: root

    property var draft: ({})             // name -> { w, h, refresh, scale, transform, x, y, disabled }
    property var running: ({})          // same shape, as currently running
    property string activeOutput: ""
    property var revertLines: []
    property int countdown: 0

    readonly property var monitors: src.monitors
    readonly property var current: monitors.find(m => m.name === activeOutput) ?? null
    readonly property var cur: draft[activeOutput] ?? null
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(running)
    readonly property var modes: current ? parseModes(current.modes, current) : []
    readonly property var resolutions: {
        const seen = {}, out = [];
        for (const m of modes) {
            const key = `${m.w}x${m.h}`;
            if (seen[key]) continue;
            seen[key] = true;
            out.push({ value: key, label: `${m.w} × ${m.h}`, sublabel: aspect(m.w, m.h) });
        }
        return out;
    }
    readonly property var rates: cur ? modes.filter(m => m.w === cur.w && m.h === cur.h)
        .map(m => ({ value: m.r, label: `${m.r.toFixed(m.r % 1 ? 2 : 0)} Hz` })) : []
    readonly property var transforms: [
        { value: 0, label: "Normal", icon: "crop_landscape" },
        { value: 1, label: "90°", icon: "rotate_90_degrees_cw" },
        { value: 2, label: "180°", icon: "flip" },
        { value: 3, label: "270°", icon: "rotate_90_degrees_ccw" },
        { value: 4, label: "Flipped", icon: "flip" },
        { value: 5, label: "Flipped 90°", icon: "flip" },
        { value: 6, label: "Flipped 180°", icon: "flip" },
        { value: 7, label: "Flipped 270°", icon: "flip" }
    ]
    readonly property var scales: {
        const base = [0.75, 1, 1.25, 1.333333, 1.5, 1.6, 1.75, 2, 2.5, 3];
        const s = cur ? cur.scale : 1;
        const list = base.some(v => Math.abs(v - s) < 0.01) ? base : [...base, s].sort((a, b) => a - b);
        return list.map(v => ({ value: v, label: `${Math.round(v * 100)}%`, sublabel: cur ? `Looks like ${Math.round(cur.w / v)} × ${Math.round(cur.h / v)}` : "" }));
    }

    function aspect(w, h) {
        const g = (a, b) => b ? g(b, a % b) : a;
        const d = g(w, h);
        const r = `${w / d}:${h / d}`;
        return { "8:5": "16:10", "43:18": "21:9", "64:27": "21:9", "12:5": "21:9" }[r] ?? r;
    }
    function parseModes(list, m) {
        const out = [];
        for (const s of list ?? []) {
            const x = /^(\d+)x(\d+)@([\d.]+)/.exec(s);
            if (x) out.push({ w: +x[1], h: +x[2], r: Math.round(+x[3] * 100) / 100 });
        }
        if (!out.length && m) out.push({ w: m.width, h: m.height, r: Math.round(m.refresh * 100) / 100 });
        return out.sort((a, b) => b.w * b.h - a.w * a.h || b.r - a.r);
    }
    function specOf(m) {
        return { w: m.width, h: m.height, refresh: Math.round(m.refresh * 100) / 100, scale: Math.round(m.scale * 1e6) / 1e6,
                 transform: m.transform, x: m.x, y: m.y, disabled: m.disabled };
    }
    function reset() {
        const d = {};
        for (const m of monitors) d[m.name] = specOf(m);
        running = d;
        draft = JSON.parse(JSON.stringify(d));
        if (!monitors.some(m => m.name === activeOutput))
            activeOutput = (monitors.find(m => m.focused) ?? monitors[0])?.name ?? "";
    }
    function edit(name, patch) {
        const d = Object.assign({}, draft);
        d[name] = Object.assign({}, d[name], patch);
        draft = d;
    }
    function logical(s) {
        const rot = s.transform % 2 === 1;
        const w = Math.round(s.w / s.scale), h = Math.round(s.h / s.scale);
        return rot ? { w: h, h: w } : { w, h };
    }
    function luaFor(name, s) {
        if (s.disabled) return `hl.monitor({ output = "${name}", disabled = true })`;
        const scale = +s.scale.toFixed(6);
        return `hl.monitor({ output = "${name}", mode = "${s.w}x${s.h}@${s.refresh.toFixed(2)}", position = "${s.x}x${s.y}", scale = ${scale}, transform = ${s.transform} })`;
    }
    function lines(map, onlyChanged) {
        return Object.keys(map)
            .filter(n => !onlyChanged || JSON.stringify(map[n]) !== JSON.stringify(running[n]))
            .map(n => luaFor(n, map[n]));
    }
    function apply() {
        const changed = lines(draft, true);
        if (!changed.length) return;
        revertLines = Object.keys(draft)
            .filter(n => JSON.stringify(draft[n]) !== JSON.stringify(running[n]))
            .map(n => luaFor(n, running[n]));
        src.apply(changed);
        countdown = 15;
        tick.start();
    }
    function keep() {
        tick.stop();
        countdown = 0;
        revertLines = [];
        toast.show("Display settings kept. Copy the Lua to make them permanent.", "check");
    }
    function revert() {
        tick.stop();
        countdown = 0;
        if (revertLines.length) src.apply(revertLines);
        revertLines = [];
        toast.show("Display settings reverted", "undo");
    }

    title: "Displays"
    subtitle: "Arrange monitors and choose resolution, refresh rate, scale and rotation"

    onMonitorsChanged: if (!dirty || countdown > 0) reset()

    MonitorSource { id: src }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown <= 0) root.revert();
        }
    }

    EmptyState {
        visible: !src.available
        loading: src.loading
        icon: "desktop_access_disabled"
        title: src.loading ? "Reading monitors…" : !src.hyprland ? "Hyprland isn't running" : "No monitors reported"
        text: src.loading ? "" : !src.hyprland
            ? "Display configuration talks to Hyprland directly. Log in to a Hyprland session to arrange your monitors."
            : src.error || "Hyprland returned an empty monitor list."
        ActionButton { visible: src.hyprland && !src.loading; text: "Retry"; icon: "refresh"; kind: "tonal"; onClicked: src.refresh() }
    }

    Banner {
        visible: root.countdown > 0
        tone: "warning"
        icon: "timer"
        text: `Keep these display settings? Reverting in ${root.countdown} s.`
        ActionButton { text: "Revert"; onClicked: root.revert() }
        ActionButton { text: "Keep"; kind: "filled"; onClicked: root.keep() }
    }

    // ---------------- arrangement ----------------
    SettingsSection {
        title: "Arrangement"
        visible: src.available

        DisplayCanvas {
            Layout.fillWidth: true
            Layout.margins: Tokens.space.xs
            implicitHeight: Math.max(240, Math.min(340, width * 0.4))
            selected: root.activeOutput
            outputs: Object.keys(root.draft).filter(n => !root.draft[n].disabled).map(n => {
                const s = root.draft[n], l = root.logical(s), m = root.monitors.find(x => x.name === n);
                return { name: n, label: `${s.w} × ${s.h} · ${Math.round(s.scale * 100)}%`, x: s.x, y: s.y, w: l.w, h: l.h, focused: m?.focused };
            })
            onSelect: name => root.activeOutput = name
            onMoved: (name, x, y) => root.edit(name, { x, y })
        }
        StyledText {
            Layout.fillWidth: true
            Layout.margins: Tokens.space.s
            text: "Drag displays to match their physical layout. Edges snap together; arrow keys nudge the selected display (Shift ×10, Ctrl ×100)."
            font.pixelSize: Tokens.font.s
            color: Theme.surfaceVariantFg
            wrapMode: Text.Wrap
        }
    }

    // monitor tabs when more than one
    Flow {
        Layout.fillWidth: true
        visible: src.available && root.monitors.length > 1
        spacing: Tokens.space.s
        Repeater {
            model: root.monitors
            Surface {
                id: tab
                required property var modelData
                readonly property bool on: root.activeOutput === modelData.name
                implicitHeight: 36
                implicitWidth: tabRow.implicitWidth + Tokens.space.l * 2
                radius: on ? Tokens.radius.s : height / 2
                interactive: true
                base: on ? Theme.secondaryContainer : Theme.surfaceContainer
                content: on ? Theme.secondaryContainerFg : Theme.surfaceFg
                onClicked: root.activeOutput = modelData.name
                Behavior on radius { Anim { duration: Motion.duration.short } }
                Row {
                    id: tabRow
                    anchors.centerIn: parent
                    spacing: Tokens.space.xs
                    Icon { text: "monitor"; size: 18; color: tab.content; fill: tab.on ? 1 : 0 }
                    StyledText { text: tab.modelData.name; color: tab.content; font.weight: Font.Medium }
                }
            }
        }
    }

    // ---------------- selected output ----------------
    SettingsSection {
        title: root.current ? `${root.current.name}${root.current.make ? " — " + [root.current.make, root.current.model].join(" ").trim() : ""}` : ""
        visible: src.available && root.cur !== null

        SettingsRow {
            icon: "power_settings_new"
            label: "Use this display"
            description: root.enabledCount <= 1 && !(root.cur?.disabled ?? true) ? "Can't turn off the only active display" : ""
            SettingsSwitch {
                checked: !(root.cur?.disabled ?? false)
                opacity: root.enabledCount <= 1 && !(root.cur?.disabled ?? true) ? 0.4 : 1
                onToggled: {
                    if (!root.cur.disabled && root.enabledCount <= 1) return;
                    root.edit(root.activeOutput, { disabled: !root.cur.disabled });
                }
            }
        }
        SettingsRow {
            icon: "aspect_ratio"
            label: "Resolution"
            visible: !(root.cur?.disabled ?? true)
            Select {
                implicitWidth: 260
                options: root.resolutions
                value: root.cur ? `${root.cur.w}x${root.cur.h}` : ""
                onSelected: v => {
                    const [w, h] = v.split("x").map(Number);
                    const best = root.modes.filter(m => m.w === w && m.h === h).sort((a, b) => b.r - a.r)[0];
                    root.edit(root.activeOutput, { w, h, refresh: best?.r ?? root.cur.refresh });
                }
            }
        }
        SettingsRow {
            icon: "speed"
            label: "Refresh rate"
            visible: !(root.cur?.disabled ?? true)
            Select {
                implicitWidth: 260
                options: root.rates
                value: root.cur?.refresh
                placeholder: root.cur ? `${root.cur.refresh} Hz` : ""
                onSelected: v => root.edit(root.activeOutput, { refresh: v })
            }
        }
        SettingsRow {
            icon: "zoom_in"
            label: "Scale"
            description: "Fractional scales must divide the resolution evenly or Hyprland picks the closest valid one"
            visible: !(root.cur?.disabled ?? true)
            Select {
                implicitWidth: 260
                options: root.scales
                value: root.cur ? (root.scales.find(o => Math.abs(o.value - root.cur.scale) < 0.001)?.value ?? root.cur.scale) : 1
                onSelected: v => root.edit(root.activeOutput, { scale: v })
            }
        }
        SettingsRow {
            icon: "screen_rotation"
            label: "Rotation"
            visible: !(root.cur?.disabled ?? true)
            Select {
                implicitWidth: 260
                options: root.transforms
                value: root.cur?.transform ?? 0
                onSelected: v => root.edit(root.activeOutput, { transform: v })
            }
        }
        SettingsRow {
            icon: "open_with"
            label: "Position"
            description: "Top-left corner in the global layout (logical pixels)"
            visible: !(root.cur?.disabled ?? true)
            InputField {
                Layout.preferredWidth: 110
                Layout.fillWidth: false
                label: "X"
                mono: true
                text: String(root.cur?.x ?? 0)
                validator: IntValidator { bottom: -32768; top: 32768 }
                onEditingFinished: if (+text !== root.cur.x) root.edit(root.activeOutput, { x: +text })
            }
            InputField {
                Layout.preferredWidth: 110
                Layout.fillWidth: false
                label: "Y"
                mono: true
                text: String(root.cur?.y ?? 0)
                validator: IntValidator { bottom: -32768; top: 32768 }
                onEditingFinished: if (+text !== root.cur.y) root.edit(root.activeOutput, { y: +text })
            }
        }
    }

    readonly property int enabledCount: Object.keys(draft).filter(n => !draft[n].disabled).length

    // ---------------- apply bar ----------------
    Rectangle {
        Layout.fillWidth: true
        visible: src.available
        implicitHeight: applyCol.implicitHeight + Tokens.space.l * 2
        radius: Tokens.radius.l
        color: root.dirty ? Theme.secondaryContainer : Theme.surfaceContainer
        Behavior on color { ColorAnim {} }

        ColumnLayout {
            id: applyCol
            anchors.fill: parent
            anchors.margins: Tokens.space.l
            spacing: Tokens.space.m

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.s
                Icon {
                    text: root.dirty ? "pending" : "check_circle"
                    size: 22
                    color: root.dirty ? Theme.secondaryContainerFg : Theme.primary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.dirty ? "You have unapplied changes" : "Matches the running configuration"
                    font.weight: Font.Medium
                    color: root.dirty ? Theme.secondaryContainerFg : Theme.surfaceFg
                }
                ActionButton {
                    text: "Reset"
                    icon: "undo"
                    enabled: root.dirty && root.countdown === 0
                    onClicked: root.reset()
                }
                ActionButton {
                    text: "Copy Lua"
                    icon: "content_copy"
                    kind: "outlined"
                    onClicked: {
                        Quickshell.clipboardText = root.lines(root.draft, false).join("\n") + "\n";
                        toast.show("Copied — paste into hypr/Monitors/monitor.lua", "content_copy");
                    }
                }
                ActionButton {
                    text: "Apply"
                    icon: "done"
                    kind: "filled"
                    enabled: root.dirty && root.countdown === 0
                    onClicked: root.apply()
                }
            }

            // Lua preview
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: luaText.implicitHeight + Tokens.space.m * 2
                radius: Tokens.radius.s
                color: Theme.surfaceLowest
                Text {
                    id: luaText
                    x: Tokens.space.m
                    y: Tokens.space.m
                    width: parent.width - Tokens.space.m * 2
                    text: root.lines(root.draft, false).join("\n")
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.s
                    color: Theme.surfaceVariantFg
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }
            }
        }
    }

    Toast { id: toast }
}
