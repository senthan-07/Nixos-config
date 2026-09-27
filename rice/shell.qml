//@ pragma UseQApplication
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// Rice — a Material 3 desktop shell for Hyprland, built on Quickshell.
// Loosely modelled on the Clavis shell (github.com/StatIndet/quickshell),
// rewritten from scratch for Hyprland.

import QtQuick
import Quickshell
import qs.services
import qs.modules.background
import qs.modules.bar
import qs.modules.capture
import qs.modules.cards
import qs.modules.dashboard
import qs.modules.dock
import qs.modules.island
import qs.modules.keyboard
import qs.modules.launcher
import qs.modules.lock
import qs.modules.notifications
import qs.modules.osd
import qs.modules.polkit
import qs.modules.power
import qs.modules.settings
import qs.modules.sidebar
import qs.modules.switcher

ShellRoot {
    Component.onCompleted: {
        // Singletons are created lazily; touch the ones that must run from
        // startup (IPC targets, notification server, idle/night light,
        // polkit agent, weather cache, first-run theming).
        Panels.ready;
        Avatar.path;
        Notifs.popups;
        Ecosystem.enabled;
        Idle.enabled;
        NightLight.enabled;
        Polkit.active;
        Weather.ready;
        DashboardState.open;
        IslandState.mode;
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property ShellScreen modelData

            Wallpaper { screen: perScreen.modelData }
            DesktopCanvas { screen: perScreen.modelData }
            Bar { screen: perScreen.modelData }
            Island { screen: perScreen.modelData }
        }
    }

    DockHost {}
    Launcher {}
    Switcher {}
    Sidebar {}
    Dashboard {}
    NotificationPopups {}
    Osd {}
    ReloadToast {}
    LockKeysOsd {}
    CaptureOverlay {}
    PowerMenu {}
    PolkitDialog {}
    Lock {}
    SettingsApp {}
}
