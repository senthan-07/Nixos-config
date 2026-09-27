import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Alt+Tab window switcher. Hyprland binds (Dotfiles/hypr/Rice/rice.lua):
//   Alt+Tab        -> `switcher next`   (opens, then moves right)
//   Alt+Shift+Tab  -> `switcher prev`
//   release Alt    -> `switcher commit` (focus the selected window)
// Windows on the current workspace are listed most recently used first.
Scope {
    id: root

    property bool open: false
    property int index: 0
    property var windows: []          // [{ toplevel, wayland, title, cls, ws, icon, name }]

    function refresh() {
        Hyprland.refreshToplevels();
        const wsId = Hyprland.focusedMonitor?.activeWorkspace?.id;
        const list = Hyprland.toplevels.values
            .filter(t => t.wayland && t.lastIpcObject && t.lastIpcObject.mapped !== false)
            .filter(t => (t.lastIpcObject.workspace?.id ?? t.workspace?.id) === wsId)
            .map(t => {
                const o = t.lastIpcObject;
                const cls = o.class || t.wayland.appId || "";
                const entry = DesktopEntries.heuristicLookup(cls);
                return {
                    toplevel: t, wayland: t.wayland,
                    title: t.title || o.title || cls,
                    cls, name: entry?.name ?? cls,
                    icon: entry?.icon ?? cls,
                    ws: o.workspace?.name ?? "",
                    order: o.focusHistoryID ?? 999
                };
            })
            .sort((a, b) => a.order - b.order);
        windows = list;
    }

    function step(d) {
        if (!open) {
            refresh();
            if (windows.length < 2) return;        // nothing to switch to
            open = true;
            // Start on the previously used window (index 1), like other desktops.
            index = windows.length > 1 ? (d > 0 ? 1 : windows.length - 1) : 0;
            return;
        }
        if (windows.length) index = (index + d + windows.length) % windows.length;
    }

    function commit() {
        if (!open) return;
        const w = windows[index];
        open = false;
        if (w) w.wayland.activate();
    }

    function cancel() { open = false; }

    IpcHandler {
        target: "switcher"
        function next(): void { root.step(1); }
        function prev(): void { root.step(-1); }
        function commit(): void { root.commit(); }
        function cancel(): void { root.cancel(); }
    }

    // Toplevel info arrives asynchronously; rebuild while open.
    Connections {
        target: Hyprland
        enabled: root.open
        function onRawEvent(e) {
            if (["openwindow", "closewindow", "windowtitlev2"].includes(e.name)) root.refresh();
        }
    }

    PanelWindow {
        id: win
        visible: root.open
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "rice-switcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Keyboard fallback in case the release bind isn't delivered.
        Item {
            anchors.fill: parent
            focus: true
            Keys.onReleased: e => { if (e.key === Qt.Key_Alt || e.key === Qt.Key_Meta) root.commit(); }
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) root.cancel();
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.commit();
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) root.step(1);
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) root.step(-1);
                else return;
                e.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.scrim, 0.25)
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            readonly property int tile: 148
            readonly property int perRow: Math.max(1, Math.min(root.windows.length, Math.floor((win.width * 0.85) / (tile + Tokens.space.s))))
            width: Math.min(win.width * 0.9, perRow * (tile + Tokens.space.s) + Tokens.space.l * 2 - Tokens.space.s)
            height: grid.implicitHeight + Tokens.space.l * 2
            radius: Tokens.radius.xl
            color: Theme.alpha(Theme.surfaceContainer, Settings.data.surfaceOpacity)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.6)

            Grid {
                id: grid
                anchors.centerIn: parent
                columns: card.perRow
                spacing: Tokens.space.s

                Repeater {
                    model: root.windows

                    Surface {
                        id: tileItem
                        required property var modelData
                        required property int index
                        readonly property bool current: index === root.index

                        width: card.tile
                        height: 132
                        radius: Tokens.radius.l
                        interactive: true
                        base: current ? Theme.secondaryContainer : Theme.alpha(Theme.surfaceHigh, 0.6)
                        content: current ? Theme.secondaryContainerFg : Theme.surfaceFg
                        border.width: current ? 2 : 0
                        border.color: Theme.primary
                        onClicked: { root.index = index; root.commit(); }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.space.m
                            spacing: Tokens.space.xs

                            AppIcon {
                                Layout.alignment: Qt.AlignHCenter
                                size: 52
                                name: tileItem.modelData.icon
                            }
                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: tileItem.modelData.name
                                font.weight: Font.DemiBold
                                color: tileItem.content
                            }
                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: tileItem.modelData.title
                                font.pixelSize: Tokens.font.xs
                                color: Theme.alpha(tileItem.content, 0.75)
                            }
                        }

                        // Workspace badge
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Tokens.space.s
                            visible: false   // all windows are on the current workspace
                            width: Math.max(20, wsText.implicitWidth + 10)
                            height: 20
                            radius: 10
                            color: Theme.alpha(tileItem.content, 0.12)
                            StyledText {
                                id: wsText
                                anchors.centerIn: parent
                                text: tileItem.modelData.ws
                                font.pixelSize: Tokens.font.xs
                                font.weight: Font.Bold
                                color: tileItem.content
                            }
                        }
                    }
                }
            }
        }
    }
}
