pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// Polkit authentication agent. Registers for the current session and exposes
// the active request as plain properties for modules/polkit/PolkitDialog.qml.
// Values stay populated after the request ends so the dialog can animate out.
//
// Set RICE_NO_POLKIT=1 to keep another agent (e.g. under GNOME).
Singleton {
    id: root

    readonly property bool registered: loader.item ? loader.item.isRegistered : false
    readonly property var flow: loader.item ? loader.item.flow : null

    // Dialog state.
    property bool active: false
    property string message: ""
    property string iconName: ""
    property string actionId: ""
    property var identities: []          // display names
    property int identityIndex: 0
    property string prompt: ""
    property bool echo: false
    property string info: ""
    property bool infoIsError: false
    property bool busy: false
    property int failures: 0

    signal failed()
    signal succeeded()

    function identityName(identity) {
        if (!identity) return "";
        return identity.displayName || identity.name || String(identity.id !== undefined ? identity.id : "");
    }

    function sync() {
        const f = flow;
        if (!f) {
            active = false;
            busy = false;
            return;
        }
        message = f.message || "Authentication is required";
        iconName = f.iconName || "";
        actionId = f.actionId || "";
        const ids = f.identities || [];
        const names = [];
        for (let i = 0; i < ids.length; i++) names.push(identityName(ids[i]));
        identities = names;
        identityIndex = Math.max(0, Array.prototype.indexOf.call(ids, f.selectedIdentity));
        prompt = cleanPrompt(f.inputPrompt);
        echo = f.responseVisible;
        info = f.supplementaryMessage || "";
        infoIsError = f.supplementaryIsError;
        busy = !f.isResponseRequired && !f.isCompleted;
        failures = 0;
        active = true;
    }

    // PAM prompts look like "Password: "; the dialog labels the field itself.
    function cleanPrompt(p) {
        const s = String(p || "").trim().replace(/:$/, "");
        return s || "Password";
    }

    function submit(text) {
        if (!flow || !flow.isResponseRequired) return;
        busy = true;
        info = "";
        flow.submit(text);
    }

    function cancel() {
        if (flow) flow.cancelAuthenticationRequest();
        active = false;
        busy = false;
    }

    function selectIdentity(index) {
        const f = flow;
        if (!f || !f.identities || index < 0 || index >= f.identities.length) return;
        f.selectedIdentity = f.identities[index];
        identityIndex = index;
    }

    onFlowChanged: sync()

    Connections {
        target: root.flow
        ignoreUnknownSignals: true

        function onIsResponseRequiredChanged() {
            const f = root.flow;
            root.busy = !f.isResponseRequired && !f.isCompleted;
            if (f.isResponseRequired) {
                root.prompt = root.cleanPrompt(f.inputPrompt);
                root.echo = f.responseVisible;
            }
        }
        function onInputPromptChanged() { root.prompt = root.cleanPrompt(root.flow.inputPrompt); }
        function onResponseVisibleChanged() { root.echo = root.flow.responseVisible; }
        function onSupplementaryMessageChanged() {
            root.info = root.flow.supplementaryMessage || "";
            root.infoIsError = root.flow.supplementaryIsError;
        }
        function onSelectedIdentityChanged() {
            const ids = root.flow.identities || [];
            root.identityIndex = Math.max(0, Array.prototype.indexOf.call(ids, root.flow.selectedIdentity));
        }
        function onAuthenticationFailed() {
            root.busy = false;
            root.failures += 1;
            root.info = "Wrong password. Try again.";
            root.infoIsError = true;
            root.failed();
        }
        function onAuthenticationSucceeded() {
            root.busy = false;
            root.succeeded();
        }
        function onIsCompletedChanged() {
            if (root.flow.isCompleted) {
                root.busy = false;
                root.active = false;
            }
        }
    }

    LazyLoader {
        id: loader
        active: Quickshell.env("RICE_NO_POLKIT") !== "1"

        PolkitAgent {}
    }
}
