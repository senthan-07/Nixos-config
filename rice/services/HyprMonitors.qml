pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Reactive screen -> Hyprland monitor lookup. Hyprland.monitorFor() is a plain
// function call, so bindings using it never update; at login rice starts
// before Hyprland has reported its monitors and they stayed null until a
// restart. Reading Hyprland.monitors here makes bindings re-evaluate.
Singleton {
    function forScreen(screen) {
        if (!screen) return null;
        return Hyprland.monitors.values.find(m => m.name === screen.name) ?? null;
    }
}
