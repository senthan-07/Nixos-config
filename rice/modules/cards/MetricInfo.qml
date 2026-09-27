import QtQuick
import qs.config
import qs.services

// Resolves a metric key ("cpu" | "memory" | "gpu" | "temp") to what the cards
// display: label, icon, level 0..1, value text, detail line and history.
QtObject {
    id: root

    property string metric: "cpu"

    readonly property bool available: {
        switch (metric) {
        case "gpu": return Metrics.gpuAvailable;
        case "temp": return SysStats.temperature > 0;
        default: return true;
        }
    }

    readonly property string label: ({ cpu: "CPU", memory: "Memory", gpu: "GPU", temp: "Temp" })[metric] || metric
    readonly property string icon: ({ cpu: "memory", memory: "memory_alt", gpu: "developer_board", temp: "thermostat" })[metric] || "monitoring"

    // Temperatures map 30..100 °C onto the fill level.
    readonly property real level: {
        switch (metric) {
        case "cpu": return Metrics.cpu;
        case "memory": return Metrics.memory;
        case "gpu": return Metrics.gpuAsleep ? 0 : Metrics.gpu;
        case "temp": return Math.max(0, Math.min(1, (SysStats.temperature - 30) / 70));
        }
        return 0;
    }

    readonly property string valueText: {
        if (!available) return "--";
        switch (metric) {
        case "temp": return Math.round(SysStats.temperature) + "°";
        case "gpu": if (Metrics.gpuAsleep) return "Off";
        }
        return Math.round(level * 100) + "%";
    }

    readonly property string detail: {
        switch (metric) {
        case "cpu": return SysStats.temperature > 0 ? `${Math.round(SysStats.temperature)}°C package` : "Processor load";
        case "memory": return `${SysStats.memUsedGiB.toFixed(1)} / ${SysStats.memTotalGiB.toFixed(1)} GiB`;
        case "gpu":
            if (!Metrics.gpuAvailable) return "No GPU counters";
            if (Metrics.gpuAsleep) return `${Metrics.gpuName || "GPU"} sleeping`;
            return [Metrics.gpuName, isNaN(Metrics.gpuTemp) ? "" : Math.round(Metrics.gpuTemp) + "°C",
                    Metrics.hybrid && !Metrics.useNvidia ? "iGPU · dGPU asleep" : ""].filter(s => s).join(" · ");
        case "temp": return SysStats.temperature >= 85 ? "Running hot" : SysStats.temperature >= 70 ? "Warm" : "Normal";
        }
        return "";
    }

    readonly property string supporting: {
        switch (metric) {
        case "cpu": return "Up " + SysStats.uptime;
        case "memory": return Math.round((1 - Metrics.memory) * SysStats.memTotalGiB * 10) / 10 + " GiB free";
        case "gpu":
            return !isNaN(Metrics.gpuMemTotal) && Metrics.gpuMemTotal > 0
                ? `VRAM ${(Metrics.gpuMemUsed / 1024).toFixed(1)} / ${(Metrics.gpuMemTotal / 1024).toFixed(1)} GiB` : "";
        case "temp": return "CPU sensor";
        }
        return "";
    }

    // History in the same 0..1 space as `level`.
    readonly property var history: {
        switch (metric) {
        case "cpu": return Metrics.cpuHistory;
        case "memory": return Metrics.memHistory;
        case "gpu": return Metrics.gpuHistory;
        case "temp": return Metrics.tempHistory.map(t => Math.max(0, Math.min(1, (t - 30) / 70)));
        }
        return [];
    }

    // Colour family per metric so a row of tiles reads as distinct.
    readonly property string family: ({ cpu: "primary", memory: "secondary", gpu: "tertiary", temp: "error" })[metric] || "primary"
    readonly property color accent: family === "secondary" ? Theme.secondary : family === "tertiary" ? Theme.tertiary
        : family === "error" ? (level > 0.78 ? Theme.error : Theme.tertiary) : Theme.primary
    readonly property color accentFg: family === "secondary" ? Theme.secondaryFg : family === "tertiary" ? Theme.tertiaryFg
        : family === "error" ? (level > 0.78 ? Theme.errorFg : Theme.tertiaryFg) : Theme.primaryFg
    readonly property color container: family === "secondary" ? Theme.secondaryContainer : family === "tertiary" ? Theme.tertiaryContainer
        : family === "error" ? (level > 0.78 ? Theme.errorContainer : Theme.tertiaryContainer) : Theme.primaryContainer
    readonly property color containerFg: family === "secondary" ? Theme.secondaryContainerFg : family === "tertiary" ? Theme.tertiaryContainerFg
        : family === "error" ? (level > 0.78 ? Theme.errorContainerFg : Theme.tertiaryContainerFg) : Theme.primaryContainerFg
}
