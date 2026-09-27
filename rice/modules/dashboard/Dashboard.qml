import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Left-hand dashboard: weather and system info, each on its own tab. Slides in from the left edge; Escape or an outside click closes it.
//   Esc                close        Ctrl+Tab / Ctrl+Shift+Tab   next / previous tab
//   Ctrl+1..2          jump to tab  wheel over the tab bar       switch tab
//   ↑ ↓ PgUp PgDn Home End  scroll weather / info    R  refresh weather
PanelWindow {
    id: root

    readonly property bool shown: DashboardState.open
    readonly property int panelWidth: 452

    screen: Quickshell.screens[0]
    visible: shown || panel.x > -panelWidth - Tokens.space.m + 1
    anchors { top: true; bottom: true; left: true }
    margins { top: Tokens.space.s; bottom: Tokens.space.s; left: Tokens.space.s }
    implicitWidth: panelWidth
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "rice-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Outside clicks close the panel (Hyprland only; elsewhere the grab would
    // be cleared immediately and close it again).
    DelayedFocusGrab {
        windows: [root]
        want: root.shown && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== null
        onCleared: DashboardState.dismiss()
    }

    onShownChanged: if (shown) keys.forceActiveFocus()

    // Views are created on first use and kept afterwards so switching back is
    // instant and keeps scroll positions.
    function loadCurrent() {
        const loader = ({ weather: weather, info: info })[DashboardState.view];
        if (loader && !loader.active) loader.active = true;
    }
    Component.onCompleted: loadCurrent()
    Connections {
        target: DashboardState
        function onViewChanged() { root.loadCurrent(); }
    }

    Rectangle {
        id: panel
        width: root.panelWidth
        height: parent.height
        x: root.shown ? 0 : -width - Tokens.space.m
        radius: Tokens.radius.xl
        color: Theme.surface
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.5)
        clip: true

        Behavior on x {
            Anim {
                duration: root.shown ? Motion.duration.long : Motion.duration.short + 50
                easing.bezierCurve: root.shown ? Motion.curve.emphasizedDecel : Motion.curve.emphasizedAccel
            }
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    DashboardState.close();
                } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
                    DashboardState.cycle(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                } else if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_2) {
                    DashboardState.setView(DashboardState.views[event.key - Qt.Key_1]);
                } else if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_PageUp, Qt.Key_PageDown, Qt.Key_Home, Qt.Key_End].includes(event.key)) {
                    const view = (DashboardState.view === "weather" ? weather : info).item;
                    const page = keys.height * 0.8;
                    view?.scrollBy(({ [Qt.Key_Up]: -80, [Qt.Key_Down]: 80, [Qt.Key_PageUp]: -page, [Qt.Key_PageDown]: page, [Qt.Key_Home]: -1e6, [Qt.Key_End]: 1e6 })[event.key]);
                } else if (DashboardState.view === "weather" && event.key === Qt.Key_R && !(event.modifiers & Qt.ControlModifier)) {
                    Weather.refresh();
                } else {
                    return;
                }
                event.accepted = true;
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.space.m
                spacing: Tokens.space.m

                DashTabs {
                    Layout.fillWidth: true
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Loader {
                        id: weather
                        anchors.fill: parent
                        active: false
                        visible: DashboardState.view === "weather"
                        opacity: visible ? 1 : 0
                        sourceComponent: WeatherView {
                            active: root.shown && DashboardState.view === "weather"
                        }
                    }

                    Loader {
                        id: info
                        anchors.fill: parent
                        active: false
                        visible: DashboardState.view === "info"
                        sourceComponent: InfoView {
                            active: root.shown && DashboardState.view === "info"
                        }
                    }
                }
            }
        }
    }
}
