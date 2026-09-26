import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services

// ext-session-lock based lock screen. One PAM conversation is shared by all
// monitors; each gets its own LockSurface.
Scope {
    id: root

    property string message: ""
    property bool failed: false
    property bool busy: false
    property string buffer: ""

    function submit(password) {
        if (busy || !password) return;
        buffer = password;
        busy = true;
        failed = false;
        pam.start();
    }

    PamContext {
        id: pam
        config: "rice-lock"
        configDirectory: "/etc/pam.d"

        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.buffer);
                root.buffer = "";
            }
        }
        onPamMessage: if (messageIsError) root.message = message
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.message = "";
                Panels.locked = false;
            } else {
                root.failed = true;
                root.message = result === PamResult.MaxTries ? "Too many attempts" : "Wrong password";
            }
        }
        onError: err => {
            root.busy = false;
            root.failed = true;
            root.message = "Authentication error";
        }
    }

    WlSessionLock {
        id: lock
        locked: Panels.locked

        LockSurface {
            context: root
        }
    }
}
