pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Profile picture. Stored as ~/.face (the file login screens and GNOME read);
// setting one also tells AccountsService, so GDM/GNOME show the same picture.
// Shown in Dashboard → Info and Settings → About, both with an edit button.
// IPC: `rice ipc call avatar set <image>`, `clear`, `pick` (opens the picker).
Singleton {
    id: root

    property string path: ""
    property int version: 0
    // Cache-busting query so a replaced ~/.face reloads everywhere.
    readonly property string source: path ? `file://${path}?v=${version}` : ""
    readonly property string facePath: `${Paths.home}/.face`

    // Settings shows the picker while this is true.
    property bool picking: false

    function pick() {
        Panels.openSettings("About");
        picking = true;
    }

    function set(file) {
        if (!file) return;
        picking = false;
        writer.command = ["sh", "-c", `
            set -e
            cp -f -- "$1" "$2.tmp" && mv -f -- "$2.tmp" "$2"
            rm -f -- "$HOME/.face.icon"
            gdbus call --system --dest org.freedesktop.Accounts \\
                --object-path "/org/freedesktop/Accounts/User$(id -u)" \\
                --method org.freedesktop.Accounts.User.SetIconFile "$2" >/dev/null 2>&1 || true`,
            "sh", String(file).replace(/^file:\/\//, ""), facePath];
        writer.running = true;
    }

    function clear() {
        picking = false;
        writer.command = ["sh", "-c", `
            rm -f -- "$HOME/.face" "$HOME/.face.icon"
            gdbus call --system --dest org.freedesktop.Accounts \\
                --object-path "/org/freedesktop/Accounts/User$(id -u)" \\
                --method org.freedesktop.Accounts.User.SetIconFile "" >/dev/null 2>&1 || true`];
        writer.running = true;
    }

    function refresh() { finder.running = true; }

    Component.onCompleted: refresh()

    Process {
        id: finder
        command: ["sh", "-c", `
            for f in "$HOME/.face" "$HOME/.face.icon" "/var/lib/AccountsService/icons/$(id -un)"; do
                [ -s "$f" ] && { printf '%s' "$f"; break; }
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.path = text.trim();
                root.version++;
            }
        }
    }

    Process {
        id: writer
        onExited: code => {
            if (code !== 0) Quickshell.execDetached(["notify-send", "-a", "rice", "Profile picture", "Couldn't copy the image to ~/.face"]);
            root.refresh();
        }
    }

    IpcHandler {
        target: "avatar"
        function set(file: string): void { root.set(file); }
        function clear(): void { root.clear(); }
        function pick(): void { root.pick(); }
        function get(): string { return root.path; }
    }
}
