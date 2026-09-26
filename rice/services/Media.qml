pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Media players (MPRIS) plus every app playing audio through PipeWire.
//
// `sources` is what the island's Media tab steps through with ◀ ▶:
//   { kind: "player", key, player, name, icon, streams }   MPRIS player (+ its audio streams)
//   { kind: "app",    key, player: null, name, icon, streams }   audio with no media controls
// Browsers based on Firefox expose one MPRIS player for all tabs, so extra
// tabs only appear as extra streams of that player.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer manual: null
    readonly property MprisPlayer active: (manual && players.includes(manual)) ? manual
        : players.find(p => p.isPlaying) ?? players[0] ?? null

    function cycle() {
        if (players.length < 2) return;
        manual = players[(players.indexOf(active) + 1) % players.length];
    }

    // Seek, then nudge the player so it re-sends its metadata. Firefox-based
    // players (Zen) drop the track length after SetPosition until playback is
    // toggled, which made seek bars jump to the end.
    function seek(player, seconds) {
        if (!player?.canSeek) return;
        player.position = Math.max(0, seconds);
        if (player.isPlaying) {
            refreshTarget = player;
            refreshPause.restart();
        }
    }

    property MprisPlayer refreshTarget: null
    Timer {
        id: refreshPause
        interval: 250           // let the seek land first
        onTriggered: {
            if (!root.refreshTarget?.isPlaying) return;
            root.refreshTarget.pause();
            refreshPlay.restart();
        }
    }
    Timer {
        id: refreshPlay
        interval: 60
        onTriggered: root.refreshTarget?.play()
    }

    function fmt(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    // ---- Audio streams -------------------------------------------------------
    function prop(n, key) { return String(n?.properties?.[key] ?? ""); }

    function isOwnStream(n) {
        // Our own level meters / cava, and other shells' peak detectors.
        const id = [prop(n, "application.name"), prop(n, "node.name"), n.name, prop(n, "media.name")].join(" ").toLowerCase();
        return id.includes("quickshell") || id.includes("peak detect") || id.includes("cava");
    }

    // App playback = "Stream/Output/Audio". Properties only arrive once a node
    // is tracked, so until then fall back to Quickshell's flags (playback
    // streams are reported with isSink = true).
    function isPlayback(n) {
        const cls = prop(n, "media.class");
        return n.isStream && (cls ? cls === "Stream/Output/Audio" : n.isSink);
    }

    readonly property var allStreams: Pipewire.nodes.values.filter(n => n.isStream)
    PwObjectTracker { objects: root.allStreams }

    readonly property var streams: allStreams.filter(n => isPlayback(n) && !isOwnStream(n))

    function appName(n) {
        return prop(n, "application.name") || prop(n, "node.description") || n.description || n.name || "Application";
    }

    function appKey(n) {
        return (prop(n, "application.process.binary") || appName(n)).toLowerCase();
    }

    function appIcon(n) {
        const icon = prop(n, "application.icon-name");
        if (icon) return icon;
        const e = DesktopEntries.heuristicLookup(prop(n, "application.process.binary") || appName(n));
        return e?.icon ?? "audio-x-generic";
    }

    // A readable title per stream; browsers name every tab "AudioStream".
    function streamTitle(n, i) {
        const t = prop(n, "media.title") || prop(n, "media.name");
        return t && !/^(audiostream|playback|audio stream|output)$/i.test(t) ? t : `Stream ${i + 1}`;
    }

    function playerKey(p) {
        return String(p.desktopEntry || p.identity || p.dbusName || "").toLowerCase();
    }

    function belongsTo(n, p) {
        const a = appKey(n), name = appName(n).toLowerCase(), k = playerKey(p), ident = String(p.identity ?? "").toLowerCase();
        if (!k) return false;
        return a === k || name === k || a.includes(k) || k.includes(a)
            || (ident && (name.includes(ident) || ident.includes(name)))
            || String(p.dbusName ?? "").toLowerCase().includes(a);
    }

    readonly property var sources: {
        const out = [];
        const claimed = new Set();
        for (const p of players) {
            const mine = streams.filter(n => belongsTo(n, p));
            mine.forEach(n => claimed.add(n));
            out.push({
                kind: "player", key: `player:${p.dbusName}`, player: p,
                name: p.identity || "Media player",
                icon: DesktopEntries.heuristicLookup(p.desktopEntry || p.identity)?.icon ?? "multimedia-player",
                streams: mine
            });
        }
        const apps = {};
        for (const n of streams) {
            if (claimed.has(n)) continue;
            const k = appKey(n);
            if (!apps[k]) {
                apps[k] = { kind: "app", key: `app:${k}`, player: null, name: appName(n), icon: appIcon(n), streams: [] };
                out.push(apps[k]);
            }
            apps[k].streams.push(n);
        }
        return out;
    }

    // Selection for the island Media tab. Tracks by key so it survives list changes.
    property string selectedKey: ""
    readonly property int index: {
        const i = sources.findIndex(s => s.key === selectedKey);
        if (i >= 0) return i;
        const a = sources.findIndex(s => s.player && s.player === active);
        return a >= 0 ? a : 0;
    }
    readonly property var current: sources.length ? sources[index] : null

    function select(i) {
        if (!sources.length) return;
        const s = sources[((i % sources.length) + sources.length) % sources.length];
        selectedKey = s.key;
        if (s.player) manual = s.player;
    }
    function nextSource() { select(index + 1); }
    function previousSource() { select(index - 1); }

    IpcHandler {
        target: "media"
        function playPause(): void { root.active?.togglePlaying(); }
        function next(): void { root.active?.next(); }
        function previous(): void { root.active?.previous(); }
        function nextSource(): void { root.nextSource(); }
        function previousSource(): void { root.previousSource(); }
        function sources(): string { return root.sources.map((s, i) => `${i === root.index ? "*" : " "} ${s.kind}\t${s.name}\t${s.streams.length} stream(s)`).join("\n"); }
    }
}
