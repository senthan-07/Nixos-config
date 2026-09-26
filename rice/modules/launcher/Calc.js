// Calculator and unit conversion for the launcher.
// A small recursive-descent parser (no eval) with functions, constants,
// implicit multiplication, factorial, percentages and base literals.
.pragma library

// ---------------------------------------------------------------- tokenizer

function tokenize(src) {
    const out = [];
    let i = 0;
    const s = String(src);
    while (i < s.length) {
        const ch = s[i];
        if (/\s/.test(ch)) { i++; continue; }
        // Base literals: 0x1f, 0b101, 0o17
        const base = /^0([xbo])([0-9a-f_]+)/i.exec(s.slice(i));
        if (base) {
            const radix = { x: 16, b: 2, o: 8 }[base[1].toLowerCase()];
            const v = parseInt(base[2].replace(/_/g, ""), radix);
            if (isNaN(v)) throw new Error("bad literal");
            out.push({ t: "num", v: v });
            i += base[0].length;
            continue;
        }
        const num = /^(\d[\d_,]*\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(s.slice(i));
        if (num) {
            // Allow 1,000,000 style separators only when grouped by three.
            let text = num[0];
            if (text.includes(",") && !/^\d{1,3}(,\d{3})+(\.\d*)?(e[+-]?\d+)?$/i.test(text)) {
                text = text.slice(0, text.indexOf(","));
            }
            out.push({ t: "num", v: parseFloat(text.replace(/[_,]/g, "")) });
            i += text.length;
            continue;
        }
        const id = /^[a-zπτφ°µ][a-z0-9_]*/i.exec(s.slice(i));
        if (id) {
            out.push({ t: "id", v: id[0].toLowerCase() });
            i += id[0].length;
            continue;
        }
        if (s.startsWith("**", i)) { out.push({ t: "op", v: "^" }); i += 2; continue; }
        const map = { "×": "*", "·": "*", "÷": "/", "−": "-" };
        const op = map[ch] || ch;
        if ("+-*/%^!(),".includes(op)) {
            out.push({ t: "op", v: op });
            i++;
            continue;
        }
        throw new Error(`unexpected "${ch}"`);
    }
    return out;
}

// ---------------------------------------------------------------- parser

const constants = {
    pi: Math.PI, "π": Math.PI, tau: 2 * Math.PI, "τ": 2 * Math.PI,
    e: Math.E, phi: (1 + Math.sqrt(5)) / 2, "φ": (1 + Math.sqrt(5)) / 2,
    deg: Math.PI / 180, "°": Math.PI / 180, inf: Infinity, infinity: Infinity
};

function factorial(n) {
    if (n < 0 || !Number.isInteger(n)) return gamma(n + 1);
    if (n > 170) return Infinity;
    let r = 1;
    for (let k = 2; k <= n; k++) r *= k;
    return r;
}

// Lanczos approximation, for non-integer factorials.
function gamma(z) {
    if (z < 0.5) return Math.PI / (Math.sin(Math.PI * z) * gamma(1 - z));
    const g = 7;
    const c = [0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
        -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7];
    z -= 1;
    let x = c[0];
    for (let i = 1; i < g + 2; i++) x += c[i] / (z + i);
    const t = z + g + 0.5;
    return Math.sqrt(2 * Math.PI) * Math.pow(t, z + 0.5) * Math.exp(-t) * x;
}

function gcd(a, b) { a = Math.abs(a); b = Math.abs(b); while (b) [a, b] = [b, a % b]; return a; }

const functions = {
    sin: Math.sin, cos: Math.cos, tan: Math.tan,
    asin: Math.asin, acos: Math.acos, atan: Math.atan, atan2: Math.atan2,
    arcsin: Math.asin, arccos: Math.acos, arctan: Math.atan,
    sinh: Math.sinh, cosh: Math.cosh, tanh: Math.tanh,
    sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, exp: Math.exp,
    ln: Math.log, log2: Math.log2, log10: Math.log10,
    log: (x, b) => b === undefined ? Math.log10(x) : Math.log(x) / Math.log(b),
    floor: Math.floor, ceil: Math.ceil, trunc: Math.trunc, sign: Math.sign,
    round: (x, d) => d === undefined ? Math.round(x) : Math.round(x * Math.pow(10, d)) / Math.pow(10, d),
    min: Math.min, max: Math.max, pow: Math.pow, hypot: Math.hypot,
    fact: factorial, gamma: gamma,
    gcd: gcd, lcm: (a, b) => Math.abs(a * b) / gcd(a, b),
    ncr: (n, r) => factorial(n) / (factorial(r) * factorial(n - r)),
    npr: (n, r) => factorial(n) / factorial(n - r),
    rad: x => x * Math.PI / 180, todeg: x => x * 180 / Math.PI,
    avg: (...a) => a.reduce((s, x) => s + x, 0) / a.length,
    sum: (...a) => a.reduce((s, x) => s + x, 0),
    rand: () => Math.random()
};

function Parser(tokens) {
    this.tokens = tokens;
    this.pos = 0;
    this.usedOperator = false;
}

Parser.prototype.peek = function () { return this.tokens[this.pos]; };
Parser.prototype.next = function () { return this.tokens[this.pos++]; };
Parser.prototype.isOp = function (v) { const t = this.peek(); return t && t.t === "op" && t.v === v; };
Parser.prototype.expect = function (v) {
    if (!this.isOp(v)) throw new Error(`expected "${v}"`);
    this.pos++;
};

Parser.prototype.expr = function () {
    let v = this.term();
    while (this.isOp("+") || this.isOp("-")) {
        const op = this.next().v;
        this.usedOperator = true;
        // "200 + 10%" means 200 * 1.10, like a pocket calculator.
        const start = this.pos;
        const rhs = this.term();
        const pct = this.tokens[this.pos - 1];
        const isPercent = pct && pct.t === "op" && pct.v === "%" && this.pos - start >= 2 && pct.percent;
        const amount = isPercent ? v * rhs : rhs;
        v = op === "+" ? v + amount : v - amount;
    }
    return v;
};

Parser.prototype.startsFactor = function () {
    const t = this.peek();
    if (!t) return false;
    if (t.t === "num") return true;
    if (t.t === "id") return t.v !== "of" && t.v !== "mod";
    return t.t === "op" && t.v === "(";
};

Parser.prototype.term = function () {
    let v = this.unary();
    for (;;) {
        const t = this.peek();
        if (t && t.t === "op" && (t.v === "*" || t.v === "/")) {
            this.next();
            this.usedOperator = true;
            const r = this.unary();
            v = t.v === "*" ? v * r : v / r;
        } else if (t && t.t === "op" && t.v === "%" ) {
            // Binary modulo (postfix percent is consumed in postfix()).
            this.next();
            this.usedOperator = true;
            const r = this.unary();
            v = ((v % r) + r) % r;
        } else if (t && t.t === "id" && (t.v === "mod" || t.v === "of")) {
            this.next();
            this.usedOperator = true;
            const r = this.unary();
            v = t.v === "of" ? v * r : ((v % r) + r) % r;
        } else if (this.startsFactor()) {
            // Implicit multiplication: 2pi, 3(4+1), (1+2)(3+4)
            this.usedOperator = true;
            v = v * this.unary();
        } else {
            return v;
        }
    }
};

Parser.prototype.unary = function () {
    if (this.isOp("-")) { this.next(); return -this.unary(); }
    if (this.isOp("+")) { this.next(); return this.unary(); }
    return this.power();
};

Parser.prototype.power = function () {
    const base = this.postfix();
    if (this.isOp("^")) {
        this.next();
        this.usedOperator = true;
        return Math.pow(base, this.unary());
    }
    return base;
};

Parser.prototype.postfix = function () {
    let v = this.primary();
    for (;;) {
        if (this.isOp("!")) {
            this.next();
            this.usedOperator = true;
            v = factorial(v);
        } else if (this.isOp("%")) {
            // Postfix percent when nothing that could be a right operand follows.
            const after = this.tokens[this.pos + 1];
            const operand = after && (after.t === "num" || (after.t === "id" && after.v !== "of" && after.v !== "mod")
                || (after.t === "op" && (after.v === "(" || after.v === "-" || after.v === "+")));
            if (operand) return v;
            const tok = this.next();
            tok.percent = true;
            this.usedOperator = true;
            v = v / 100;
        } else {
            return v;
        }
    }
};

Parser.prototype.primary = function () {
    const t = this.next();
    if (!t) throw new Error("unexpected end");
    if (t.t === "num") return t.v;
    if (t.t === "op" && t.v === "(") {
        const v = this.expr();
        if (this.peek()) this.expect(")");      // tolerate a missing final ")"
        return v;
    }
    if (t.t === "id") {
        if (functions[t.v] && this.isOp("(")) {
            this.next();
            const args = [];
            if (!this.isOp(")")) {
                args.push(this.expr());
                while (this.isOp(",")) { this.next(); args.push(this.expr()); }
            }
            if (this.peek()) this.expect(")");
            this.usedOperator = true;
            return functions[t.v].apply(null, args);
        }
        if (functions[t.v] && this.startsFactor()) {
            // sqrt 16, sin pi
            this.usedOperator = true;
            return functions[t.v](this.postfix());
        }
        if (constants[t.v] !== undefined) {
            this.usedOperator = true;
            return constants[t.v];
        }
        throw new Error(`unknown "${t.v}"`);
    }
    throw new Error(`unexpected "${t.v}"`);
};

// Returns { value, trivial } or throws.
function evaluate(src) {
    const tokens = tokenize(src);
    if (!tokens.length) throw new Error("empty");
    const p = new Parser(tokens);
    const value = p.expr();
    if (p.pos < tokens.length) throw new Error(`unexpected "${tokens[p.pos].v}"`);
    return { value: value, trivial: !p.usedOperator };
}

// ---------------------------------------------------------------- formatting

function format(v) {
    if (typeof v !== "number" || isNaN(v)) return "";
    if (!isFinite(v)) return v > 0 ? "∞" : "-∞";
    if (v === 0) return "0";
    const abs = Math.abs(v);
    if (abs >= 1e15 || abs < 1e-9) {
        return v.toExponential(8).replace(/\.?0+e/, "e").replace("e+", "e");
    }
    const rounded = +v.toPrecision(12);
    return String(rounded);
}

// Human display with digit grouping (the raw `format` value is what gets copied).
function pretty(v) {
    const raw = format(v);
    if (!/^-?\d+(\.\d+)?$/.test(raw)) return raw;
    const parts = raw.split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return parts.join(".");
}

// Conversions: 8 significant digits is plenty and avoids float noise.
function prettyShort(v) {
    return pretty(typeof v === "number" && isFinite(v) && v !== 0 ? +v.toPrecision(8) : v);
}

function bases(v) {
    if (!Number.isInteger(v) || Math.abs(v) > Number.MAX_SAFE_INTEGER || Math.abs(v) < 2) return "";
    const sign = v < 0 ? "-" : "";
    const a = Math.abs(v);
    const bin = a.toString(2);
    return `${sign}0x${a.toString(16).toUpperCase()}` + (bin.length <= 32 ? `  ·  ${sign}0b${bin}` : "");
}

// ---------------------------------------------------------------- units

// [category, factor-to-base, display, aliases...]
const unitDefs = [
    ["Length", 1, "m", "m", "meter", "meters", "metre", "metres"],
    ["Length", 1000, "km", "km", "kilometer", "kilometers", "kilometre", "kilometres"],
    ["Length", 0.01, "cm", "cm", "centimeter", "centimeters"],
    ["Length", 0.001, "mm", "mm", "millimeter", "millimeters"],
    ["Length", 1e-6, "µm", "um", "µm", "micron", "microns"],
    ["Length", 1e-9, "nm", "nm", "nanometer", "nanometers"],
    ["Length", 1609.344, "mi", "mi", "mile", "miles"],
    ["Length", 0.9144, "yd", "yd", "yard", "yards"],
    ["Length", 0.3048, "ft", "ft", "foot", "feet"],
    ["Length", 0.0254, "in", "in", "inch", "inches"],
    ["Length", 1852, "nmi", "nmi", "nauticalmile"],
    ["Length", 9.4607e15, "ly", "ly", "lightyear", "lightyears"],
    ["Length", 1.495978707e11, "au", "au"],

    ["Mass", 1, "kg", "kg", "kilogram", "kilograms", "kilo", "kilos"],
    ["Mass", 0.001, "g", "g", "gram", "grams"],
    ["Mass", 1e-6, "mg", "mg", "milligram", "milligrams"],
    ["Mass", 1000, "t", "t", "tonne", "tonnes", "ton", "tons"],
    ["Mass", 0.45359237, "lb", "lb", "lbs", "pound", "pounds"],
    ["Mass", 0.028349523125, "oz", "oz", "ounce", "ounces"],
    ["Mass", 6.35029318, "st", "st", "stone", "stones"],

    ["Time", 1, "s", "s", "sec", "secs", "second", "seconds"],
    ["Time", 0.001, "ms", "ms", "millisecond", "milliseconds"],
    ["Time", 60, "min", "min", "mins", "minute", "minutes"],
    ["Time", 3600, "h", "h", "hr", "hrs", "hour", "hours"],
    ["Time", 86400, "d", "d", "day", "days"],
    ["Time", 604800, "wk", "wk", "week", "weeks"],
    ["Time", 2629800, "mo", "mo", "month", "months"],
    ["Time", 31557600, "yr", "yr", "yrs", "year", "years"],

    ["Data", 1, "B", "b", "byte", "bytes"],
    ["Data", 0.125, "bit", "bit", "bits"],
    ["Data", 1e3, "KB", "kb", "kilobyte", "kilobytes"],
    ["Data", 1e6, "MB", "mb", "megabyte", "megabytes"],
    ["Data", 1e9, "GB", "gb", "gigabyte", "gigabytes"],
    ["Data", 1e12, "TB", "tb", "terabyte", "terabytes"],
    ["Data", 1e15, "PB", "pb", "petabyte", "petabytes"],
    ["Data", 1024, "KiB", "kib"],
    ["Data", 1048576, "MiB", "mib"],
    ["Data", 1073741824, "GiB", "gib"],
    ["Data", 1099511627776, "TiB", "tib"],
    ["Data", 125, "kbit", "kbit", "kbits"],
    ["Data", 125000, "Mbit", "mbit", "mbits"],
    ["Data", 125000000, "Gbit", "gbit", "gbits"],

    ["Speed", 1, "m/s", "m/s", "mps"],
    ["Speed", 1 / 3.6, "km/h", "km/h", "kmh", "kph", "kmph"],
    ["Speed", 0.44704, "mph", "mph", "mi/h"],
    ["Speed", 0.514444, "kn", "kn", "knot", "knots"],
    ["Speed", 0.3048, "ft/s", "ft/s", "fps"],

    ["Area", 1, "m²", "m2", "m²", "sqm"],
    ["Area", 1e6, "km²", "km2", "km²", "sqkm"],
    ["Area", 1e-4, "cm²", "cm2", "cm²"],
    ["Area", 0.09290304, "ft²", "ft2", "ft²", "sqft"],
    ["Area", 0.00064516, "in²", "in2", "in²", "sqin"],
    ["Area", 4046.8564224, "acre", "acre", "acres", "ac"],
    ["Area", 10000, "ha", "ha", "hectare", "hectares"],
    ["Area", 2589988.110336, "mi²", "mi2", "mi²", "sqmi"],

    ["Volume", 1, "L", "l", "liter", "liters", "litre", "litres"],
    ["Volume", 0.001, "mL", "ml", "milliliter", "milliliters"],
    ["Volume", 0.01, "cL", "cl"],
    ["Volume", 0.1, "dL", "dl"],
    ["Volume", 1000, "m³", "m3", "m³"],
    ["Volume", 0.001, "cm³", "cm3", "cc"],
    ["Volume", 3.785411784, "gal", "gal", "gallon", "gallons"],
    ["Volume", 0.946352946, "qt", "qt", "quart", "quarts"],
    ["Volume", 0.473176473, "pt", "pt", "pint", "pints"],
    ["Volume", 0.24, "cup", "cup", "cups"],
    ["Volume", 0.0295735295625, "fl oz", "floz"],
    ["Volume", 0.01478676478125, "tbsp", "tbsp"],
    ["Volume", 0.00492892159375, "tsp", "tsp"],

    ["Energy", 1, "J", "j", "joule", "joules"],
    ["Energy", 1000, "kJ", "kj"],
    ["Energy", 4.184, "cal", "cal"],
    ["Energy", 4184, "kcal", "kcal"],
    ["Energy", 3600, "Wh", "wh"],
    ["Energy", 3.6e6, "kWh", "kwh"],
    ["Energy", 1.602176634e-19, "eV", "ev"],

    ["Power", 1, "W", "w", "watt", "watts"],
    ["Power", 1000, "kW", "kw", "kilowatt", "kilowatts"],
    ["Power", 745.69987158, "hp", "hp", "horsepower"],

    ["Pressure", 1, "Pa", "pa"],
    ["Pressure", 1000, "kPa", "kpa"],
    ["Pressure", 100000, "bar", "bar"],
    ["Pressure", 6894.757293, "psi", "psi"],
    ["Pressure", 101325, "atm", "atm"],
    ["Pressure", 133.322387415, "mmHg", "mmhg"],

    ["Angle", 1, "rad", "rad", "radian", "radians"],
    ["Angle", Math.PI / 180, "°", "deg", "degree", "degrees", "°"],
    ["Angle", Math.PI / 200, "grad", "grad", "gon"],
    ["Angle", 2 * Math.PI, "turn", "turn", "turns", "rev"],

    ["Frequency", 1, "Hz", "hz"],
    ["Frequency", 1e3, "kHz", "khz"],
    ["Frequency", 1e6, "MHz", "mhz"],
    ["Frequency", 1e9, "GHz", "ghz"],
];

const temperature = {
    c: "°C", "°c": "°C", celsius: "°C",
    f: "°F", "°f": "°F", fahrenheit: "°F",
    k: "K", kelvin: "K"
};

const units = {};
for (const d of unitDefs) {
    for (let i = 3; i < d.length; i++) units[d[i]] = { cat: d[0], f: d[1], name: d[2] };
}

function lookupUnit(name) {
    name = String(name).toLowerCase().replace(/\s+/g, "");
    if (temperature[name]) return { cat: "Temperature", name: temperature[name] };
    return units[name] || null;
}

function toKelvin(v, u) {
    return u === "°C" ? v + 273.15 : u === "°F" ? (v - 32) * 5 / 9 + 273.15 : v;
}

function fromKelvin(v, u) {
    return u === "°C" ? v - 273.15 : u === "°F" ? (v - 273.15) * 9 / 5 + 32 : v;
}

const conversionRe = /^(.*?)\s*([a-zµ°²³][a-z0-9µ°²³\/ ]*?)\s+(?:to|in|into|as|->|=>|=)\s+([a-zµ°²³][a-z0-9µ°²³\/ ]*?)\s*$/i;

// "10 km to mi" → { category, value, from, to, result } or null.
function convert(query) {
    const m = conversionRe.exec(String(query).trim());
    if (!m) return null;
    const from = lookupUnit(m[2]);
    const to = lookupUnit(m[3]);
    if (!from || !to || from.cat !== to.cat) return null;
    let amount = 1;
    if (m[1].trim()) {
        try { amount = evaluate(m[1]).value; } catch (e) { return null; }
    }
    if (typeof amount !== "number" || !isFinite(amount)) return null;
    let result;
    if (from.cat === "Temperature") result = fromKelvin(toKelvin(amount, from.name), to.name);
    else result = amount * from.f / to.f;
    return { category: from.cat, value: amount, from: from.name, to: to.name, result: result };
}

// Currency-shaped query: "100 usd to inr", "$20 in eur", "5k jpy to usd".
const symbols = { "$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY", "₹": "INR", "₩": "KRW", "₽": "RUB", "₺": "TRY", "₫": "VND", "₱": "PHP", "฿": "THB" };

function parseCurrency(query) {
    let q = String(query).trim();
    let symbol = "";
    const sm = /^([$€£¥₹₩₽₺₫₱฿])\s*/.exec(q);
    if (sm) { symbol = symbols[sm[1]]; q = q.slice(sm[0].length); }
    const m = /^([\d.,_]+\s*[kmb]?|.*?[\d)]\s*)?\s*([a-z]{3})?\s*(?:to|in|into|as|->|=>|=)\s*([a-z]{3})\s*$/i.exec(q);
    if (!m) return null;
    const from = (m[2] || symbol || "").toUpperCase();
    const to = m[3].toUpperCase();
    if (!from || (symbol && m[2])) return null;
    let raw = (m[1] || "1").trim();
    let mult = 1;
    const suffix = /([kmb])$/i.exec(raw);
    if (suffix && /\d\s*[kmb]$/i.test(raw)) {
        mult = { k: 1e3, m: 1e6, b: 1e9 }[suffix[1].toLowerCase()];
        raw = raw.slice(0, -1);
    }
    let amount;
    try { amount = evaluate(raw).value * mult; } catch (e) { return null; }
    if (!isFinite(amount)) return null;
    return { amount: amount, from: from, to: to };
}

// Default-mode heuristic: only show an answer when the query is clearly math
// (the parser must also have applied an operator, function or constant).
function looksLikeMath(q) {
    q = String(q).trim();
    return q.length > 1 && /[\dπτφ]|\b(pi|tau|phi|e)\b/i.test(q);
}
