pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    // Emitted for user-visible volume changes so the OSD can react.
    signal changed()

    readonly property string icon: muted || volume <= 0 ? "volume_off"
        : volume < 0.34 ? "volume_mute"
        : volume < 0.67 ? "volume_down" : "volume_up"

    function setVolume(v) {
        if (sink?.ready && sink.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }

    function setMicVolume(v) {
        if (source?.ready && source.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }

    function toggleMute() {
        if (sink?.audio) sink.audio.muted = !sink.audio.muted;
    }

    function toggleMic() {
        if (source?.audio) source.audio.muted = !source.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // Ignore the initial values reported while Pipewire binds the nodes.
    Timer {
        id: settle
        interval: 1500
        running: true
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { if (!settle.running) root.changed(); }
        function onMutedChanged() { if (!settle.running) root.changed(); }
    }

    IpcHandler {
        target: "audio"
        function up(): void { root.setVolume(root.volume + 0.05); }
        function down(): void { root.setVolume(root.volume - 0.05); }
        function mute(): void { root.toggleMute(); }
        function micMute(): void { root.toggleMic(); }
    }
}
