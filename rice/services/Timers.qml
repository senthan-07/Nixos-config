pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// Pomodoro and stopwatch. Both are anchored to wall-clock timestamps, so they
// keep counting across shell restarts and never drift with timer jitter.
// State lives in $XDG_STATE_HOME/rice/timers.json.
Singleton {
    id: root

    // ---- Pomodoro ------------------------------------------------------
    readonly property int focusMinutes: store.get("focusMinutes", 25)
    readonly property int breakMinutes: store.get("breakMinutes", 5)
    readonly property int longBreakMinutes: store.get("longBreakMinutes", 15)
    readonly property int cyclesBeforeLongBreak: store.get("cycles", 4)
    readonly property bool notify: store.get("notify", true)

    readonly property bool pomodoroRunning: store.get("pomoRunning", false)
    readonly property string pomodoroPhase: store.get("pomoPhase", "focus")   // "focus" | "break"
    readonly property int pomodoroCycle: store.get("pomoCycle", 0)            // 0-based focus round
    readonly property bool pomodoroLongBreak: pomodoroPhase === "break" && pomodoroCycle + 1 >= cyclesBeforeLongBreak
    readonly property int pomodoroDuration: durationFor(pomodoroPhase, pomodoroCycle)
    property int pomodoroRemaining: pomodoroDuration                          // seconds
    readonly property real pomodoroProgress: pomodoroDuration > 0 ? 1 - pomodoroRemaining / pomodoroDuration : 0
    readonly property bool pomodoroIdle: !pomodoroRunning && pomodoroPhase === "focus"
        && pomodoroCycle === 0 && pomodoroRemaining >= pomodoroDuration

    // ---- Stopwatch -----------------------------------------------------
    readonly property bool stopwatchRunning: store.get("swRunning", false)
    property real stopwatchElapsed: 0                                         // seconds (fractional)
    readonly property var stopwatchLaps: store.get("swLaps", [])              // [seconds]

    signal phaseFinished(string finished, string next)

    function now() { return Date.now() / 1000; }

    function durationFor(phase, cycle) {
        if (phase !== "break") return focusMinutes * 60;
        return (cycle + 1 >= cyclesBeforeLongBreak ? longBreakMinutes : breakMinutes) * 60;
    }

    function fmt(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        const mm = String(m).padStart(2, "0"), ss = String(sec).padStart(2, "0");
        return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
    }

    function fmtPrecise(seconds) {
        const cs = Math.floor((seconds % 1) * 100);
        return `${fmt(seconds)}.${String(cs).padStart(2, "0")}`;
    }

    function phaseLabel() {
        return pomodoroPhase === "focus" ? "Focus" : pomodoroLongBreak ? "Long break" : "Break";
    }

    function patch(obj) {
        for (const k in obj) store.set(k, obj[k]);
    }

    // Pomodoro -----------------------------------------------------------
    function start() {
        if (pomodoroRunning) return;
        const done = pomodoroDuration - pomodoroRemaining;
        patch({ pomoStart: now() - done, pomoRunning: true });
        tick();
    }

    function pause() {
        if (!pomodoroRunning) return;
        tick();
        patch({ pomoRunning: false, pomoLeft: pomodoroRemaining });
    }

    function toggle() { pomodoroRunning ? pause() : start(); }

    function reset() {
        patch({ pomoRunning: false, pomoPhase: "focus", pomoCycle: 0, pomoLeft: focusMinutes * 60 });
        pomodoroRemaining = focusMinutes * 60;
    }

    // Jump straight to the next phase (keeps running state).
    function skip() {
        const n = nextPhase(pomodoroPhase, pomodoroCycle);
        const d = durationFor(n.phase, n.cycle);
        patch({ pomoPhase: n.phase, pomoCycle: n.cycle, pomoStart: now(), pomoLeft: d });
        pomodoroRemaining = d;
    }

    function nextPhase(phase, cycle) {
        if (phase === "focus") return { phase: "break", cycle: cycle };
        return { phase: "focus", cycle: (cycle + 1) % cyclesBeforeLongBreak };
    }

    function setDurations(focus, brk, longBrk, cycles) {
        patch({
            focusMinutes: Math.max(1, focus | 0), breakMinutes: Math.max(1, brk | 0),
            longBreakMinutes: Math.max(1, longBrk | 0), cycles: Math.max(1, cycles | 0)
        });
        if (!pomodoroRunning) pomodoroRemaining = pomodoroDuration;
    }

    function setNotify(on) { patch({ notify: !!on }); }

    function tick() {
        if (!pomodoroRunning) return;
        const t = now();
        let phase = pomodoroPhase, cycle = pomodoroCycle;
        let startAt = Number(store.get("pomoStart", t));
        if (!isFinite(startAt) || startAt > t) startAt = t;
        let d = durationFor(phase, cycle);
        let finished = "";
        let guard = 0;
        // Catch up on every phase that elapsed (e.g. after a suspend).
        while (t >= startAt + d && guard++ < 64) {
            finished = phase;
            startAt += d;
            const n = nextPhase(phase, cycle);
            phase = n.phase; cycle = n.cycle;
            d = durationFor(phase, cycle);
        }
        if (finished !== "") {
            patch({ pomoPhase: phase, pomoCycle: cycle, pomoStart: startAt });
            announce(finished, phase, cycle);
        }
        pomodoroRemaining = Math.max(0, Math.ceil(startAt + d - t));
    }

    function announce(finished, phase, cycle) {
        phaseFinished(finished, phase);
        if (!notify) return;
        const mins = Math.round(durationFor(phase, cycle) / 60);
        const title = finished === "focus" ? "Focus session complete" : "Break is over";
        const body = phase === "focus" ? `Back to work — ${mins} minute focus, round ${cycle + 1} of ${cyclesBeforeLongBreak}.`
            : cycle + 1 >= cyclesBeforeLongBreak ? `Take a long break: ${mins} minutes.`
            : `Take a short break: ${mins} minutes.`;
        Quickshell.execDetached(["notify-send", "-a", "Rice", "-i", "alarm-symbolic",
            "-h", "string:x-rice-source:pomodoro", title, body]);
    }

    // Stopwatch ----------------------------------------------------------
    function startStopwatch() {
        if (stopwatchRunning) return;
        const laps = stopwatchElapsed === 0 ? [] : stopwatchLaps;
        patch({ swStart: now() - stopwatchElapsed, swLaps: laps, swRunning: true });
    }

    function pauseStopwatch() {
        if (!stopwatchRunning) return;
        swTick();
        patch({ swRunning: false, swElapsed: stopwatchElapsed });
    }

    function toggleStopwatch() { stopwatchRunning ? pauseStopwatch() : startStopwatch(); }

    function resetStopwatch() {
        stopwatchElapsed = 0;
        patch({ swRunning: false, swElapsed: 0, swLaps: [] });
    }

    function lap() {
        if (!stopwatchRunning) return;
        swTick();
        patch({ swLaps: [...stopwatchLaps, stopwatchElapsed].slice(-50) });
    }

    function swTick() {
        if (stopwatchRunning)
            stopwatchElapsed = Math.max(0, now() - Number(store.get("swStart", now())));
        else
            stopwatchElapsed = Number(store.get("swElapsed", 0));
    }

    function restore() {
        if (pomodoroRunning) tick();
        else pomodoroRemaining = Math.max(0, Math.min(pomodoroDuration, Number(store.get("pomoLeft", pomodoroDuration))));
        swTick();
    }

    JsonStore {
        id: store
        name: "timers"
        onLoadedChanged: if (loaded) root.restore()
    }

    Timer {
        interval: 250
        repeat: true
        running: root.pomodoroRunning
        triggeredOnStart: true
        onTriggered: root.tick()
    }

    Timer {
        interval: 33
        repeat: true
        running: root.stopwatchRunning
        onTriggered: root.swTick()
    }
}
