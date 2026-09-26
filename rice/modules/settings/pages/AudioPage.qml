import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.modules.settings
import "../controls"
import qs.components
import qs.services
import qs.config

// Audio: output/input device pickers with per-device volume and a per-application mixer.
SettingsPage {
    id: root

    property int expandedDevice: -1
    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => n.audio && !n.isSink && !n.isStream && !(n.name ?? "").endsWith(".monitor"))
    // Stream properties (media.class) come from Media's tracker of all streams;
    // Quickshell reports playback streams with isSink = true.
    readonly property var playback: Media.streams.filter(n => n.audio && !isPeakMonitor(n))
    readonly property var recording: Media.allStreams.filter(n => n.audio && !Media.isPlayback(n) && !isPeakMonitor(n))
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    function isPeakMonitor(n) {
        // Our own (and other shells') level meters show up as capture streams.
        const id = [prop(n, "application.name"), prop(n, "node.name"), n.name, n.nickname, n.description, prop(n, "media.name")].join(" ").toLowerCase();
        return id.includes("quickshell") || id.includes("peak detect");
    }
    function prop(n, key) { return String(n?.properties?.[key] ?? ""); }
    function deviceIcon(n, input) {
        const s = `${n.name} ${n.description} ${prop(n, "device.form-factor")} ${prop(n, "device.bus")}`.toLowerCase();
        if (input) return s.includes("headset") ? "headset_mic" : s.includes("webcam") ? "videocam" : "mic";
        return s.includes("headset") || s.includes("headphone") ? "headphones"
            : s.includes("bluez") || s.includes("bluetooth") ? "bluetooth_audio"
            : s.includes("hdmi") || s.includes("displayport") ? "tv"
            : s.includes("usb") ? "usb" : "speaker";
    }
    function appName(n) {
        return prop(n, "application.name") || prop(n, "node.description") || n.description || n.name || "Application";
    }
    function appIcon(n) {
        const icon = prop(n, "application.icon-name");
        if (icon) return icon;
        const bin = prop(n, "application.process.binary");
        if (bin) {
            const entry = DesktopEntries.heuristicLookup(bin);
            if (entry?.icon) return entry.icon;
            return bin;
        }
        const e = DesktopEntries.heuristicLookup(appName(n));
        return e?.icon || "";
    }
    function setDefault(n, input) {
        if (!Exec.allow(`audio default ${input ? "source" : "sink"} ${n.name}`)) return;
        if (input) Pipewire.preferredDefaultAudioSource = n;
        else Pipewire.preferredDefaultAudioSink = n;
    }
    function setVolume(n, v) {
        if (!n?.audio || !Exec.allow(`audio volume ${n.name} ${v.toFixed(2)}`)) return;
        n.audio.muted = false;
        n.audio.volume = v;
    }
    function toggleMute(n) {
        if (n?.audio && Exec.allow(`audio mute ${n.name}`)) n.audio.muted = !n.audio.muted;
    }

    title: "Audio"
    subtitle: "Output and input devices, and per-application volume"

    PwObjectTracker { objects: [...root.sinks, ...root.sources, ...root.playback, ...root.recording] }

    Banner {
        visible: !Pipewire.ready
        tone: "error"
        text: "Can't reach PipeWire. Make sure the pipewire and wireplumber user services are running."
    }

    // ---------------- Output ----------------
    SettingsSection {
        title: "Output"
        visible: Pipewire.ready

        VolumeRow {
            visible: root.sink !== null
            node: root.sink
            title: root.sink?.description || root.sink?.nickname || "Output"
            detail: "Default output"
            icon: root.sink ? root.deviceIcon(root.sink, false) : "speaker"
            onSetVolume: v => root.setVolume(root.sink, v)
            onToggleMute: root.toggleMute(root.sink)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.space.s
            Layout.leftMargin: Tokens.space.m
            text: "Output device"
            font.pixelSize: Tokens.font.s
            font.weight: Font.DemiBold
            color: Theme.surfaceVariantFg
        }

        Repeater {
            model: root.sinks
            DeviceChoice {
                required property var modelData
                node: modelData
                input: false
            }
        }
        EmptyState {
            visible: root.sinks.length === 0
            icon: "speaker"
            title: "No output devices"
            text: "Connect speakers or headphones."
        }
    }

    // ---------------- Input ----------------
    SettingsSection {
        title: "Input"
        visible: Pipewire.ready

        VolumeRow {
            visible: root.source !== null
            node: root.source
            title: root.source?.description || root.source?.nickname || "Input"
            detail: "Default input · speak to test the level meter"
            icon: "mic"
            onSetVolume: v => root.setVolume(root.source, v)
            onToggleMute: root.toggleMute(root.source)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.space.s
            Layout.leftMargin: Tokens.space.m
            text: "Input device"
            font.pixelSize: Tokens.font.s
            font.weight: Font.DemiBold
            color: Theme.surfaceVariantFg
        }

        Repeater {
            model: root.sources
            DeviceChoice {
                required property var modelData
                node: modelData
                input: true
            }
        }
        EmptyState {
            visible: root.sources.length === 0
            icon: "mic_off"
            title: "No input devices"
            text: "Connect a microphone or headset."
        }
    }

    // ---------------- Applications ----------------
    SettingsSection {
        title: "Applications"
        visible: Pipewire.ready

        Repeater {
            model: root.playback
            VolumeRow {
                required property var modelData
                node: modelData
                title: root.appName(modelData)
                detail: root.prop(modelData, "media.name")
                appIcon: root.appIcon(modelData)
                maxVolume: 1
                onSetVolume: v => root.setVolume(modelData, v)
                onToggleMute: root.toggleMute(modelData)
            }
        }
        EmptyState {
            visible: root.playback.length === 0
            icon: "music_off"
            title: "No apps are playing audio"
            text: "Applications appear here while they play sound, so you can adjust them individually."
        }
    }

    SettingsSection {
        title: "Recording"
        visible: Pipewire.ready && root.recording.length > 0

        Repeater {
            model: root.recording
            VolumeRow {
                required property var modelData
                node: modelData
                title: root.appName(modelData)
                detail: "Using the microphone"
                appIcon: root.appIcon(modelData)
                maxVolume: 1
                meter: false
                onSetVolume: v => root.setVolume(modelData, v)
                onToggleMute: root.toggleMute(modelData)
            }
        }
    }

    // Selectable device row; non-default devices expand to show their own volume.
    component DeviceChoice: ListRow {
        id: choice
        required property var node
        required property bool input
        readonly property bool isDefault: node === (input ? root.source : root.sink)

        icon: root.deviceIcon(node, input)
        highlighted: isDefault
        interactive: true
        expanded: root.expandedDevice === node.id && !isDefault
        title: node.description || node.nickname || node.name
        subtitle: isDefault ? "In use" : node.audio?.muted ? "Muted" : `${Math.round((node.audio?.volume ?? 0) * 100)}%`
        onClicked: root.setDefault(node, input)

        Icon {
            visible: choice.isDefault
            text: "check_circle"
            fill: 1
            size: 22
            color: Theme.primary
        }
        IconButton {
            visible: !choice.isDefault
            icon: choice.expanded ? "expand_less" : "tune"
            size: 34
            onClicked: root.expandedDevice = choice.expanded ? -1 : choice.node.id
        }

        expansion: [
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.m
                LevelSlider {
                    Layout.fillWidth: true
                    from: 0; to: 1.5; step: 0.01
                    value: choice.node.audio?.volume ?? 0
                    onMoved: v => root.setVolume(choice.node, v)
                }
                IconButton {
                    icon: choice.node.audio?.muted ? "volume_off" : "volume_up"
                    toggled: choice.node.audio?.muted ?? false
                    onClicked: root.toggleMute(choice.node)
                }
            }
        ]
    }
}
