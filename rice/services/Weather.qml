pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// Weather from Open-Meteo (forecast + air quality, no API key).
// Location comes from a configured city (Open-Meteo geocoding) or, when no
// city is set, from IP geolocation. Raw responses are cached in
// $XDG_STATE_HOME/rice/weather.json and re-parsed when the unit changes, so a
// restart shows the last forecast immediately.
//
//   qs -c rice ipc call weather refresh
//   qs -c rice ipc call weather setCity "Berlin"      ("" = auto-detect)
//   qs -c rice ipc call weather setUnit F
Singleton {
    id: root

    // ---- public contract ---------------------------------------------------
    property bool ready: false
    property bool loading: false
    property string error: ""
    property string location: ""
    readonly property string unit: store.get("unit", "C") === "F" ? "F" : "C"
    readonly property string city: store.get("city", "")
    property real latitude: NaN
    property real longitude: NaN
    property var lastUpdated: null          // Date of the last successful fetch
    // "empty" | "fresh" | "stale" | "error"
    readonly property string status: {
        if (!ready) return error ? "error" : "empty";
        if (error) return "error";
        return lastUpdated && (clock.date - lastUpdated) > staleAfter ? "stale" : "fresh";
    }

    // {temp, feelsLike, humidity, windSpeed, windDir, windGusts, code, isDay, description,
    //  icon, uv, pressure, visibility, precipitation, dewPoint, cloudCover}
    property var current: null
    // [{time: Date, temp, code, icon, precipProb, isDay}] — next 24 hours
    property var hourly: []
    // [{date: Date, min, max, code, icon, sunrise: Date, sunset: Date, precipSum, precipProb, uvMax, windMax, description}]
    property var daily: []
    property var aqi: null                  // US AQI, number | null
    // {usAqi, europeanAqi, pm25, pm10, ozone, no2}
    property var air: null
    // {phase 0..1 (0 new, .5 full), illumination 0..1, name, waxing}
    readonly property var moon: moonFor(clock.date)

    // Forecast times are shifted into the forecast location's wall-clock
    // time, so Qt.formatTime() shows local hours even for a far-away city.
    // Add this to Date.now() before comparing against them.
    property real timeShift: 0

    readonly property string tempUnit: "°" + unit
    readonly property string speedUnit: unit === "F" ? "mph" : "km/h"
    readonly property string distanceUnit: unit === "F" ? "mi" : "km"
    readonly property string precipUnit: unit === "F" ? "in" : "mm"

    readonly property int refreshInterval: 15 * 60 * 1000
    readonly property int staleAfter: 60 * 60 * 1000

    function refresh() {
        if (loading) return;
        error = "";
        loading = true;
        watchdog.restart();
        const gen = ++generation;
        if (city) geocode(city, gen);
        else locateByIp(0, gen);
    }

    function setCity(name) {
        name = (name || "").trim();
        store.set("city", name);
        cancel();
        refresh();
    }

    function setUnit(u) {
        u = String(u || "").toUpperCase().startsWith("F") ? "F" : "C";
        store.set("unit", u);
        Qt.callLater(reparse);
    }

    function toggleUnit() {
        setUnit(unit === "C" ? "F" : "C");
    }

    function fmtTemp(v) {
        return v === undefined || v === null || isNaN(v) ? "--" : Math.round(v) + "°";
    }

    // Material Symbols glyph for a WMO weather code.
    function iconFor(code, isDay) {
        const day = isDay === undefined || !!isDay;
        switch (code) {
        case 0: return day ? "clear_day" : "bedtime";
        case 1:
        case 2: return day ? "partly_cloudy_day" : "partly_cloudy_night";
        case 3: return "cloud";
        case 45:
        case 48: return "foggy";
        case 51: case 53: case 55: case 56: case 57:
        case 61: case 63: case 65: case 66: case 67:
        case 80: case 81: case 82: return "rainy";
        case 71: case 73: case 75: case 77: case 85: case 86: return "weather_snowy";
        case 95: return "thunderstorm";
        case 96: case 99: return "weather_hail";
        }
        return "cloud";
    }

    function describe(code) {
        return ({
            0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
            45: "Fog", 48: "Rime fog",
            51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
            56: "Freezing drizzle", 57: "Freezing drizzle",
            61: "Light rain", 63: "Rain", 65: "Heavy rain",
            66: "Freezing rain", 67: "Freezing rain",
            71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains",
            80: "Rain showers", 81: "Rain showers", 82: "Violent showers",
            85: "Snow showers", 86: "Heavy snow showers",
            95: "Thunderstorm", 96: "Thunderstorm, hail", 99: "Thunderstorm, hail"
        })[code] || "Unknown";
    }

    // "clear" | "partly" | "cloudy" | "fog" | "rain" | "snow" | "storm"
    function sceneFor(code) {
        if (code === undefined || code === null) return "cloudy";
        if (code >= 95) return "storm";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "rain";
        if (code === 45 || code === 48) return "fog";
        if (code === 3) return "cloudy";
        if (code === 1 || code === 2) return "partly";
        return "clear";
    }

    function valid(v) {
        return v !== undefined && v !== null && !isNaN(v);
    }

    function fmt(v, digits) {
        return valid(v) ? Number(v).toFixed(digits || 0) : "--";
    }

    function compass(deg) {
        if (!valid(deg)) return "--";
        return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round((((deg % 360) + 360) % 360) / 45) % 8];
    }

    // {name, color} for a UV index.
    function uvLevel(uv) {
        if (!valid(uv)) return { name: "--", color: "#8a8f98" };
        if (uv < 3) return { name: "Low", color: "#5ccf6a" };
        if (uv < 6) return { name: "Moderate", color: "#f5c33b" };
        if (uv < 8) return { name: "High", color: "#ff8c3a" };
        if (uv < 11) return { name: "Very high", color: "#ff4d5a" };
        return { name: "Extreme", color: "#b264ff" };
    }

    // {name, color} for a US AQI value.
    function aqiLevel(v) {
        if (!valid(v)) return { name: "Unavailable", color: "#8a8f98" };
        if (v <= 50) return { name: "Good", color: "#5ccf6a" };
        if (v <= 100) return { name: "Moderate", color: "#f5c33b" };
        if (v <= 150) return { name: "Unhealthy for some", color: "#ff8c3a" };
        if (v <= 200) return { name: "Unhealthy", color: "#ff4d5a" };
        if (v <= 300) return { name: "Very unhealthy", color: "#b264ff" };
        return { name: "Hazardous", color: "#a3294f" };
    }

    function formatTime(date) {
        if (!date) return "--";
        return Qt.formatTime(date, Settings.data.use24h ? "HH:mm" : "h:mm AP");
    }

    function moonFor(date) {
        const synodic = 29.530588853;
        const ref = Date.UTC(2000, 0, 6, 18, 14) ; // a known new moon
        let phase = ((date.getTime() - ref) / 86400000 / synodic) % 1;
        if (phase < 0) phase += 1;
        // Principal phases get about a day either side; the rest is in between.
        const name = phase < 0.034 || phase > 0.966 ? "New moon"
            : phase < 0.216 ? "Waxing crescent" : phase < 0.284 ? "First quarter"
            : phase < 0.466 ? "Waxing gibbous" : phase < 0.534 ? "Full moon"
            : phase < 0.716 ? "Waning gibbous" : phase < 0.784 ? "Last quarter" : "Waning crescent";
        return {
            phase,
            illumination: (1 - Math.cos(2 * Math.PI * phase)) / 2,
            name,
            waxing: phase < 0.5,
            age: phase * synodic
        };
    }

    // ---- internals ---------------------------------------------------------
    property int generation: 0
    property var place: null   // {name, lat, lon}

    function cancel() {
        generation++;
        loading = false;
        watchdog.stop();
    }

    function fail(gen, message) {
        if (gen !== generation) return;
        console.warn("rice: weather:", message);
        error = message;
        loading = false;
        watchdog.stop();
    }

    // GET + JSON.parse with a per-request timeout, so a hanging provider falls
    // through to the next one instead of stalling the whole refresh.
    function getJson(url, gen, done) {
        const xhr = new XMLHttpRequest();
        let finished = false;
        const timer = requestTimer.createObject(root);
        timer.triggered.connect(() => {
            if (finished) return;
            finished = true;
            xhr.abort();
            timer.destroy();
            if (gen === root.generation) done("timed out", null);
        });
        timer.start();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || finished) return;
            finished = true;
            timer.stop();
            timer.destroy();
            if (gen !== root.generation) return;
            if (xhr.status !== 200) {
                done(`HTTP ${xhr.status || "error"}`, null);
                return;
            }
            try {
                done("", JSON.parse(xhr.responseText));
            } catch (e) {
                done("Invalid response", null);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function geocode(name, gen) {
        getJson(`https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name=${encodeURIComponent(name)}`, gen, (err, json) => {
            if (err) return fail(gen, `Geocoding failed (${err})`);
            const r = (json.results || [])[0];
            if (!r) return fail(gen, `Couldn't find “${name}”`);
            const label = [r.name, r.admin1 && r.admin1 !== r.name ? r.admin1 : r.country].filter(Boolean).join(", ");
            fetchForecast({ name: label, lat: r.latitude, lon: r.longitude }, gen);
        });
    }

    // Free IP geolocation services, tried in order.
    readonly property var ipProviders: [
        { url: "http://ip-api.com/json/?fields=status,city,regionName,country,lat,lon",
          parse: j => j.status === "success" ? { city: j.city, region: j.regionName || j.country, lat: j.lat, lon: j.lon } : null },
        { url: "https://ipwho.is/",
          parse: j => j.success ? { city: j.city, region: j.region || j.country, lat: j.latitude, lon: j.longitude } : null },
        { url: "https://ipapi.co/json/",
          parse: j => j.latitude !== undefined && !j.error ? { city: j.city, region: j.region || j.country_name, lat: j.latitude, lon: j.longitude } : null }
    ]

    function locateByIp(index, gen) {
        if (index >= ipProviders.length) {
            // Offline or every provider failed: fall back to the cached place.
            const cached = place || (store.get("cache", null) || {}).place;
            if (cached) return fetchForecast(cached, gen);
            return fail(gen, "Couldn't detect your location");
        }
        const p = ipProviders[index];
        getJson(p.url, gen, (err, json) => {
            const loc = err ? null : p.parse(json);
            if (!loc || isNaN(loc.lat)) return locateByIp(index + 1, gen);
            const label = [loc.city, loc.region !== loc.city ? loc.region : ""].filter(Boolean).join(", ");
            fetchForecast({ name: label || "Current location", lat: loc.lat, lon: loc.lon }, gen);
        });
    }

    function fetchForecast(where, gen) {
        const q = `latitude=${where.lat}&longitude=${where.lon}&timezone=auto&timeformat=unixtime`;
        const forecastUrl = "https://api.open-meteo.com/v1/forecast?" + q + "&forecast_days=7"
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,"
            + "cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m,visibility,uv_index,dew_point_2m"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,"
            + "precipitation_probability_max,uv_index_max,wind_speed_10m_max";
        const airUrl = "https://air-quality-api.open-meteo.com/v1/air-quality?" + q
            + "&current=us_aqi,european_aqi,pm10,pm2_5,ozone,nitrogen_dioxide";

        let forecast = null, airJson = undefined;
        const finish = () => {
            if (forecast === null || airJson === undefined) return;
            if (gen !== generation) return;
            const cache = { place: where, forecast, air: airJson, fetchedAt: Date.now() };
            store.set("cache", cache);
            apply(cache);
            error = "";
            loading = false;
            watchdog.stop();
        };

        getJson(forecastUrl, gen, (err, json) => {
            if (err || !json.current) return fail(gen, `Forecast unavailable (${err || "bad data"})`);
            forecast = json;
            finish();
        });
        // Air quality is optional; a failure only hides the AQI card.
        getJson(airUrl, gen, (err, json) => {
            airJson = err ? null : json;
            finish();
        });
    }

    function reparse() {
        const cache = store.get("cache", null);
        if (cache && cache.forecast) apply(cache);
    }

    function apply(cache) {
        const f = cache.forecast;
        const imperial = unit === "F";
        const T = c => c === null || c === undefined ? NaN : imperial ? c * 9 / 5 + 32 : c;
        const S = k => k === null || k === undefined ? NaN : imperial ? k * 0.621371 : k;
        const D = m => m === null || m === undefined ? NaN : (imperial ? m / 1609.344 : m / 1000);
        const P = mm => mm === null || mm === undefined ? NaN : imperial ? mm / 25.4 : mm;

        place = cache.place;
        location = cache.place.name;
        latitude = cache.place.lat;
        longitude = cache.place.lon;
        lastUpdated = new Date(cache.fetchedAt);

        const shift = (f.utc_offset_seconds || 0) * 1000 + new Date().getTimezoneOffset() * 60000;
        const at = epoch => new Date(epoch * 1000 + shift);
        timeShift = shift;

        const c = f.current;
        current = {
            temp: T(c.temperature_2m),
            feelsLike: T(c.apparent_temperature),
            humidity: c.relative_humidity_2m,
            windSpeed: S(c.wind_speed_10m),
            windDir: c.wind_direction_10m,
            windGusts: S(c.wind_gusts_10m),
            code: c.weather_code,
            isDay: c.is_day === 1,
            description: describe(c.weather_code),
            icon: iconFor(c.weather_code, c.is_day === 1),
            uv: c.uv_index,
            pressure: c.pressure_msl,
            visibility: D(c.visibility),
            precipitation: P(c.precipitation),
            dewPoint: T(c.dew_point_2m),
            cloudCover: c.cloud_cover
        };

        const h = f.hourly;
        const from = Date.now() / 1000 - 3600;
        const hours = [];
        for (let i = 0; i < h.time.length && hours.length < 25; i++) {
            if (h.time[i] < from) continue;
            hours.push({
                time: at(h.time[i]),
                temp: T(h.temperature_2m[i]),
                code: h.weather_code[i],
                isDay: h.is_day[i] === 1,
                icon: iconFor(h.weather_code[i], h.is_day[i] === 1),
                precipProb: h.precipitation_probability[i] ?? 0
            });
        }
        hourly = hours;

        const d = f.daily;
        const days = [];
        for (let i = 0; i < d.time.length; i++) {
            days.push({
                date: at(d.time[i]),
                min: T(d.temperature_2m_min[i]),
                max: T(d.temperature_2m_max[i]),
                code: d.weather_code[i],
                icon: iconFor(d.weather_code[i], true),
                description: describe(d.weather_code[i]),
                sunrise: at(d.sunrise[i]),
                sunset: at(d.sunset[i]),
                precipSum: P(d.precipitation_sum[i]),
                precipProb: d.precipitation_probability_max[i] ?? 0,
                uvMax: d.uv_index_max[i],
                windMax: S(d.wind_speed_10m_max[i])
            });
        }
        daily = days;

        const a = cache.air && cache.air.current;
        air = a ? {
            usAqi: a.us_aqi, europeanAqi: a.european_aqi,
            pm25: a.pm2_5, pm10: a.pm10, ozone: a.ozone, no2: a.nitrogen_dioxide
        } : null;
        aqi = a && a.us_aqi !== null && a.us_aqi !== undefined ? a.us_aqi : null;

        ready = true;
    }

    property bool started: false
    function start() {
        if (started) return;
        started = true;
        const cache = store.get("cache", null);
        if (cache && cache.forecast) {
            try { apply(cache); } catch (e) { console.warn("rice: weather cache unreadable", e); }
        }
        if (!cache || Date.now() - (cache.fetchedAt || 0) > refreshInterval - 30000)
            refresh();
    }

    Component {
        id: requestTimer
        Timer { interval: 10000 }
    }

    JsonStore {
        id: store
        name: "weather"
        onLoadedChanged: {
            if (!loaded) return;
            // The file may arrive after start() already ran (and kicked off a
            // refresh); show the cached forecast meanwhile.
            if (root.started && !root.ready) root.reparse();
            root.start();
        }
    }

    // No cache file yet: FileView never reports `loaded`, so start anyway.
    Timer {
        running: true
        interval: 1200
        onTriggered: root.start()
    }

    Timer {
        running: root.started
        repeat: true
        interval: root.refreshInterval
        onTriggered: root.refresh()
    }

    // Retry sooner after a failure (e.g. network not up yet at login).
    Timer {
        running: root.started && root.error !== "" && !root.loading
        interval: 60 * 1000
        onTriggered: root.refresh()
    }

    Timer {
        id: watchdog
        interval: 45000
        onTriggered: root.fail(root.generation, "Request timed out")
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    IpcHandler {
        target: "weather"
        function refresh(): void { root.refresh(); }
        function setCity(name: string): void { root.setCity(name); }
        function setUnit(unit: string): void { root.setUnit(unit); }
        function toggleUnit(): void { root.toggleUnit(); }
        function summary(): string {
            return root.ready ? `${root.location}: ${root.fmtTemp(root.current.temp)}${root.unit} ${root.current.description}` : root.error || "loading";
        }
    }
}
