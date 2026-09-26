pragma Singleton

import QtQuick
import Quickshell
import qs.config

Singleton {
    readonly property date now: clock.date
    readonly property string time: Qt.formatTime(now, Settings.data.use24h
        ? (Settings.data.showSeconds ? "HH:mm:ss" : "HH:mm")
        : (Settings.data.showSeconds ? "h:mm:ss AP" : "h:mm AP"))
    readonly property string date: Qt.formatDate(now, Settings.data.dateFormat || "ddd, d MMM")

    function format(fmt) {
        return Qt.formatDateTime(now, fmt);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
