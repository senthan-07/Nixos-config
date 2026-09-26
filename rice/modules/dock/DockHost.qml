import QtQuick
import Quickshell
import qs.services

// Root of the dock: one DockWindow per screen while the dock is enabled.
//   shell.qml:  import qs.modules.dock   …   DockHost {}
Scope {
    Variants {
        model: Dock.enabled ? Quickshell.screens : []

        DockWindow {
            required property ShellScreen modelData
            screen: modelData
        }
    }
}
