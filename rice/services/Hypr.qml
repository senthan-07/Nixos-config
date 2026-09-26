pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Thin wrapper over Hyprland IPC that works with both the Lua and the
// classic hyprlang config front-ends.
Singleton {
    readonly property bool lua: Hyprland.usingLua

    function focusWorkspace(target) {
        if (lua)
            Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = ${JSON.stringify(String(target))} })`]);
        else
            Hyprland.dispatch(`workspace ${target}`);
    }

    function exit() {
        if (lua)
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]);
        else
            Hyprland.dispatch("exit");
    }
}
