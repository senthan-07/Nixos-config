pragma Singleton

import QtQuick
import Quickshell
import qs.components

// Exchange rates from open.er-api.com (free, no key, daily updates),
// cached on disk for 12 hours. Rates are relative to USD.
Singleton {
    id: root

    property var rates: store.get("rates", {})
    property real updated: store.get("updated", 0)       // ms since epoch of the fetch
    property string state: "idle"                         // idle | loading | ready | error
    property string error: ""
    readonly property bool hasRates: Object.keys(rates).length > 0
    readonly property int maxAge: 12 * 3600 * 1000

    // Common codes, so queries are recognised before the first download.
    readonly property var names: ({
        USD: "US dollar", EUR: "Euro", INR: "Indian rupee", GBP: "British pound", JPY: "Japanese yen",
        CNY: "Chinese yuan", AUD: "Australian dollar", CAD: "Canadian dollar", CHF: "Swiss franc",
        SGD: "Singapore dollar", AED: "UAE dirham", SAR: "Saudi riyal", KRW: "South Korean won",
        RUB: "Russian ruble", BRL: "Brazilian real", MXN: "Mexican peso", ZAR: "South African rand",
        HKD: "Hong Kong dollar", NZD: "New Zealand dollar", SEK: "Swedish krona", NOK: "Norwegian krone",
        DKK: "Danish krone", PLN: "Polish złoty", TRY: "Turkish lira", THB: "Thai baht",
        IDR: "Indonesian rupiah", MYR: "Malaysian ringgit", PHP: "Philippine peso", PKR: "Pakistani rupee",
        BDT: "Bangladeshi taka", LKR: "Sri Lankan rupee", NPR: "Nepalese rupee", VND: "Vietnamese đồng",
        EGP: "Egyptian pound", NGN: "Nigerian naira", KWD: "Kuwaiti dinar", QAR: "Qatari riyal",
        OMR: "Omani rial", BHD: "Bahraini dinar", ILS: "Israeli shekel", CZK: "Czech koruna",
        HUF: "Hungarian forint", TWD: "Taiwan dollar", ARS: "Argentine peso", CLP: "Chilean peso",
        COP: "Colombian peso", KES: "Kenyan shilling", UAH: "Ukrainian hryvnia"
    })

    function known(code) {
        return !!names[code] || rates[code] !== undefined;
    }

    property real lastAttempt: 0

    function ensure() {
        if (state === "loading") return;
        // Back off for a minute after a failed download.
        if (state === "error" && Date.now() - lastAttempt < 60000) return;
        if (hasRates && Date.now() - updated < maxAge) {
            state = "ready";
            return;
        }
        fetch();
    }

    function fetch() {
        lastAttempt = Date.now();
        state = "loading";
        error = "";
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            try {
                if (xhr.status !== 200) throw new Error(`HTTP ${xhr.status || "error"}`);
                const json = JSON.parse(xhr.responseText);
                if (json.result !== "success" || !json.rates) throw new Error("bad response");
                store.set("rates", json.rates);
                store.set("updated", Date.now());
                root.state = "ready";
            } catch (e) {
                root.error = String(e.message || e);
                // Stale rates are still better than nothing.
                root.state = hasRates ? "ready" : "error";
            }
        };
        xhr.open("GET", "https://open.er-api.com/v6/latest/USD");
        xhr.send();
    }

    // null when either rate is unknown.
    function convert(amount, from, to) {
        const a = rates[from], b = rates[to];
        if (!a || !b) return null;
        return amount / a * b;
    }

    function ageText() {
        if (!updated) return "";
        const mins = Math.round((Date.now() - updated) / 60000);
        if (mins < 1) return "just now";
        if (mins < 60) return `${mins} min ago`;
        const h = Math.round(mins / 60);
        return h < 48 ? `${h} h ago` : `${Math.round(h / 24)} days ago`;
    }

    JsonStore {
        id: store
        name: "launcher-currency"
    }
}
