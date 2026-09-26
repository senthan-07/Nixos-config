.pragma library

// Keybind parsing for the Shortcuts page.
//
// Three sources, all normalised to rows of
//   { mods: [..], key: "Q", action: { kind, name, args, cmd, varName }, flags: {..},
//     description, category, command, source }
//  - parseLua(files):      Hyprland Lua config (hl.bind(...)), incl. simple for-loops and
//                          local helper functions such as `local ipc = function (t, f) ... end`
//  - parseHyprlang(files): classic hyprland.conf `bind[flags] = MODS, key, dispatcher, args`
//  - parseLive(json):      `hyprctl -j binds`
// files: [{ path, text }]

const MOD_BITS = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"], [2, "CAPS"], [16, "MOD2"], [32, "MOD3"], [128, "MOD5"]];
const MOD_ORDER = ["SUPER", "CTRL", "ALT", "SHIFT", "CAPS", "MOD2", "MOD3", "MOD5"];

const CATEGORIES = [
    { name: "Shell", icon: "dashboard" },
    { name: "Apps", icon: "apps" },
    { name: "Windows", icon: "select_window" },
    { name: "Workspaces", icon: "space_dashboard" },
    { name: "Mouse", icon: "mouse" },
    { name: "Media & hardware", icon: "tune" },
    { name: "Session", icon: "power_settings_new" },
    { name: "Other", icon: "more_horiz" }
];

function categories() { return CATEGORIES; }

const IPC_NAMES = {
    "launcher.toggle": "App launcher",
    "launcher.open": "Open app launcher",
    "launcher.wallpapers": "Wallpaper picker",
    "sidebar.toggle": "Quick settings sidebar",
    "power.toggle": "Power menu",
    "lock.lock": "Lock screen",
    "theme.toggleDark": "Toggle dark mode",
    "notifs.toggleDnd": "Do not disturb",
    "caffeine.toggle": "Caffeine (keep awake)",
    "settings.open": "Settings",
    "settings.toggle": "Settings",
    "wallpaper.random": "Random wallpaper",
    "spotlight.clipboard": "Clipboard history",
    "spotlight.emoji": "Emoji picker",
    "spotlight.files": "File search",
    "spotlight.help": "Keybinds & help",
    "spotlight.commands": "Launcher commands",
    "spotlight.calc": "Calculator",
    "spotlight.mode": "Launcher mode",
    "dashboard.toggle": "Dashboard (weather, info)",
    "dashboard.open": "Dashboard",
    "dashboard.openTab": "Dashboard app drawer",
    "island.toggle": "Island hub",
    "island.media": "Island media and lyrics",
    "island.timer": "Pomodoro and stopwatch",
    "island.tools": "Island tools",
    "dock.toggle": "Show / hide the dock",
    "dock.toggleAutohide": "Dock autohide",
    "desktop.editToggle": "Edit desktop widgets",
    "desktop.toggle": "Show / hide desktop widgets",
    "nightlight.toggle": "Night light",
    "idle.toggle": "Idle lock on / off",
    "capture.region": "Screenshot region",
    "capture.screen": "Screenshot whole screen",
    "capture.window": "Screenshot window",
    "capture.screenshot": "Screenshot",
    "capture.ocr": "OCR text to clipboard",
    "capture.pick": "Colour picker",
    "capture.record": "Record screen (toggle)",
    "capture.recordRegion": "Record region (toggle)",
    "shell.reload": "Reload the shell",
    "capture.recordAudio": "Record system audio (toggle)",
    "capture.recordMic": "Record microphone (toggle)",
    "capture.stop": "Stop recording",
    "audio.up": "Volume up",
    "audio.down": "Volume down",
    "audio.mute": "Mute audio",
    "brightness.up": "Brightness up",
    "brightness.down": "Brightness down",
    "media.playPause": "Play / pause",
    "media.next": "Next track",
    "media.previous": "Previous track"
};

// ---------- small helpers ----------------------------------------------------

function normMod(m) {
    const u = String(m).trim().toUpperCase().replace(/^\$\w+$/, "SUPER");
    if (u === "MOD4" || u === "WIN" || u === "LOGO" || u === "META") return "SUPER";
    if (u === "CONTROL" || u === "CTL") return "CTRL";
    if (u === "MOD1") return "ALT";
    return u;
}

function isMod(k) { return MOD_ORDER.indexOf(normMod(k)) >= 0; }

function sortMods(mods) {
    return mods.map(normMod).filter((m, i, a) => a.indexOf(m) === i)
        .sort((a, b) => MOD_ORDER.indexOf(a) - MOD_ORDER.indexOf(b));
}

function combo(mods, key) {
    return sortMods(mods).join("+") + "+" + String(key).toLowerCase();
}

function humanize(s) {
    return String(s).replace(/[._]+/g, " ").replace(/([a-z])([A-Z])/g, "$1 $2")
        .replace(/\s+/g, " ").trim().replace(/^./, c => c.toUpperCase());
}

// Split "a, b(c, d), { e = 1 }" at top-level commas, respecting quotes and brackets.
function splitArgs(s) {
    const out = [];
    let depth = 0, cur = "", q = null;
    for (let i = 0; i < s.length; i++) {
        const c = s[i];
        if (q) {
            cur += c;
            if (c === "\\" && i + 1 < s.length) { cur += s[++i]; continue; }
            if (c === q) q = null;
            continue;
        }
        if (c === "\"" || c === "'") { q = c; cur += c; continue; }
        if ("([{".includes(c)) depth++;
        if (")]}".includes(c)) depth--;
        if (c === "," && depth === 0) { out.push(cur.trim()); cur = ""; continue; }
        cur += c;
    }
    if (cur.trim() !== "") out.push(cur.trim());
    return out;
}

// Index of the ")" matching the "(" at `open`, or -1.
function matchParen(s, open) {
    let depth = 0, q = null;
    for (let i = open; i < s.length; i++) {
        const c = s[i];
        if (q) { if (c === "\\") i++; else if (c === q) q = null; continue; }
        if (c === "\"" || c === "'") { q = c; continue; }
        if (c === "(") depth++;
        else if (c === ")" && --depth === 0) return i;
    }
    return -1;
}

function stripComment(line) {
    let q = null;
    for (let i = 0; i < line.length - 1; i++) {
        const c = line[i];
        if (q) { if (c === "\\") i++; else if (c === q) q = null; continue; }
        if (c === "\"" || c === "'") { q = c; continue; }
        if (c === "-" && line[i + 1] === "-") return line.slice(0, i);
    }
    return line;
}

// Evaluate a Lua string expression like `mainMod .. " + " .. key` against `vars`.
// Unknown identifiers become "{name}" so callers can spot loop variables.
function evalLua(expr, vars) {
    const parts = [];
    let cur = "", q = null;
    for (let i = 0; i < expr.length; i++) {
        const c = expr[i];
        if (q) { cur += c; if (c === "\\") { cur += expr[++i]; } else if (c === q) q = null; continue; }
        if (c === "\"" || c === "'") { q = c; cur += c; continue; }
        if (c === "." && expr[i + 1] === ".") { parts.push(cur.trim()); cur = ""; i++; continue; }
        cur += c;
    }
    parts.push(cur.trim());
    return parts.map(p => {
        const m = p.match(/^(["'])(.*)\1$/);
        if (m) return m[2].replace(/\\(["'\\])/g, "$1");
        if (/^-?\d+$/.test(p)) return p;
        if (vars && Object.prototype.hasOwnProperty.call(vars, p)) return vars[p];
        return "{" + p + "}";
    }).join("");
}

// `{ direction = "left", workspace = i }` -> { direction: "left", workspace: "{i}" }
function parseTable(s, vars) {
    const out = {};
    const body = String(s || "").trim().replace(/^\{/, "").replace(/\}$/, "");
    for (const part of splitArgs(body)) {
        const m = part.match(/^(\w+)\s*=\s*([\s\S]+)$/);
        if (m) out[m[1]] = evalLua(m[2], vars);
        else if (part) out["_" + Object.keys(out).length] = evalLua(part, vars);
    }
    return out;
}

// ---------- action description -------------------------------------------------

function describeExec(cmd, varName) {
    const c = String(cmd).trim();
    let m = c.match(/\brice\s+ipc\s+call\s+(\S+)\s+(\S+)/) || c.match(/\bqs\b.*\bipc\s+call\s+(\S+)\s+(\S+)/);
    if (m) {
        const k = m[1] + "." + m[2];
        return { description: IPC_NAMES[k] || humanize(m[2]) + " " + m[1], category: "Shell" };
    }
    if (/wpctl\s+set-volume/.test(c)) return { description: /%\+|\+$/.test(c) ? "Volume up" : "Volume down", category: "Media & hardware" };
    if (/wpctl\s+set-mute.*SOURCE/.test(c)) return { description: "Mute microphone", category: "Media & hardware" };
    if (/wpctl\s+set-mute/.test(c)) return { description: "Mute audio", category: "Media & hardware" };
    if (/pactl|pamixer|amixer/.test(c)) return { description: "Volume", category: "Media & hardware" };
    if (/brightnessctl|light\s+-|brillo/.test(c)) return { description: /\+|-A|\bup\b/.test(c) ? "Brightness up" : "Brightness down", category: "Media & hardware" };
    m = c.match(/playerctl\s+(\S+)/);
    if (m) {
        const n = { "next": "Next track", "previous": "Previous track", "play-pause": "Play / pause", "play": "Play", "pause": "Pause", "stop": "Stop" };
        return { description: n[m[1]] || "Media " + m[1], category: "Media & hardware" };
    }
    if (/hyprshutdown|hl\.dsp\.exit|dispatch\s+exit/.test(c)) return { description: "Exit Hyprland", category: "Session" };
    if (/hyprlock|swaylock|loginctl\s+lock/.test(c)) return { description: "Lock screen", category: "Session" };
    if (/systemctl\s+(suspend|poweroff|reboot|hibernate)/.test(c)) return { description: humanize(c.match(/systemctl\s+(\w+)/)[1]), category: "Session" };
    if (/grim|slurp|hyprshot|grimblast|flameshot/.test(c)) return { description: /slurp|region|area/.test(c) ? "Screenshot region" : "Screenshot", category: "Apps" };
    if (/cliphist|wl-paste/.test(c)) return { description: "Clipboard history", category: "Apps" };
    const prog = c.split(/\s+/)[0].split("/").pop();
    if (varName) return { description: "Open " + humanize(varName).toLowerCase() + (prog && prog !== "{" + varName + "}" ? " (" + prog + ")" : ""), category: "Apps" };
    return { description: "Launch " + prog, category: "Apps" };
}

function workspaceLabel(w) {
    const s = String(w);
    if (s === "{range}") return "1–10";
    if (s === "e+1" || s === "r+1" || s === "m+1" || s === "+1") return "next";
    if (s === "e-1" || s === "r-1" || s === "m-1" || s === "-1") return "previous";
    const sp = s.match(/^special:?(.*)$/);
    if (sp) return "scratchpad" + (sp[1] ? " “" + sp[1] + "”" : "");
    return s;
}

// name: normalised dispatcher ("window.close", "focus", "exec", ...); args: table or string
function describeAction(a) {
    const n = a.name, t = a.args || {};
    const dir = { left: "left", right: "right", up: "up", down: "down", l: "left", r: "right", u: "up", d: "down" };
    switch (n) {
    case "exec": return describeExec(a.cmd, a.varName);
    case "exit": return { description: "Exit Hyprland", category: "Session" };
    case "window.close": return { description: "Close window", category: "Windows" };
    case "window.kill": return { description: "Kill window", category: "Windows" };
    case "window.float": return { description: "Toggle floating", category: "Windows" };
    case "window.pseudo": return { description: "Pseudo-tile window", category: "Windows" };
    case "window.pin": return { description: "Pin window", category: "Windows" };
    case "window.fullscreen": return { description: "Fullscreen", category: "Windows" };
    case "window.center": return { description: "Center window", category: "Windows" };
    case "window.drag": return { description: "Move window by dragging", category: "Mouse" };
    case "window.resize": return { description: "Resize window by dragging", category: "Mouse" };
    case "window.swap":
        return { description: "Swap window " + (dir[t.direction] || t.direction || ""), category: "Windows" };
    case "window.move":
        if (t.workspace !== undefined) {
            const w = workspaceLabel(t.workspace);
            return { description: w.startsWith("scratchpad") ? "Move window to " + w : "Move window to workspace " + w, category: "Workspaces" };
        }
        return { description: "Move window " + (dir[t.direction] || t.direction || ""), category: "Windows" };
    case "layout":
        return { description: t._0 === "togglesplit" ? "Toggle split direction" : "Layout: " + (t._0 || ""), category: "Windows" };
    case "focus":
        if (t.workspace !== undefined) {
            const w = workspaceLabel(t.workspace);
            if (w === "next" || w === "previous") return { description: humanize(w) + " workspace", category: "Workspaces" };
            return { description: w.startsWith("scratchpad") ? "Show " + w : "Go to workspace " + w, category: "Workspaces" };
        }
        if (t.direction) return { description: "Focus window " + (dir[t.direction] || t.direction), category: "Windows" };
        if (t.monitor) return { description: "Focus monitor " + t.monitor, category: "Windows" };
        return { description: "Focus", category: "Windows" };
    case "workspace.toggle_special":
        return { description: "Toggle scratchpad" + (t._0 ? " “" + t._0 + "”" : ""), category: "Workspaces" };
    }
    return { description: humanize(n.replace(/^window\./, "window ")) + (t._0 ? " " + t._0 : ""), category: "Other" };
}

// Map classic dispatchers (hyprctl / hyprlang) onto the normalised names above.
function fromDispatcher(disp, arg) {
    const d = String(disp || "").trim(), a = String(arg || "").trim();
    if (d.startsWith("hl.dsp.")) return { name: d.slice(7), args: {} };
    const dirs = { l: "left", r: "right", u: "up", d: "down" };
    switch (d.toLowerCase()) {
    case "exec": case "execr": return { name: "exec", cmd: a, args: {} };
    case "killactive": return { name: "window.close", args: {} };
    case "forcekillactive": return { name: "window.kill", args: {} };
    case "togglefloating": return { name: "window.float", args: {} };
    case "pseudo": return { name: "window.pseudo", args: {} };
    case "pin": return { name: "window.pin", args: {} };
    case "fullscreen": return { name: "window.fullscreen", args: {} };
    case "centerwindow": return { name: "window.center", args: {} };
    case "togglesplit": return { name: "layout", args: { _0: "togglesplit" } };
    case "layoutmsg": return { name: "layout", args: { _0: a } };
    case "movefocus": return { name: "focus", args: { direction: dirs[a] || a } };
    case "swapwindow": return { name: "window.swap", args: { direction: dirs[a] || a } };
    case "movewindow": return a ? { name: "window.move", args: { direction: dirs[a] || a } } : { name: "window.drag", args: {} };
    case "resizewindow": return { name: "window.resize", args: {} };
    case "workspace": return { name: "focus", args: { workspace: a } };
    case "focusmonitor": return { name: "focus", args: { monitor: a } };
    case "movetoworkspace": case "movetoworkspacesilent": return { name: "window.move", args: { workspace: a } };
    case "togglespecialworkspace": return { name: "workspace.toggle_special", args: { _0: a } };
    case "exit": return { name: "exit", args: {} };
    }
    return { name: d || "unknown", args: a ? { _0: a } : {} };
}

function makeRow(mods, key, action, flags, source, explicitDesc) {
    const d = describeAction(action);
    let category = d.category;
    const k = String(key);
    if (/^mouse/i.test(k) || (flags && flags.mouse)) category = "Mouse";
    if (/^XF86/i.test(k) && category === "Apps") category = "Media & hardware";
    return {
        mods: sortMods(mods),
        key: k,
        action: action,
        flags: flags || {},
        description: explicitDesc || d.description,
        category: category,
        command: action.name === "exec" ? String(action.cmd || "") : "",
        source: source || ""
    };
}

// ---------- Lua ------------------------------------------------------------------

function parseLua(files) {
    const vars = {};
    const funcs = {};    // name -> { params: [..], body: "hl.dsp.exec_cmd(...)" }
    const rows = [];

    for (const f of files) {
        const lines = String(f.text || "").split("\n").map(stripComment);
        const loops = [];   // { indent, var }
        let pendingFunc = null;

        for (let i = 0; i < lines.length; i++) {
            let line = lines[i];
            const indent = line.match(/^\s*/)[0].length;

            // Loop scope bookkeeping.
            let m = line.match(/^\s*for\s+(\w+)\s*=\s*(-?\d+)\s*,\s*(-?\d+)/);
            if (m) { loops.push({ indent: indent, v: m[1] }); vars[m[1]] = "{range}"; continue; }
            if (/^\s*end\b/.test(line) && loops.length && loops[loops.length - 1].indent === indent) {
                const l = loops.pop();
                delete vars[l.v];
                continue;
            }

            // local helper = function (a, b) return <expr> end
            m = line.match(/^\s*local\s+(\w+)\s*=\s*function\s*\(([^)]*)\)(.*)$/);
            if (m) {
                pendingFunc = { name: m[1], params: m[2].split(",").map(p => p.trim()).filter(p => p), body: m[3] };
                if (/\bend\s*$/.test(m[3])) { funcs[pendingFunc.name] = pendingFunc; pendingFunc = null; }
                continue;
            }
            if (pendingFunc) {
                if (/^\s*end\b/.test(line)) { funcs[pendingFunc.name] = pendingFunc; pendingFunc = null; }
                else pendingFunc.body += " " + line.trim();
                continue;
            }

            // local x = "str" / local key = i % 10
            m = line.match(/^\s*local\s+(\w+)\s*=\s*(.+?)\s*$/);
            if (m && !/hl\.bind/.test(m[2])) {
                if (/^["']/.test(m[2])) vars[m[1]] = evalLua(m[2], vars);
                else if (loops.length && new RegExp("\\b" + loops[loops.length - 1].v + "\\b").test(m[2])) vars[m[1]] = "{range}";
                if (!/hl\.bind/.test(line)) continue;
            }

            const at = line.indexOf("hl.bind(");
            if (at < 0) continue;
            // Join continuation lines until the call closes.
            let text = line.slice(at);
            let close = matchParen(text, text.indexOf("("));
            let j = i;
            while (close < 0 && j + 1 < lines.length && j - i < 8) {
                text += " " + lines[++j].trim();
                close = matchParen(text, text.indexOf("("));
            }
            i = j;
            if (close < 0) continue;
            const args = splitArgs(text.slice(text.indexOf("(") + 1, close));
            if (args.length < 2) continue;

            const keyStr = evalLua(args[0], vars);
            const parts = keyStr.split("+").map(p => p.trim()).filter(p => p !== "");
            const mods = parts.filter(isMod);
            let key = parts.filter(p => !isMod(p)).join("+") || parts[parts.length - 1] || "";
            if (key === "{range}") key = "1…0";

            const action = luaAction(args[1], vars, funcs);
            const flags = args[2] ? parseTable(args[2], vars) : {};
            for (const k in flags) flags[k] = flags[k] === "true";
            const desc = args.length > 3 ? luaDescription(args[3], vars) : "";
            rows.push(makeRow(mods, key, action, flags, f.path, desc));
        }
    }
    return rows;
}

function luaDescription(arg, vars) {
    const t = parseTable(arg, vars);
    return t.description || t.desc || "";
}

// "hl.dsp.window.float({ action = "toggle" })" | "ipc("launcher", "toggle")"
function luaAction(expr, vars, funcs) {
    expr = expr.trim();
    const m = expr.match(/^([\w.]+)\s*\(/);
    if (!m) return { name: "unknown", args: {} };
    const open = expr.indexOf("(");
    const close = matchParen(expr, open);
    const inner = close > 0 ? expr.slice(open + 1, close) : "";
    const callee = m[1];

    if (callee.startsWith("hl.dsp.")) {
        const name = callee.slice(7);
        if (name === "exec_cmd") {
            const raw = inner.trim();
            const varName = /^\w+$/.test(raw) ? raw : "";
            return { name: "exec", cmd: evalLua(raw, vars), varName: varName, args: {} };
        }
        const argList = splitArgs(inner);
        let args = {};
        if (argList.length && argList[0].startsWith("{")) args = parseTable(argList[0], vars);
        else argList.forEach((a, i) => args["_" + i] = evalLua(a, vars));
        return { name: name, args: args };
    }

    // Call of a local helper: substitute its parameters and evaluate its body.
    const fn = funcs[callee];
    if (fn) {
        const local = Object.assign({}, vars);
        splitArgs(inner).forEach((a, i) => { if (fn.params[i]) local[fn.params[i]] = evalLua(a, vars); });
        const body = fn.body.replace(/^\s*return\s+/, "").replace(/\s*\bend\s*$/, "").trim();
        return luaAction(body, local, {});
    }
    return { name: callee, args: {} };
}

// ---------- hyprlang -----------------------------------------------------------

function parseHyprlang(files) {
    const vars = {};
    const rows = [];
    for (const f of files) {
        for (let line of String(f.text || "").split("\n")) {
            line = line.replace(/(^|\s)#.*$/, "").trim();
            let m = line.match(/^\$(\w+)\s*=\s*(.*)$/);
            if (m) { vars[m[1]] = m[2].trim(); continue; }
            m = line.match(/^bind([a-z]*)\s*=\s*(.*)$/);
            if (!m) continue;
            const flags = {};
            for (const c of m[1]) flags[{ l: "locked", e: "repeating", m: "mouse", r: "release", d: "described" }[c] || c] = true;
            const sub = s => s.replace(/\$(\w+)/g, (x, n) => vars[n] !== undefined ? vars[n] : x);
            const fields = m[2].split(",").map(s => s.trim());
            const mods = sub(fields[0] || "").split(/[\s+_]+/).filter(p => p);
            const key = sub(fields[1] || "");
            let desc = "", rest = fields.slice(2);
            if (flags.described) { desc = rest.shift() || ""; }
            const disp = rest.shift() || "";
            const arg = sub(rest.join(", "));
            rows.push(makeRow(mods, key, fromDispatcher(disp, arg), flags, f.path, desc));
        }
    }
    return rows;
}

// ---------- hyprctl -j binds -----------------------------------------------------

function parseLive(json, fileRows) {
    let list;
    try { list = typeof json === "string" ? JSON.parse(json) : json; } catch (e) { return null; }
    if (!Array.isArray(list)) return null;
    const known = {};
    for (const r of fileRows || []) known[combo(r.mods, r.key)] = r;

    const rows = [];
    for (const b of list) {
        const mods = MOD_BITS.filter(([bit]) => (b.modmask & bit) !== 0).map(([, n]) => n);
        const key = b.key || (b.keycode ? "code:" + b.keycode : "");
        if (!key) continue;
        const flags = { locked: !!b.locked, mouse: !!b.mouse, repeating: !!b.repeat, release: !!b.release };
        const action = fromDispatcher(b.dispatcher, b.arg);
        const row = makeRow(mods, key, action, flags, "hyprctl", b.has_description || b.description ? b.description : "");
        // Lua closures show up as opaque dispatchers; borrow the description parsed from the files.
        if (row.category === "Other" && !b.description) {
            const f = known[combo(mods, key)];
            if (f) { row.description = f.description; row.category = f.category; row.command = f.command; }
        }
        rows.push(row);
    }
    return collapse(rows);
}

// Merge runs like SUPER+1..SUPER+0 "Go to workspace N" into one row.
function collapse(rows) {
    const groups = {};
    const out = [];
    for (const r of rows) {
        const n = r.description.match(/\b(\d+)\b/);
        if (!/^\d$/.test(r.key) || !n) { out.push(r); continue; }
        const g = [r.category, r.mods.join("+"), r.description.replace(/\b\d+\b/, "#")].join("|");
        if (!groups[g]) { groups[g] = { first: r, nums: [], keys: [] }; out.push(groups[g]); }
        groups[g].nums.push(parseInt(n[1]));
        groups[g].keys.push(r.key);
    }
    return out.map(x => {
        if (!x.first) return x;
        if (x.nums.length < 3) return Object.assign({}, x.first);
        const lo = Math.min.apply(null, x.nums), hi = Math.max.apply(null, x.nums);
        return Object.assign({}, x.first, {
            key: x.keys[0] + "…" + x.keys[x.keys.length - 1],
            description: x.first.description.replace(/\b\d+\b/, lo + "–" + hi)
        });
    });
}

// Group rows by category in display order, applying a search query.
function group(rows, query) {
    const q = String(query || "").trim().toLowerCase();
    const match = r => !q || [r.description, r.category, r.command, r.mods.join(" "), r.key]
        .join(" ").toLowerCase().includes(q);
    const out = [];
    for (const c of CATEGORIES) {
        const items = rows.filter(r => r.category === c.name && match(r));
        if (items.length) out.push({ name: c.name, icon: c.icon, items: items });
    }
    return out;
}

// Entry point for file sources: picks the parser by extension and dedupes by combo.
function parseFiles(files) {
    const lua = files.filter(f => /\.lua$/.test(f.path));
    const conf = files.filter(f => /\.conf$/.test(f.path));
    const rows = parseLua(lua).concat(parseHyprlang(conf));
    const seen = {};
    return rows.filter(r => {
        const k = combo(r.mods, r.key) + "|" + r.description;
        if (seen[k]) return false;
        seen[k] = true;
        return true;
    });
}
