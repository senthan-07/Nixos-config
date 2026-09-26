import QtQuick
import Quickshell
import Quickshell.Hyprland

// Monitor data for the Displays page, read from Hyprland (`hyprctl -j monitors all`, so
// disabled outputs are included) and refreshed on Hyprland monitor events.
// Each monitor: { name, description, make, model, x, y, width, height, refresh, scale,
//                 transform, modes: ["WxH@R", …], focused, disabled }
Item {
    id: root

    readonly property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property bool available: hyprland && monitors.length > 0
    property bool loading: hyprland
    property var monitors: []
    property string error: ""

    function refresh() {
        if (!hyprland) { loading = false; return; }
        q.start(["hyprctl", "-j", "monitors", "all"]);
    }

    // Apply Lua `hl.monitor({...})` specs one by one.
    function apply(lines) {
        for (const line of lines) Exec.run(["hyprctl", "eval", line]);
        settle.restart();
    }

    Component.onCompleted: refresh()

    Timer { id: settle; interval: 900; onTriggered: root.refresh() }

    Connections {
        target: root.hyprland ? Hyprland : null
        function onRawEvent(event) {
            if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name))
                settle.restart();
        }
    }

    Query {
        id: q
        onFinished: (out, code) => {
            root.loading = false;
            if (code !== 0) { root.error = out.trim() || "hyprctl failed"; return; }
            try {
                root.error = "";
                root.monitors = JSON.parse(out).map(m => ({
                    name: m.name, description: m.description ?? "", make: m.make ?? "", model: m.model ?? "",
                    x: m.x ?? 0, y: m.y ?? 0, width: m.width, height: m.height,
                    refresh: m.refreshRate ?? 60, scale: m.scale ?? 1, transform: m.transform ?? 0,
                    modes: m.availableModes ?? [], focused: m.focused ?? false, disabled: m.disabled ?? false
                }));
            } catch (e) {
                root.error = `Couldn't read monitor list: ${e}`;
            }
        }
    }
}
