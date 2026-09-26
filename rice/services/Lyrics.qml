pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.config
import Quickshell.Io

// Synced lyrics for the active MPRIS player, fetched from LRCLIB
// (https://lrclib.net). Results (including misses) are cached on disk in
// $XDG_STATE_HOME/rice/lyrics-cache.json so replays never hit the network.
//
//   status      "idle" | "loading" | "ready" | "none" | "error"
//   lines       [{ time: seconds, text }] sorted; plain lyrics get time -1
//   synced      true when `lines` carry timestamps
//   index       current line for the player position (-1 before the first)
//   position    player position in seconds, refreshed while tracking
Singleton {
    id: root

    readonly property MprisPlayer player: Media.active
    readonly property string title: clean(player?.trackTitle ?? "")
    readonly property string artist: clean(player?.trackArtist ?? "")
    readonly property string album: clean(player?.trackAlbum ?? "")
    readonly property real length: player && player.length > 0 && isFinite(player.length) ? player.length : 0
    readonly property string key: title ? `${artist.toLowerCase()}|${title.toLowerCase()}|${Math.round(length)}` : ""

    property string status: "idle"
    property string error: ""
    property var lines: []
    property bool synced: false
    property bool instrumental: false
    property string source: ""          // "lrclib" | "cache"

    // User offset in seconds, applied on top of the player position.
    property real offset: 0

    // Anything that shows lyrics sets this while visible; position is only polled then.
    property int consumers: 0
    readonly property bool tracking: consumers > 0 && synced && (player?.isPlaying ?? false)

    property real position: 0
    readonly property int index: synced ? indexAt(position + offset + 0.15) : -1
    readonly property string currentLine: index >= 0 && index < lines.length ? lines[index].text : ""
    readonly property string nextLine: index + 1 < lines.length && synced ? lines[index + 1].text : ""
    readonly property real lineProgress: {
        if (index < 0 || index + 1 >= lines.length) return 0;
        const a = lines[index].time, b = lines[index + 1].time;
        return b > a ? Math.max(0, Math.min(1, (position + offset - a) / (b - a))) : 0;
    }

    property int _req: 0
    property string _loadedKey: ""

    function acquire() { consumers++; Qt.callLater(syncPosition); }
    function release() { consumers = Math.max(0, consumers - 1); }

    function clean(s) {
        return String(s || "").trim();
    }

    function syncPosition() {
        if (player) position = player.position;
    }

    function retry() {
        if (!key) return;
        const c = Object.assign({}, cache.entries);
        delete c[key];
        cache.entries = c;
        _loadedKey = "";
        load();
    }

    // Binary search: last line whose timestamp is <= t.
    function indexAt(t) {
        const l = lines;
        if (!l.length || t < l[0].time) return -1;
        let lo = 0, hi = l.length - 1;
        while (lo < hi) {
            const mid = (lo + hi + 1) >> 1;
            if (l[mid].time <= t) lo = mid; else hi = mid - 1;
        }
        return lo;
    }

    function parseLrc(text) {
        const out = [];
        let shift = 0;
        const stamp = /\[(\d{1,3}):(\d{1,2}(?:[.:]\d{1,3})?)\]/g;
        for (const raw of String(text || "").split(/\r?\n/)) {
            const off = raw.match(/^\[offset:\s*([+-]?\d+)\]/i);
            if (off) { shift = parseInt(off[1]) / 1000; continue; }
            const times = [];
            let m, last = 0;
            stamp.lastIndex = 0;
            while ((m = stamp.exec(raw)) !== null) {
                if (m.index !== last) break;          // only leading stamps
                times.push(parseInt(m[1]) * 60 + parseFloat(m[2].replace(":", ".")));
                last = stamp.lastIndex;
            }
            if (!times.length) continue;
            // Strip word-level <mm:ss.xx> tags from enhanced LRC.
            const body = raw.slice(last).replace(/<\d+:\d+(?:\.\d+)?>/g, "").trim();
            for (const t of times) out.push({ time: Math.max(0, t - shift), text: body });
        }
        out.sort((a, b) => a.time - b.time);
        return out;
    }

    function parsePlain(text) {
        return String(text || "").split(/\r?\n/).map(t => ({ time: -1, text: t.trim() }));
    }

    function apply(entry, from) {
        instrumental = !!entry.instrumental;
        const synced_ = entry.synced ? parseLrc(entry.synced) : [];
        if (synced_.length) {
            lines = synced_;
            synced = true;
        } else if (entry.plain) {
            lines = parsePlain(entry.plain);
            synced = false;
        } else {
            lines = [];
            synced = false;
        }
        source = from;
        error = "";
        status = lines.length ? "ready" : "none";
        syncPosition();
    }

    function reset() {
        _req++;
        lines = [];
        synced = false;
        instrumental = false;
        error = "";
        source = "";
        status = "idle";
    }

    function load() {
        if (!key) { reset(); _loadedKey = ""; return; }
        if (key === _loadedKey) return;
        _loadedKey = key;
        const hit = cache.entries[key];
        if (hit) { apply(hit, "cache"); return; }
        reset();
        _retries = 0;
        status = "loading";
        fetchExact(++_req);
    }

    function query(params) {
        return Object.keys(params).filter(k => params[k] !== "" && params[k] !== undefined)
            .map(k => `${k}=${encodeURIComponent(params[k])}`).join("&");
    }

    function request(url, req, done) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || req !== _req) return;
            let body = null;
            try { body = JSON.parse(xhr.responseText); } catch (e) {}
            done(xhr.status, body);
        };
        xhr.open("GET", url);
        xhr.setRequestHeader("Lrclib-Client", "rice-shell (https://github.com/quickshell-mirror/quickshell)");
        xhr.send();
        watchdog.restart();
    }

    function lineCount(lrc) {
        return (String(lrc || "").match(/^\[\d+:\d+/gm) || []).length;
    }

    function fetchExact(req) {
        if (!length || !album) { fetchSearch(req); return; }
        const url = "https://lrclib.net/api/get?" + query({
            artist_name: artist, track_name: title, album_name: album, duration: Math.round(length)
        });
        request(url, req, (code, body) => {
            // Some entries are junk ("[00:00.00]probe"); fall back to search for those.
            if (code === 200 && body && (body.instrumental || lineCount(body.syncedLyrics) >= 4))
                finish(req, body);
            else if (code === 200 || code === 404)
                fetchSearch(req, code === 200 ? body : null);
            else
                fail(req, code);
        });
    }

    function fetchSearch(req, weak) {
        const url = "https://lrclib.net/api/search?" + query({ track_name: title, artist_name: artist });
        request(url, req, (code, body) => {
            if (code !== 200 || !Array.isArray(body)) {
                if (weak) finish(req, weak); else fail(req, code);
                return;
            }
            let best = null, bestScore = -1e9;
            for (const r of body) {
                const lc = lineCount(r.syncedLyrics);
                const dd = length ? Math.abs((r.duration || 0) - length) : 0;
                if (length && dd > 8) continue;
                let score = (lc >= 4 ? 100 : r.plainLyrics ? 20 : r.instrumental ? 10 : 0) - dd * 4;
                if (album && String(r.albumName || "").toLowerCase() === album.toLowerCase()) score += 5;
                if (score > bestScore) { bestScore = score; best = r; }
            }
            finish(req, best || weak);
        });
    }

    function finish(req, r) {
        if (req !== _req) return;
        watchdog.stop();
        const entry = r ? {
            synced: r.syncedLyrics || "", plain: r.plainLyrics || "", instrumental: !!r.instrumental,
            at: Date.now()
        } : { synced: "", plain: "", instrumental: false, miss: true, at: Date.now() };
        store(entry);
        apply(entry, "lrclib");
    }

    property int _retries: 0

    function fail(req, code) {
        if (req !== _req) return;
        watchdog.stop();
        // lrclib occasionally answers 5xx under load; retry once quietly.
        if ((code === 0 || code >= 500) && _retries < 1) {
            _retries++;
            retryTimer.restart();
            return;
        }
        lines = [];
        synced = false;
        error = code === 0 ? "Can't reach lrclib.net" : `lrclib.net returned ${code}`;
        status = "error";
        _loadedKey = "";           // allow retry on next track change / retry()
    }

    function store(entry) {
        const c = Object.assign({}, cache.entries);
        c[key] = entry;
        // Keep the newest 150 tracks; forget misses after a week.
        const keys = Object.keys(c)
            .filter(k => !(c[k].miss && Date.now() - c[k].at > 7 * 86400000))
            .sort((a, b) => (c[b].at || 0) - (c[a].at || 0)).slice(0, 150);
        const next = {};
        for (const k of keys) next[k] = c[k];
        cache.entries = next;
        cache.setText(JSON.stringify(next));
    }

    onKeyChanged: debounce.restart()
    onTrackingChanged: syncPosition()

    FileView {
        id: cache
        property var entries: ({})
        path: `${Paths.state}/lyrics-cache.json`
        printErrors: false
        onLoaded: {
            try { entries = JSON.parse(text()) || {}; } catch (e) { entries = {}; }
            if (root.status === "idle") debounce.restart();
        }
    }

    // Players publish title/artist/length in separate property updates.
    Timer {
        id: debounce
        interval: 350
        onTriggered: root.load()
    }

    Timer {
        id: retryTimer
        interval: 2500
        onTriggered: if (root.status === "loading") root.fetchExact(root._req)
    }

    Timer {
        id: watchdog
        interval: 15000
        onTriggered: if (root.status === "loading") root.fail(root._req, 0)
    }

    Timer {
        interval: 100
        repeat: true
        running: root.tracking
        onTriggered: root.syncPosition()
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() { root.syncPosition(); }
        function onPostTrackChanged() { root.syncPosition(); }
    }
}
