.pragma library

// Every card the desktop canvas and CardsColumn can show. Sizes are in grid
// cells (see CardStyle.cell / gap). `framed` cards draw a regular surface;
// the others are free-standing shapes (cookie, tank, pill).
var cards = [
    { type: "clock",    name: "Cookie clock",  icon: "schedule",        w: 3, h: 3, min: [2, 2], max: [5, 5], square: true },
    { type: "digital",  name: "Big clock",     icon: "timer_10_alt_1",  w: 4, h: 2, min: [2, 2], max: [8, 5] },
    { type: "weather",  name: "Weather",       icon: "partly_cloudy_day", w: 4, h: 2, min: [3, 2], max: [8, 4], needs: "weather" },
    { type: "cpu",      name: "CPU",           icon: "memory",          w: 2, h: 2, min: [1, 1], max: [4, 4], square: true },
    { type: "memory",   name: "Memory",        icon: "memory_alt",      w: 2, h: 2, min: [1, 1], max: [4, 4], square: true },
    { type: "gpu",      name: "GPU",           icon: "developer_board", w: 2, h: 2, min: [1, 1], max: [4, 4], square: true },
    { type: "temp",     name: "Temperature",   icon: "thermostat",      w: 2, h: 2, min: [1, 1], max: [4, 4], square: true },
    { type: "cpuTile",  name: "CPU trend",     icon: "monitoring",      w: 3, h: 2, min: [2, 2], max: [6, 4] },
    { type: "memTile",  name: "Memory trend",  icon: "monitoring",      w: 3, h: 2, min: [2, 2], max: [6, 4] },
    { type: "gpuTile",  name: "GPU trend",     icon: "monitoring",      w: 3, h: 2, min: [2, 2], max: [6, 4] },
    { type: "network",  name: "Network",       icon: "swap_vert",       w: 4, h: 2, min: [3, 1], max: [8, 4] },
    { type: "storage",  name: "Storage",       icon: "hard_drive",      w: 4, h: 2, min: [3, 2], max: [8, 5] },
    { type: "battery",  name: "Battery",       icon: "battery_full",    w: 2, h: 3, min: [1, 2], max: [3, 4] },
    { type: "calendar", name: "Calendar",      icon: "calendar_month",  w: 3, h: 3, min: [3, 3], max: [5, 5] },
    { type: "cava",     name: "Visualizer",    icon: "graphic_eq",      w: 4, h: 2, min: [2, 1], max: [8, 4] },
    { type: "todo",     name: "To-do",         icon: "checklist",       w: 3, h: 4, min: [3, 3], max: [5, 8] }
];

function find(type) {
    for (var i = 0; i < cards.length; i++)
        if (cards[i].type === type) return cards[i];
    return null;
}

// Layout used until the user edits a screen: clock and weather top-left,
// a row of liquid metrics under them, calendar + to-do on the right edge.
// Without the weather service its slot shows the big-number clock instead.
function defaultLayout(cols, rows, hasWeather) {
    var out = [
        { type: "clock",   x: 0, y: 0, w: 3, h: 3 },
        { type: hasWeather ? "weather" : "digital", x: 0, y: 3, w: 4, h: 2 },
        { type: "cpu",     x: 0, y: 5, w: 2, h: 2 },
        { type: "memory",  x: 2, y: 5, w: 2, h: 2 },
        { type: "cpuTile", x: 0, y: 7, w: 4, h: 2 }
    ];
    if (cols >= 14) {
        out.push({ type: "calendar", x: cols - 3, y: 0, w: 3, h: 3 });
        out.push({ type: "network", x: cols - 4, y: 3, w: 4, h: 2 });
    }
    // Drop anything that does not fit a small screen.
    return out.filter(function (c) { return c.x >= 0 && c.x + c.w <= cols && c.y + c.h <= rows; })
              .map(function (c, i) { c.id = "d" + i; return c; });
}

function overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

function fits(rect, cards, ignoreId, cols, rows) {
    if (rect.x < 0 || rect.y < 0 || rect.x + rect.w > cols || rect.y + rect.h > rows) return false;
    for (var i = 0; i < cards.length; i++)
        if (cards[i].id !== ignoreId && overlaps(rect, cards[i])) return false;
    return true;
}

// First free cell scanning columns left→right then rows, or null.
function freeSpot(w, h, cards, cols, rows) {
    for (var x = 0; x + w <= cols; x++)
        for (var y = 0; y + h <= rows; y++)
            if (fits({ x: x, y: y, w: w, h: h }, cards, null, cols, rows)) return { x: x, y: y };
    return null;
}

// Nearest free position to (x, y) within `radius` cells, or null.
function nearestFree(rect, cards, ignoreId, cols, rows, radius) {
    var best = null, bestD = 1e9;
    for (var dy = -radius; dy <= radius; dy++)
        for (var dx = -radius; dx <= radius; dx++) {
            var r = { x: rect.x + dx, y: rect.y + dy, w: rect.w, h: rect.h };
            var d = dx * dx + dy * dy;
            if (d < bestD && fits(r, cards, ignoreId, cols, rows)) { best = r; bestD = d; }
        }
    return best;
}
