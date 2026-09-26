import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Owns the settings window and its IPC target. Open state lives in
// Panels.settings / Panels.settingsPage so any module can open a page.
Scope {
    id: root

    SettingsWindow {}

    IpcHandler {
        target: "settings"
        function open(): void { Panels.openSettings(""); }
        function page(name: string): void { Panels.openSettings(name); }
        function toggle(): void { Panels.settings ? (Panels.settings = false) : Panels.openSettings(""); }
    }
}
