pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, temperature and root-disk usage, polled every 2s.
Singleton {
    id: root

    property real cpu: 0
    property real memory: 0
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real temperature: 0
    property real disk: 0
    property string tempPath: ""
    property string uptime: ""

    property var lastCpu: null

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 2000
        onTriggered: {
            stat.reload();
            meminfo.reload();
            upt.reload();
            if (root.tempPath) temp.reload();
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 60000
        onTriggered: df.running = true
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + (f[4] || 0);
            const total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                if (dt > 0) root.cpu = 1 - (idle - root.lastCpu.idle) / dt;
            }
            root.lastCpu = { idle, total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const get = key => parseInt((t.match(new RegExp(`^${key}:\\s+(\\d+)`, "m")) || [0, 0])[1]);
            const total = get("MemTotal");
            const avail = get("MemAvailable");
            if (total > 0) {
                root.memory = 1 - avail / total;
                root.memTotalGiB = total / 1048576;
                root.memUsedGiB = (total - avail) / 1048576;
            }
        }
    }

    FileView {
        id: upt
        path: "/proc/uptime"
        onLoaded: {
            const s = Math.floor(parseFloat(text()));
            const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
            root.uptime = (d ? `${d}d ` : "") + (h ? `${h}h ` : "") + `${m}m`;
        }
    }

    FileView {
        id: temp
        path: root.tempPath
        onLoaded: root.temperature = parseInt(text()) / 1000
    }

    // Prefer the CPU package sensor; fall back to the first thermal zone.
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case \"$(cat $h/name)\" in coretemp|k10temp|zenpower) echo $h/temp1_input; exit;; esac; done; for z in /sys/class/thermal/thermal_zone*; do [ \"$(cat $z/type)\" = x86_pkg_temp ] && echo $z/temp && exit; done; echo /sys/class/thermal/thermal_zone0/temp"]
        stdout: StdioCollector {
            onStreamFinished: root.tempPath = text.trim()
        }
    }

    Process {
        id: df
        command: ["df", "--output=pcent", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseInt(text.split("\n")[1]);
                if (!isNaN(pct)) root.disk = pct / 100;
            }
        }
    }
}
