pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`
    readonly property string picturesDir: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`

    // Dotfiles repo (symlinked into ~/.config). Generated app themes and
    // autostart entries are written here. The `rice` wrapper exports
    // RICE_DOTFILES by resolving the ~/.config/hypr link.
    readonly property string dotfiles: Quickshell.env("RICE_DOTFILES") || `${home}/Modules/nixos/rice/Dotfiles`

    readonly property string state: `${stateHome}/rice`
    readonly property string settingsFile: `${state}/settings.json`
    readonly property string schemeFile: `${state}/scheme.json`
    readonly property string appUsageFile: `${state}/app-usage.json`
    readonly property string wallpaperDir: `${picturesDir}/Wallpapers`

    function stripFileUrl(path) {
        return String(path).replace(/^file:\/\//, "");
    }
}
