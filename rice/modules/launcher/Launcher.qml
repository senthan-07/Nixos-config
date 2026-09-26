pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import "Calc.js" as Calc
import "Commands.js" as Commands
import "EmojiData.js" as Emoji
import "Help.js" as Help

// Spotlight-style launcher.
//
//   text   apps (+ calculator, commands and web fallbacks)
//   >      commands / run a shell command
//   =      calculator, units ("10 km to mi") and currency ("100 usd to inr")
//   ?      web search ("?yt lofi" picks an engine)
//   /      files in $HOME
//   ;      clipboard history
//   .      emoji
//   :      wallpapers
//
// Keys: ↑/↓, Tab/Shift+Tab, Ctrl+N/P/J/K move · ←/→ in grids · → expands app
// actions · Enter runs · Shift+Enter keeps the launcher open · Alt+Enter
// reveals a file · Ctrl+Enter copies a path · Shift+Del deletes a clipboard
// entry · Ctrl+1…6 switch mode · Ctrl+G list/grid · Backspace on empty
// input or Esc leaves a mode · Esc closes.
PanelWindow {
    id: root

    // ------------------------------------------------------------ window
    property real shown: Panels.launcher ? 1 : 0
    Behavior on shown {
        NumberAnimation {
            duration: Panels.launcher ? Spot.openDuration : Spot.closeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Panels.launcher ? Motion.curve.emphasizedDecel : Motion.curve.emphasizedAccel
        }
    }

    visible: Panels.launcher || shown > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "rice-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Panels.launcher ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ------------------------------------------------------------ modes
    readonly property var modes: ({
        apps: { id: "apps", label: "Apps", icon: "apps", prefix: "", placeholder: "Search apps, commands, math…" },
        files: { id: "files", label: "Files", icon: "draft", prefix: "/", placeholder: "Search files and folders" },
        clipboard: { id: "clipboard", label: "Clipboard", icon: "content_paste", prefix: ";", placeholder: "Search clipboard history" },
        emoji: { id: "emoji", label: "Emoji", icon: "mood", prefix: ".", placeholder: "Search emoji" },
        wallpapers: { id: "wallpapers", label: "Wallpapers", icon: "image", prefix: ":", placeholder: "Search wallpapers" },
        commands: { id: "commands", label: "Commands", icon: "terminal", prefix: ">", placeholder: "Search commands or type a shell command" },
        calc: { id: "calc", label: "Calculator", icon: "calculate", prefix: "=", placeholder: "2^10, sqrt(2), 10 km to mi, 100 usd to inr" },
        web: { id: "web", label: "Web", icon: "travel_explore", prefix: "?", placeholder: "Search the web (yt, w, gh, nix… picks an engine)" },
        help: { id: "help", label: "Keys & help", icon: "keyboard", prefix: "!", placeholder: "Search keybinds, launcher tricks and rice commands" }
    })
    readonly property var railModes: ["apps", "files", "clipboard", "emoji", "wallpapers", "help"].map(m => modes[m])
    readonly property var prefixes: ({ "/": "files", ";": "clipboard", ".": "emoji", ":": "wallpapers", ">": "commands", "=": "calc", "?": "web", "!": "help" })

    property string mode: "apps"
    readonly property string query: bar.text
    property int selected: 0
    property string expandedKey: ""
    property string confirmKey: ""
    property string copiedKey: ""
    property bool switching: false
    property string lastQuery: ""
    property string lastMode: ""

    readonly property bool gridLayout: store.get("layout", "list") === "grid"

    JsonStore {
        id: store
        name: "launcher"
    }

    // ------------------------------------------------------------ lifecycle
    Connections {
        target: Panels
        function onLauncherChanged() {
            if (Panels.launcher) root.opened();
        }
    }

    function opened() {
        confirmKey = "";
        copiedKey = "";
        expandedKey = "";
        const q = Panels.launcherQuery;
        Panels.launcherQuery = "";
        setMode("apps", "");
        if (q) bar.text = q;          // a prefix switches mode via onTextChanged
        selectFirst();
        bar.input.forceActiveFocus();
    }

    function close() {
        Panels.launcher = false;
    }

    function setMode(m, text) {
        switching = true;
        mode = m;
        bar.text = text || "";
        switching = false;
        expandedKey = "";
        confirmKey = "";
        if (m === "clipboard") Clipboard.refresh();
        if (m === "files") FileSearch.search(bar.text);
        else FileSearch.cancel();
        if (m === "wallpapers" && !Wallpapers.list.length) Wallpapers.rescan();
        if (m === "help") Keybinds.reload();
        selectFirst();
        bar.input.forceActiveFocus();
    }

    function onQueryEdited() {
        if (switching) return;
        const t = bar.text;
        if (mode === "apps" && t.length && prefixes[t[0]]) {
            setMode(prefixes[t[0]], t.slice(1));
            return;
        }
        expandedKey = "";
        confirmKey = "";
        if (mode === "files") FileSearch.search(t);
    }

    // ------------------------------------------------------------ answers
    function computeAnswer(q, explicit) {
        q = q.trim();
        if (!q) return null;
        const unit = Calc.convert(q);
        if (unit) {
            const cat = unit.category;
            return {
                type: "unit", label: cat,
                lhs: Calc.pretty(unit.value), lhsUnit: unit.from,
                rhs: Calc.prettyShort(unit.result), rhsUnit: unit.to,
                copy: String(+unit.result.toPrecision(10)),
                detail: cat === "Temperature" ? "" : `1 ${unit.from} = ${Calc.prettyShort(Calc.convert(`1 ${unit.from} to ${unit.to}`).result)} ${unit.to}`,
                state: "ready"
            };
        }
        const cur = Calc.parseCurrency(q);
        if (cur && Currency.known(cur.from) && Currency.known(cur.to)) {
            Qt.callLater(Currency.ensure);
            const v = Currency.convert(cur.amount, cur.from, cur.to);
            const rate = Currency.convert(1, cur.from, cur.to);
            const loading = v === null && Currency.state !== "error";
            return {
                type: "currency",
                label: "Currency",
                lhs: Calc.pretty(cur.amount), lhsUnit: `${cur.from} · ${Currency.names[cur.from] || ""}`,
                rhs: v === null ? "" : Number(v).toLocaleString(Qt.locale("en_US"), "f", v >= 100 ? 2 : 4).replace(/\.?0+$/, m => m.startsWith(".") && m.length > 1 ? "" : m),
                rhsUnit: `${cur.to} · ${Currency.names[cur.to] || ""}`,
                copy: v === null ? "" : Number(v).toFixed(2),
                detail: rate === null ? "" : `1 ${cur.from} = ${Calc.pretty(+rate.toPrecision(6))} ${cur.to} · ${Currency.ageText()}`,
                state: v !== null ? "ready" : loading ? "loading" : "error",
                error: Currency.error || "Rates unavailable"
            };
        }
        if (!explicit && !Calc.looksLikeMath(q)) return null;
        try {
            const r = Calc.evaluate(q);
            if (!explicit && r.trivial) return null;
            if (typeof r.value !== "number" || isNaN(r.value)) return null;
            return {
                type: "calc", label: "Calculator",
                lhs: q, rhs: Calc.pretty(r.value), copy: Calc.format(r.value),
                detail: "", rhsUnit: Calc.bases(r.value), state: "ready"
            };
        } catch (e) {
            if (!explicit) return null;
            return { type: "calc", label: "Calculator", lhs: q, state: "error", error: e.message };
        }
    }

    readonly property var answer: (mode === "apps" || mode === "calc")
        ? computeAnswer(query, mode === "calc") : null
    // Touch the rate table so answers refresh when rates arrive.
    readonly property var _rates: Currency.rates

    // ------------------------------------------------------------ items
    readonly property string view: mode === "apps" && gridLayout && !answer ? "appgrid"
        : mode === "wallpapers" ? "wallgrid"
        : mode === "emoji" ? "emoji"
        : mode === "clipboard" ? "clipboard" : "list"

    // Every item records the view it was built for, so views never render
    // another mode's items during a mode switch.
    readonly property var items: tag(view, build(mode, query, view, expandedKey, answer, _rates,
        Clipboard.entries, FileSearch.results, Wallpapers.list, store.data,
        Settings.data.darkMode, Settings.data.doNotDisturb, Panels.caffeine, Keybinds.rows))

    function tag(v, list) {
        for (const it of list) it.view = v;
        return list;
    }

    function header(title, note) {
        return { kind: "header", key: `h:${title}`, title: title, note: note || "" };
    }

    function answerItem(a) {
        return {
            kind: "answer", key: "answer", answer: a, hint: "Copy",
            run: mods => {
                if (a.state !== "ready" || !a.copy) return false;
                copy(a.copy);
                if (mode === "calc") remember(query);
                flashCopied("answer");
                return !mods.shift;
            }
        };
    }

    function appItem(e) {
        const actions = e.actions || [];
        const key = `app:${e.id}`;
        return {
            kind: "row", key: key, appIcon: e.icon || "", title: e.name,
            subtitle: e.comment || e.genericName || "",
            hint: "Open", expandable: actions.length > 0 && view === "list", expanded: expandedKey === key,
            entry: e,
            run: () => { Apps.launch(e); return true; }
        };
    }

    function appItems(q, limit) {
        const out = [];
        for (const e of Apps.query(q).slice(0, limit)) {
            const it = appItem(e);
            out.push(it);
            if (it.expanded) {
                for (const a of e.actions) {
                    out.push({
                        kind: "action", key: `act:${e.id}:${a.id}`, parentKey: it.key,
                        appIcon: a.icon || e.icon || "", title: a.name, subtitle: "", hint: "Run",
                        run: () => { a.execute(); return true; }
                    });
                }
            }
        }
        return out;
    }

    function commandItem(c) {
        const toggles = {
            darkMode: Settings.data.darkMode, dnd: Settings.data.doNotDisturb, caffeine: Panels.caffeine,
            layout: gridLayout
        };
        const on = toggles[c.id];
        return {
            kind: "row", key: `cmd:${c.id}`, icon: c.icon, title: c.title, subtitle: c.subtitle,
            hint: "Run", confirm: !!c.confirm,
            badge: on === undefined ? "" : on ? "On" : "Off", badgeOn: !!on,
            run: () => runCommand(c.id)
        };
    }

    function webItems(q) {
        let engines = Commands.engines;
        let text = q;
        const words = q.split(/\s+/);
        const picked = engines.find(e => e.key === words[0].toLowerCase());
        if (picked && words.length > 1) {
            text = words.slice(1).join(" ");
            engines = [picked, ...engines.filter(e => e !== picked)];
        }
        return engines.map(e => ({
            kind: "row", key: `web:${e.key}`, icon: e.icon, title: `${e.name}`,
            subtitle: text ? `Search for “${text}”` : `Keyword: ${e.key}`, hint: "Search",
            run: () => {
                if (!text) { bar.text = `${e.key} `; return false; }
                Quickshell.execDetached(["xdg-open", Commands.engineUrl(e, text)]);
                return true;
            }
        }));
    }

    function clipItem(e) {
        const t = e.text.trim();
        let icon = "notes", tone = "neutral", type = "Text", swatch = "", title = t.replace(/\s+/g, " ");
        if (e.image) { icon = "image"; tone = "tertiary"; type = "Image"; title = `Image · ${e.width} × ${e.height}`; }
        else if (e.binary) { icon = "data_object"; type = "Binary"; title = `Binary data · ${e.size}`; }
        else if (/^https?:\/\/\S+$/i.test(t)) { icon = "link"; tone = "primary"; type = "Link"; }
        else if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(t)) { icon = "palette"; tone = "primary"; type = "Colour"; swatch = t; }
        else if (/^(\/|~\/|file:\/\/)\S+$/.test(t)) { icon = "folder_open"; type = "Path"; }
        else if (/[{};]\s*$|^\s*(import|def|function|const|let|fn|#include)\b/m.test(t)) { icon = "code"; type = "Code"; }
        return {
            kind: "row", key: `clip:${e.id}`, entry: e, icon: icon, tone: tone, typeLabel: type, swatch: swatch,
            title: title || "(whitespace)",
            subtitle: e.image ? `${e.format.toUpperCase()} · ${e.size}` : type,
            hint: "Copy",
            run: mods => {
                Clipboard.copy(e);
                flashCopied(`clip:${e.id}`);
                return !mods.shift;
            }
        };
    }

    // ---- Keys & help mode ----------------------------------------------------
    // "SUPER+SHIFT" + "mouse:272" -> "Super + Shift + Left drag"
    function prettyKey(k) {
        const names = {
            "return": "Enter", "space": "Space", "escape": "Esc", "print": "Print", "comma": ",", "period": ".",
            "slash": "/", "question": "?", "tab": "Tab", "left": "←", "right": "→", "up": "↑", "down": "↓",
            "mouse:272": "Left drag", "mouse:273": "Right drag", "mouse_down": "Scroll down", "mouse_up": "Scroll up"
        };
        const lk = String(k).toLowerCase();
        if (names[lk]) return names[lk];
        if (/^xf86/i.test(k)) return String(k).replace(/^XF86/i, "").replace(/([a-z])([A-Z])/g, "$1 $2");
        return k.length === 1 ? k.toUpperCase() : k.charAt(0).toUpperCase() + k.slice(1);
    }

    function prettyCombo(r) {
        const mods = r.mods.map(m => m.charAt(0) + m.slice(1).toLowerCase());
        return mods.concat([prettyKey(r.key)]).join(" + ");
    }

    function helpItems(t) {
        const q = t.toLowerCase();
        const hit = (...fields) => !q || q.split(/\s+/).every(w => fields.join(" ").toLowerCase().includes(w));
        const out = [];

        for (const g of Keybinds.groups(t)) {
            out.push(header(g.name, `${g.items.length}`));
            for (const r of g.items) {
                const combo = prettyCombo(r);
                const cmd = r.command;
                out.push({
                    kind: "row", key: `kb:${combo}:${r.description}`, icon: Keybinds.iconFor(g.name),
                    title: r.description, subtitle: cmd || g.name, mono: false,
                    badge: combo, hint: cmd ? "Run" : "Copy keys",
                    run: cmd ? (() => { Quickshell.execDetached(["sh", "-c", cmd]); return true; })
                        : (() => { copy(combo); flashCopied(`kb:${combo}:${r.description}`); return false; })
                });
            }
        }
        if (Keybinds.loaded && !Keybinds.rows.length && !q)
            out.push(header("Hyprland keybinds", "none found in ~/.config/hypr"));

        const pre = Help.prefixes.filter(p => hit(p.key, p.title, p.subtitle, "prefix launcher"));
        if (pre.length) out.push(header("Launcher prefixes"), ...pre.map(p => ({
            kind: "row", key: `pre:${p.key}`, icon: modes[p.mode].icon, title: p.title, subtitle: p.subtitle,
            badge: p.key, hint: "Open",
            run: () => { setMode(p.mode, ""); return false; }
        })));

        const pk = Help.panelKeys.filter(k => hit(k.area, k.keys, k.title));
        if (pk.length) out.push(header("Inside the panels"), ...pk.map(k => ({
            kind: "row", key: `pk:${k.area}:${k.keys}`, icon: "keyboard_keys", title: k.title, subtitle: k.area,
            badge: k.keys
        })));

        const ipcs = Help.ipc.filter(c => hit(c.cmd, c.title, "ipc command"));
        if (ipcs.length) out.push(header("rice ipc commands", "Enter copies"), ...ipcs.map(c => ({
            kind: "row", key: `ipc:${c.cmd}`, icon: "terminal", title: c.title, subtitle: c.cmd, mono: false,
            hint: "Copy",
            run: () => { copy(c.cmd); flashCopied(`ipc:${c.cmd}`); return false; }
        })));

        const docs = Help.docs.filter(d => hit(d.title, d.subtitle, "docs documentation help"));
        if (docs.length) out.push(header("Docs"), ...docs.map(d => ({
            kind: "row", key: `doc:${d.file}`, icon: "menu_book", title: d.title, subtitle: d.subtitle, hint: "Open",
            run: () => { Quickshell.execDetached(["xdg-open", `${Quickshell.shellDir}/${d.file}`]); return true; }
        })));
        return out;
    }

    function build(mode, q, view) {
        const t = q.trim();
        const out = [];
        switch (mode) {
        case "apps": {
            if (view === "appgrid") return appItems(t, 400);
            if (answer) out.push(answerItem(answer));
            const cmds = t ? Commands.search(t, 3) : [];
            const apps = appItems(t, t ? (answer || cmds.length ? 8 : 40) : 400);
            if (apps.length) out.push(header("Applications", t ? "" : `${Apps.entries.length}`), ...apps);
            if (cmds.length) out.push(header("Commands"), ...cmds.map(commandItem));
            if (t) {
                out.push(header("Search elsewhere"));
                out.push({
                    kind: "row", key: "go:web", icon: "travel_explore", title: `Search the web for “${t}”`,
                    subtitle: Commands.engines[0].name, hint: "Search",
                    run: () => { Quickshell.execDetached(["xdg-open", Commands.engineUrl(Commands.engines[0], t)]); return true; }
                });
                out.push({
                    kind: "row", key: "go:files", icon: "draft", title: `Search files for “${t}”`,
                    subtitle: "Home folder", hint: "Files",
                    run: () => { setMode("files", t); return false; }
                });
                if (/^[a-z ]+$/i.test(t)) out.push({
                    kind: "row", key: "go:emoji", icon: "mood", title: `Search emoji for “${t}”`,
                    subtitle: "Emoji picker", hint: "Emoji",
                    run: () => { setMode("emoji", t); return false; }
                });
            }
            return out;
        }
        case "commands": {
            if (t) {
                out.push(header("Shell"));
                out.push({
                    kind: "row", key: "run:sh", icon: "terminal", tone: "primary", title: t, mono: true,
                    subtitle: "Run in the background", hint: "Run",
                    run: () => { Quickshell.execDetached(["sh", "-c", t]); return true; }
                });
                out.push({
                    kind: "row", key: "run:term", icon: "select_window", title: t, mono: true,
                    subtitle: `Run in ${Settings.data.terminal}`, hint: "Run",
                    run: () => {
                        Quickshell.execDetached([Settings.data.terminal, "-e", "sh", "-c", `${t}; printf '\\n[exited %s] ' $?; read -r _`]);
                        return true;
                    }
                });
            }
            const cmds = Commands.search(t);
            if (cmds.length) out.push(header("Commands"), ...cmds.map(commandItem));
            return out;
        }
        case "calc": {
            if (answer) out.push(answerItem(answer));
            const hist = store.get("calcHistory", []);
            const past = hist.filter(h => h !== t && (!t || h.includes(t))).slice(0, 8).map(h => {
                const a = computeAnswer(h, true);
                return {
                    kind: "row", key: `hist:${h}`, icon: "history", title: h, mono: true,
                    subtitle: a && a.state === "ready" ? `= ${a.rhs}${a.rhsUnit && a.type !== "calc" ? " " + a.rhsUnit : ""}` : "",
                    hint: "Edit",
                    run: () => { bar.text = h; return false; }
                };
            });
            if (past.length) out.push(header("History"), ...past);
            const examples = ["sqrt(2) * 10", "15% of 80", "10 km to mi", "30 c to f", "100 usd to inr", "5! / 2^3"];
            const rows = (t ? [] : examples.slice(0, past.length ? 3 : 6)).map(x => ({
                kind: "row", key: `ex:${x}`, icon: "lightbulb", title: x, mono: true,
                subtitle: "Example", hint: "Try",
                run: () => { bar.text = x; return false; }
            }));
            if (rows.length) out.push(header("Try"), ...rows);
            return out;
        }
        case "web":
            return t ? webItems(t) : [];
        case "files":
            return FileSearch.results.map(f => ({
                kind: "row", key: `file:${f.path}`, file: f, title: f.name,
                subtitle: FileSearch.prettyPath(f.parent), hint: f.dir ? "Open folder" : "Open",
                run: mods => {
                    if (mods.alt) FileSearch.reveal(f);
                    else if (mods.ctrl) FileSearch.copyPath(f);
                    else FileSearch.open(f);
                    return true;
                }
            }));
        case "clipboard": {
            const words = t.toLowerCase().split(/\s+/).filter(Boolean);
            return Clipboard.entries
                .filter(e => !words.length || words.every(w => (e.image ? `image ${e.format}` : e.text.toLowerCase()).includes(w)))
                .map(clipItem);
        }
        case "emoji": {
            const words = t.toLowerCase().split(/\s+/).filter(Boolean);
            const recent = store.get("emojiRecent", []);
            const mk = (e, r) => ({
                kind: "row", key: `${r ? "r" : "e"}:${e[0]}`, glyph: e[0], title: e[1], group: Emoji.groups[e[2]],
                run: mods => {
                    copy(e[0]);
                    rememberEmoji(e[0]);
                    return !mods.shift;
                }
            });
            if (!words.length) {
                const byChar = {};
                for (const e of Emoji.list) byChar[e[0]] = e;
                const rec = recent.map(c => byChar[c]).filter(Boolean).map(e => mk(e, true));
                return rec.concat(Emoji.list.map(e => mk(e, false)));
            }
            const scored = [];
            for (const e of Emoji.list) {
                const name = e[1].toLowerCase();
                if (!words.every(w => name.includes(w) || Emoji.groups[e[2]].toLowerCase().includes(w))) continue;
                let s = name.startsWith(words[0]) ? 3 : name.split(/[\s:-]/).some(p => p.startsWith(words[0])) ? 2 : 1;
                if (recent.includes(e[0])) s += 2;
                scored.push({ e: e, s: s });
            }
            return scored.sort((a, b) => b.s - a.s).map(x => mk(x.e, false));
        }
        case "help":
            return helpItems(t);
        case "wallpapers": {
            const words = t.toLowerCase().split(/\s+/).filter(Boolean);
            return Wallpapers.list
                .filter(p => words.every(w => p.toLowerCase().includes(w)))
                .map(p => ({
                    kind: "row", key: `wall:${p}`, path: p,
                    title: p.slice(p.lastIndexOf("/") + 1).replace(/\.[^.]+$/, ""),
                    run: mods => { Wallpapers.set(p); return !mods.shift; }
                }));
        }
        }
        return out;
    }

    // Empty / loading / error states.
    readonly property var info: {
        const t = query.trim();
        switch (mode) {
        case "files":
            if (!t) return { icon: "draft", title: "Search your files", subtitle: `Type to search ${FileSearch.prettyPath(Paths.home)} · Alt+Enter shows the file in its folder` };
            if (FileSearch.state === "loading" || (FileSearch.state === "idle" && t)) return { loading: true, title: "Searching…", subtitle: FileSearch.backend ? `Using ${FileSearch.backend}` : "" };
            if (FileSearch.state === "error") return { icon: "error", error: true, title: "File search failed", subtitle: FileSearch.error };
            return { icon: "search_off", title: "No files found", subtitle: `Nothing in your home folder matches “${t}”` };
        case "clipboard":
            if (!Clipboard.available) return { icon: "content_paste_off", error: true, title: "Clipboard history unavailable", subtitle: "Install cliphist and wl-clipboard" };
            if (Clipboard.state === "loading") return { loading: true, title: "Loading history…" };
            if (Clipboard.state === "error") return { icon: "error", error: true, title: "Couldn't read clipboard history", subtitle: Clipboard.error, actionLabel: "Retry" };
            if (!Clipboard.entries.length) return { icon: "content_paste", title: "Clipboard history is empty", subtitle: "Copied text and images show up here while `wl-paste --watch cliphist store` is running." };
            return { icon: "search_off", title: "No matches", subtitle: `Nothing in your history matches “${t}”` };
        case "wallpapers":
            if (!Wallpapers.list.length) return { icon: "hide_image", title: "No wallpapers yet", subtitle: `Add images to ${FileSearch.prettyPath(Paths.wallpaperDir)}`, actionLabel: "Rescan" };
            return { icon: "search_off", title: "No matches", subtitle: `No wallpaper matches “${t}”` };
        case "web":
            return { icon: "travel_explore", title: "Search the web", subtitle: "Type a query. Start with yt, w, gh, nix, maps or ddg to pick an engine." };
        case "emoji":
            return { icon: "sentiment_dissatisfied", title: "No emoji found", subtitle: `Nothing matches “${t}”` };
        case "calc":
            return { icon: "calculate", title: "Calculator", subtitle: "Type an expression" };
        case "help":
            if (Keybinds.loading && !Keybinds.rows.length) return { loading: true, title: "Reading keybinds…" };
            return { icon: "search_off", title: "Nothing matches", subtitle: `No keybind or help entry matches “${t}”` };
        default:
            return { icon: "search_off", title: "No results", subtitle: `Nothing matches “${t}”` };
        }
    }

    function infoAction() {
        if (mode === "clipboard") Clipboard.refresh();
        else if (mode === "wallpapers") Wallpapers.rescan();
    }

    readonly property var hints: {
        switch (mode) {
        case "files": return [["↵", "Open"], ["Alt ↵", "Show in folder"], ["Ctrl ↵", "Copy path"]];
        case "clipboard": return [["↵", "Copy"], ["⇧ ↵", "Copy, stay"], ["⇧ Del", "Delete"], ["Ctrl ⇧ Del", "Clear all"]];
        case "wallpapers": return [["↵", "Apply"], ["⇧ ↵", "Preview"], ["← →", "Move"]];
        case "commands": return [["↵", "Run"], ["Esc", "Back"]];
        case "calc": return [["↵", "Copy result"], ["Esc", "Back"]];
        case "web": return [["↵", "Search"], ["Esc", "Back"]];
        case "help": return [["↵", "Run / copy / open"], ["Esc", "Back"]];
        default: {
            const h = [["↵", "Open"], ["Tab", "Next"]];
            if (view === "list") h.push(["→", "Actions"]);
            h.push(["Ctrl 1–6", "Modes"]);
            return h;
        }
        }
    }

    readonly property string status: {
        switch (mode) {
        case "files": return FileSearch.state === "ready" && FileSearch.results.length ? `${FileSearch.results.length}${FileSearch.limited ? "+" : ""} result${FileSearch.results.length === 1 ? "" : "s"}` : "";
        case "clipboard": return Clipboard.entries.length ? `${Clipboard.entries.length} items` : "";
        case "wallpapers": return Wallpapers.list.length ? `${items.length} of ${Wallpapers.list.length}` : "";
        case "emoji": return items.length ? "↵ Copy  ·  ⇧↵ Copy and stay" : "";
        default: return "";
        }
    }

    // ------------------------------------------------------------ selection
    function selectable(i) {
        const it = items[i];
        return !!it && it.kind !== "header";
    }

    function selectFirst() {
        for (let i = 0; i < items.length; i++) {
            if (selectable(i)) { selected = i; return; }
        }
        selected = -1;
    }

    onItemsChanged: {
        // A new query or mode starts at the top; background refreshes
        // (clipboard, files, rates) keep the selected item when it survives.
        const keep = query === lastQuery && mode === lastMode;
        const prevKey = keep && lastItems[selected] ? lastItems[selected].key : "";
        lastQuery = query;
        lastMode = mode;
        lastItems = items;
        if (prevKey) {
            const i = items.findIndex(it => it.key === prevKey);
            if (i >= 0) { selected = i; return; }
            if (selected < items.length && selectable(selected)) return;
        }
        selectFirst();
    }
    property var lastItems: []

    function move(delta) {
        const n = items.length;
        if (!n) return;
        const cols = panel.columns;
        const grid = view !== "list" && view !== "clipboard";
        const cur = selected < 0 ? 0 : selected;
        if (grid && Math.abs(delta) >= cols && cols > 1) {
            // Vertical move in a grid: clamp instead of wrapping.
            const next = cur + delta;
            if (next >= 0 && next < n) selected = next;
            else if (delta > 0 && Math.floor(cur / cols) < Math.floor((n - 1) / cols)) selected = n - 1;
            return;
        }
        const dir = delta > 0 ? 1 : -1;
        if (Math.abs(delta) === 1) {
            // Single steps wrap around.
            let i = selected < 0 ? (dir > 0 ? -1 : n) : selected;
            for (let step = 0; step < n; step++) {
                i = (i + dir + n) % n;
                if (selectable(i)) { selected = i; return; }
            }
            return;
        }
        // Page jumps clamp at the ends.
        let i = Math.max(0, Math.min(n - 1, cur + delta));
        while (i >= 0 && i < n && !selectable(i)) i += dir;
        if (i < 0 || i >= n) {
            i = Math.max(0, Math.min(n - 1, cur + delta));
            while (i >= 0 && i < n && !selectable(i)) i -= dir;
        }
        if (i >= 0 && i < n) selected = i;
    }

    // ------------------------------------------------------------ actions
    function activate(index, mods) {
        const it = items[index];
        if (!it || it.kind === "header" || !it.run) return;
        selected = index;
        mods = mods || {};
        if (it.confirm && confirmKey !== it.key) {
            confirmKey = it.key;
            return;
        }
        confirmKey = "";
        if (it.run(mods)) close();
    }

    function copy(text) {
        Quickshell.execDetached(["wl-copy", "--", String(text)]);
    }

    function flashCopied(key) {
        copiedKey = key;
        copiedTimer.restart();
    }

    // Keybinds load asynchronously; jump back to the top once they arrive.
    Connections {
        target: Keybinds
        function onRowsChanged() { if (root.mode === "help") root.selectFirst(); }
    }

    Timer {
        id: copiedTimer
        interval: 1200
        onTriggered: root.copiedKey = ""
    }

    function remember(expr) {
        expr = expr.trim();
        if (!expr) return;
        const h = store.get("calcHistory", []).filter(x => x !== expr);
        h.unshift(expr);
        store.set("calcHistory", h.slice(0, 20));
    }

    function rememberEmoji(ch) {
        const r = store.get("emojiRecent", []).filter(x => x !== ch);
        r.unshift(ch);
        store.set("emojiRecent", r.slice(0, 24));
    }

    function setLayout(grid) {
        store.set("layout", grid ? "grid" : "list");
    }

    function toggleExpand(index) {
        const it = items[index];
        if (!it) return false;
        if (it.kind === "action") {
            expandedKey = "";
            Qt.callLater(() => { const i = items.findIndex(x => x.key === it.parentKey); if (i >= 0) selected = i; });
            return true;
        }
        if (!it.expandable) return false;
        const key = it.key;
        expandedKey = expandedKey === key ? "" : key;
        Qt.callLater(() => {
            const i = items.findIndex(x => x.key === key);
            if (i >= 0) selected = expandedKey === key && selectable(i + 1) && items[i + 1].kind === "action" ? i + 1 : i;
        });
        return true;
    }

    function removeClip(index) {
        const it = items[index];
        if (mode !== "clipboard" || !it || !it.entry) return;
        Clipboard.remove(it.entry);
    }

    function ipc(target, fn) {
        Quickshell.execDetached(["quickshell", "ipc", "--pid", String(Quickshell.processId), "call", target, fn]);
    }

    // Returns true when the launcher should close.
    function runCommand(id) {
        switch (id) {
        case "lock": Panels.closeAll(); Panels.locked = true; return false;
        case "logout": Hypr.exit(); return true;
        case "suspend": Quickshell.execDetached(["systemctl", "suspend"]); return true;
        case "reboot": Quickshell.execDetached(["systemctl", "reboot"]); return true;
        case "poweroff": Quickshell.execDetached(["systemctl", "poweroff"]); return true;
        case "power": Panels.toggle("power"); return false;
        case "settings": ipc("settings", "open"); return true;
        case "wallpapers": setMode("wallpapers", ""); return false;
        case "randomWallpaper": Wallpapers.random(); return false;
        case "darkMode": Settings.data.darkMode = !Settings.data.darkMode; return false;
        case "dnd": Settings.data.doNotDisturb = !Settings.data.doNotDisturb; return false;
        case "caffeine": Panels.caffeine = !Panels.caffeine; return false;
        case "sidebar": Panels.toggle("sidebar"); return false;
        case "clipboard": setMode("clipboard", ""); return false;
        case "clearClipboard": Clipboard.wipe(); return false;
        case "emoji": setMode("emoji", ""); return false;
        case "files": setMode("files", ""); return false;
        case "calculator": setMode("calc", ""); return false;
        case "web": setMode("web", ""); return false;
        case "keybinds": setMode("help", ""); return false;
        case "layout": setLayout(!gridLayout); setMode("apps", ""); return false;
        case "reload": Quickshell.reload(false); return true;
        }
        return false;
    }

    // ------------------------------------------------------------ keys
    function handleKey(event) {
        const mods = event.modifiers;
        const ctrl = (mods & Qt.ControlModifier) !== 0;
        const shift = (mods & Qt.ShiftModifier) !== 0;
        const alt = (mods & Qt.AltModifier) !== 0;
        const grid = view !== "list" && view !== "clipboard";
        const cols = grid ? panel.columns : 1;
        const input = bar.input;
        let handled = true;

        switch (event.key) {
        case Qt.Key_Escape:
            if (expandedKey) expandedKey = "";
            else if (confirmKey) confirmKey = "";
            else if (mode !== "apps") setMode("apps", "");
            else close();
            break;
        case Qt.Key_Up: move(-cols); break;
        case Qt.Key_Down: move(cols); break;
        case Qt.Key_Tab: move(1); break;
        case Qt.Key_Backtab: move(-1); break;
        case Qt.Key_PageUp: move(grid ? -cols * 3 : -6); break;
        case Qt.Key_PageDown: move(grid ? cols * 3 : 6); break;
        case Qt.Key_N: case Qt.Key_J:
            if (ctrl) move(cols); else handled = false;
            break;
        case Qt.Key_P: case Qt.Key_K:
            if (ctrl) move(-cols); else handled = false;
            break;
        case Qt.Key_G:
            if (ctrl) { setLayout(!gridLayout); if (mode !== "apps") setMode("apps", query); }
            else handled = false;
            break;
        case Qt.Key_Left:
            if (grid) move(-1);
            else if (expandedKey && input.cursorPosition === input.text.length) toggleExpand(items.findIndex(x => x.key === expandedKey));
            else handled = false;
            break;
        case Qt.Key_Right:
            if (grid) move(1);
            else if (input.cursorPosition === input.text.length && items[selected] && (items[selected].expandable || items[selected].kind === "action")) toggleExpand(selected);
            else handled = false;
            break;
        case Qt.Key_Return: case Qt.Key_Enter:
            activate(selected, { shift: shift, alt: alt, ctrl: ctrl });
            break;
        case Qt.Key_Backspace:
            if (!input.text && mode !== "apps") setMode("apps", "");
            else handled = false;
            break;
        case Qt.Key_Delete:
            if (mode === "clipboard" && shift && ctrl) {
                if (confirmKey === "wipe") { confirmKey = ""; Clipboard.wipe(); }
                else { confirmKey = "wipe"; bar.flashError(); }
            } else if (mode === "clipboard" && shift) removeClip(selected);
            else handled = false;
            break;
        default:
            if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_1 + railModes.length - 1) {
                const m = railModes[event.key - Qt.Key_1].id;
                setMode(m, m === mode ? query : "");
            } else {
                handled = false;
            }
        }
        event.accepted = handled;
    }

    // ------------------------------------------------------------ scene
    // Scrim; click outside to close.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.scrim, 0.28 * root.shown)
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Item {
        id: scene
        anchors.fill: parent
        opacity: root.shown
        scale: 0.96 + 0.04 * root.shown
        transformOrigin: Item.Top

        SearchBar {
            id: bar
            z: 1                // rail tooltips draw over the results panel
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.16) - Spot.bleed - 10 * (1 - root.shown)
            mode: root.mode
            modeInfo: root.modes[root.mode]
            railModes: root.railModes
            railExpanded: root.mode !== "apps" || root.query === ""
            placeholder: root.modes[root.mode].placeholder
            busy: (root.mode === "files" && FileSearch.state === "loading")
                || (root.mode === "clipboard" && Clipboard.state === "loading")
                || (!!root.answer && root.answer.state === "loading")
            input.onTextChanged: root.onQueryEdited()
            input.Keys.priority: Keys.BeforeItem
            input.Keys.onPressed: event => root.handleKey(event)
            onModeClicked: id => root.setMode(id, "")
            onChipClosed: root.setMode("apps", "")
        }

        ResultsPanel {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            y: bar.y + Spot.bleed + Spot.searchHeight + Spot.panelGap + 14 * (1 - root.shown)
            view: root.view
            items: root.items
            selected: root.selected
            info: root.items.length ? null : root.info
            hints: root.hints
            status: root.status
            confirmKey: root.confirmKey
            copiedKey: root.copiedKey
            preview: root.view === "emoji" && root.items[root.selected]
                ? { glyph: root.items[root.selected].glyph, title: root.items[root.selected].title } : null
            showLayoutToggle: root.mode === "apps"
            gridLayout: root.gridLayout
            onHovered: i => { if (root.selectable(i)) root.selected = i; }
            onActivated: (i, m) => root.activate(i, { shift: m && (m.modifiers & Qt.ShiftModifier) })
            onSecondary: i => { root.selected = i; root.toggleExpand(i); }
            onRemoveRequested: i => root.removeClip(i)
            onLayoutRequested: grid => root.setLayout(grid)
            onInfoAction: root.infoAction()
        }
    }

    // ------------------------------------------------------------ IPC
    function ipcMode(name) {
        if (!modes[name]) return;
        if (!Panels.launcher) Panels.openLauncher("");
        setMode(name, "");
    }

    IpcHandler {
        target: "spotlight"
        function open(text: string): void { Panels.openLauncher(text); }
        function mode(name: string): void { root.ipcMode(name); }
        function clipboard(): void { root.ipcMode("clipboard"); }
        function emoji(): void { root.ipcMode("emoji"); }
        function help(): void { root.ipcMode("help"); }
        function files(): void { root.ipcMode("files"); }
        function calc(): void { root.ipcMode("calc"); }
        function commands(): void { root.ipcMode("commands"); }
        function type(text: string): void { root.setMode(root.mode, text); root.onQueryEdited(); }
        function layout(name: string): void { root.setLayout(name === "grid"); }
        function key(name: string): void {
            const map = { down: Qt.Key_Down, up: Qt.Key_Up, left: Qt.Key_Left, right: Qt.Key_Right, tab: Qt.Key_Tab, enter: Qt.Key_Return, esc: Qt.Key_Escape };
            root.handleKey({ key: map[name] || 0, modifiers: 0, accepted: false });
        }
    }
}
