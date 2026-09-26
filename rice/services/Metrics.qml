pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Rolling one-minute histories for the system cards (1 Hz, 60 samples).
// CPU and network are read here directly from /proc so graphs move every
// second; memory and temperature come from SysStats. The GPU is read from
// amdgpu's sysfs counter; nvidia-smi is used only when no iGPU counter exists
// and the card is awake (polling a dGPU keeps it from runtime-suspending).
Singleton {
    id: root

    readonly property int historyLength: 60

    // Current values. Ratios are 0..1, rates are bytes per second.
    property real cpu: 0
    readonly property real memory: SysStats.memory
    readonly property real temperature: SysStats.temperature
    property real rxRate: 0
    property real txRate: 0
    property real rxTotal: 0
    property real txTotal: 0
    property string iface: ""

    // GPU: `gpuAvailable` means a readable utilisation source exists.
    property bool gpuAvailable: false
    property real gpu: 0
    property real gpuTemp: NaN
    property real gpuMemUsed: NaN      // MiB
    property real gpuMemTotal: NaN     // MiB
    property string gpuName: ""
    property bool gpuAsleep: false     // NVIDIA-only systems: dGPU runtime-suspended

    // Histories, oldest first. Replaced (not mutated) so bindings update.
    property var cpuHistory: []
    property var memHistory: []
    property var tempHistory: []
    property var gpuHistory: []
    property var rxHistory: []
    property var txHistory: []

    // Mounted filesystems: [{mount, fs, size, used, avail, pct}] (bytes, pct 0..1).
    property var disks: []
    property bool disksReady: false

    // Filled by the probe: [{kind: "amd"|"nvidia", dir: "/sys/class/drm/cardN/device"}]
    property var gpuSources: []

    property var lastCpu: null
    property var lastNet: null

    function push(list, value) {
        const out = list.length >= historyLength ? list.slice(list.length - historyLength + 1) : list.slice();
        out.push(value);
        return out;
    }

    function formatRate(bytes) {
        return formatBytes(bytes) + "/s";
    }

    function formatBytes(bytes) {
        const b = Math.max(0, Number(bytes) || 0);
        const units = ["B", "KB", "MB", "GB", "TB"];
        let v = b, i = 0;
        while (v >= 1000 && i < units.length - 1) { v /= 1024; i++; }
        return (v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i];
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: {
            stat.reload();
            netdev.reload();
            root.sampleGpu();
            root.memHistory = root.push(root.memHistory, SysStats.memory);
            if (SysStats.temperature > 0)
                root.tempHistory = root.push(root.tempHistory, SysStats.temperature);
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 30000
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
                if (dt > 0) {
                    root.cpu = Math.max(0, Math.min(1, 1 - (idle - root.lastCpu.idle) / dt));
                    root.cpuHistory = root.push(root.cpuHistory, root.cpu);
                }
            }
            root.lastCpu = { idle, total };
        }
    }

    // Sum every physical-looking interface; report the busiest one by name.
    FileView {
        id: netdev
        path: "/proc/net/dev"
        onLoaded: {
            const lines = text().split("\n").slice(2);
            let rx = 0, tx = 0, best = "", bestBytes = -1;
            for (const line of lines) {
                const m = line.match(/^\s*([^:]+):\s*(.*)$/);
                if (!m) continue;
                const name = m[1].trim();
                if (/^(lo|veth|docker|br-|virbr|tun|tap|wg)/.test(name)) continue;
                const f = m[2].trim().split(/\s+/).map(Number);
                rx += f[0]; tx += f[8];
                if (f[0] + f[8] > bestBytes) { bestBytes = f[0] + f[8]; best = name; }
            }
            const now = Date.now();
            if (root.lastNet) {
                const dt = (now - root.lastNet.t) / 1000;
                if (dt > 0) {
                    root.rxRate = Math.max(0, (rx - root.lastNet.rx) / dt);
                    root.txRate = Math.max(0, (tx - root.lastNet.tx) / dt);
                    root.rxHistory = root.push(root.rxHistory, root.rxRate);
                    root.txHistory = root.push(root.txHistory, root.txRate);
                }
            }
            root.rxTotal = rx;
            root.txTotal = tx;
            root.iface = best;
            root.lastNet = { t: now, rx, tx };
        }
    }

    // ---- GPU ----------------------------------------------------------------

    Process {
        id: gpuProbe
        running: true
        command: ["sh", "-c", "for c in /sys/class/drm/card[0-9]; do d=$c/device; v=$(cat $d/vendor 2>/dev/null); "
            + "if [ \"$v\" = 0x10de ] && command -v nvidia-smi >/dev/null; then echo nvidia $d; "
            + "elif [ -r $d/gpu_busy_percent ]; then echo amd $d; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.trim().split("\n")) {
                    const p = l.split(" ");
                    if (p.length === 2) out.push({ kind: p[0], dir: p[1] });
                }
                root.gpuSources = out;
                root.gpuAvailable = out.length > 0;
            }
        }
    }

    property int gpuTick: 0
    function sampleGpu() {
        if (!gpuAvailable) return;
        gpuTick++;
        if (nvidiaDir) nvPower.reload();
        if (amdDir) {
            amdBusy.reload();
            if (gpuTick % 2 === 0 && !amdTemp.running) amdTemp.running = true;
        } else if (nvidiaDir && !gpuAsleep && nvKnown) {
            // nvidia-smi is slow-ish; every 2s. Only reached when there is no
            // iGPU counter, i.e. a desktop where the NVIDIA card is always on.
            if (gpuTick % 2 === 0 && !nvSmi.running) nvSmi.running = true;
        }
    }

    readonly property string nvidiaDir: (gpuSources.find(s => s.kind === "nvidia") || {}).dir || ""
    readonly property string amdDir: (gpuSources.find(s => s.kind === "amd") || {}).dir || ""
    // On hybrid laptops the iGPU is sampled and the dGPU is never polled:
    // opening it with nvidia-smi would keep it out of runtime suspend.
    readonly property bool hybrid: nvidiaDir !== "" && amdDir !== ""
    property bool nvKnown: false
    property bool dgpuActive: false

    FileView {
        id: nvPower
        path: root.nvidiaDir ? `${root.nvidiaDir}/power/runtime_status` : ""
        printErrors: false
        onLoaded: {
            const st = text().trim();
            root.nvKnown = true;
            root.dgpuActive = st === "active";
            // Only the NVIDIA-only case reports the GPU itself as asleep.
            root.gpuAsleep = !root.amdDir && st !== "active";
        }
    }

    Process {
        id: nvSmi
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,name",
            "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.split("\n")[0].split(",").map(s => s.trim());
                if (f.length < 5 || isNaN(parseFloat(f[0]))) return;
                root.gpu = parseFloat(f[0]) / 100;
                root.gpuTemp = parseFloat(f[1]);
                root.gpuMemUsed = parseFloat(f[2]);
                root.gpuMemTotal = parseFloat(f[3]);
                root.gpuName = f[4].replace(/^NVIDIA\s+/, "").replace(/GeForce\s+/, "");
                root.gpuHistory = root.push(root.gpuHistory, root.gpu);
            }
        }
    }

    FileView {
        id: amdBusy
        path: root.amdDir ? `${root.amdDir}/gpu_busy_percent` : ""
        printErrors: false
        onLoaded: {
            const v = parseInt(text());
            if (isNaN(v)) return;
            root.gpu = v / 100;
            if (!root.gpuName) root.gpuName = "Radeon";
            root.gpuHistory = root.push(root.gpuHistory, root.gpu);
        }
    }

    // amdgpu edge temperature + VRAM (or GTT for APUs) in one cheap shell read.
    Process {
        id: amdTemp
        command: ["sh", "-c", `d=${root.amdDir}; cat $d/hwmon/hwmon*/temp1_input 2>/dev/null | head -1; `
            + "cat $d/mem_info_vram_used $d/mem_info_vram_total 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n").map(Number);
                if (l.length >= 1 && !isNaN(l[0])) root.gpuTemp = l[0] / 1000;
                if (l.length >= 3) {
                    root.gpuMemUsed = l[1] / 1048576;
                    root.gpuMemTotal = l[2] / 1048576;
                }
            }
        }
    }

    // ---- Storage ------------------------------------------------------------

    Process {
        id: df
        command: ["df", "-B1", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs",
            "-x", "ramfs", "-x", "fuse.portal", "--output=target,fstype,size,used,avail"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const seen = {};
                for (const l of text.trim().split("\n").slice(1)) {
                    const f = l.trim().split(/\s+/);
                    if (f.length < 5) continue;
                    const n = f.length;
                    const mount = f.slice(0, n - 4).join(" ");
                    const size = Number(f[n - 3]), used = Number(f[n - 2]), avail = Number(f[n - 1]);
                    // Skip tiny/system mounts and bind duplicates of the same device size.
                    if (!(size > 256 * 1048576) || /^\/(boot|efi|nix\/store|run\/(user|wrappers)|sys|proc|dev)(\/|$)/.test(mount)) continue;
                    const key = `${size}:${used}`;
                    if (seen[key]) continue;
                    seen[key] = true;
                    out.push({ mount, fs: f[n - 4], size, used, avail, pct: size > 0 ? used / (used + avail) : 0 });
                }
                out.sort((a, b) => (a.mount === "/" ? -1 : b.mount === "/" ? 1 : a.mount.localeCompare(b.mount)));
                root.disks = out;
                root.disksReady = true;
            }
        }
    }
}
