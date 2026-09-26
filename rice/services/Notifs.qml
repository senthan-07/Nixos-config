pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

Singleton {
    id: root

    readonly property var history: server.trackedNotifications.values
    property var popups: []
    readonly property bool dnd: Settings.data.doNotDisturb

    function hide(n) {
        popups = popups.filter(p => p !== n);
    }

    function clear() {
        for (const n of [...history]) n.dismiss();
        popups = [];
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            n.closed.connect(() => root.hide(n));
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n, ...root.popups].slice(0, 5);
        }
    }

    IpcHandler {
        target: "notifs"
        function clear(): void { root.clear(); }
        function toggleDnd(): void { Settings.data.doNotDisturb = !Settings.data.doNotDisturb; }
    }
}
