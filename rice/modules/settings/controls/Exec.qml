pragma Singleton

import QtQuick
import Quickshell

// Single choke point for every state-changing action the system pages take.
// With RICE_SETTINGS_DRYRUN=1 nothing is executed; actions are only logged
// (used by the headless test harness so real devices are never touched).
Singleton {
    id: root

    readonly property bool dryRun: Quickshell.env("RICE_SETTINGS_DRYRUN") === "1"
    // Last dry-run action, handy for asserting in tests.
    property string lastAction: ""

    // Run a detached command (argv array).
    function run(argv) {
        if (dryRun) {
            lastAction = argv.join(" ");
            console.info("rice-settings[dry-run]:", lastAction);
            return;
        }
        Quickshell.execDetached(argv);
    }

    // Guard for in-process mutations (Networking/Bluetooth/Pipewire objects).
    // Returns true when the caller may go ahead.
    function allow(what) {
        if (dryRun) {
            lastAction = what;
            console.info("rice-settings[dry-run]:", what);
            return false;
        }
        return true;
    }

    // Shell-quote one argument for display / copy-to-clipboard strings.
    function quote(s) {
        return `'${String(s).replace(/'/g, `'\\''`)}'`;
    }
}
