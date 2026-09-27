import QtQuick
import QtQuick.Layouts
import qs.modules.settings
import "../widgets"
import qs.components
import qs.services
// qs.config last: its `Settings` singleton must win over modules/settings/Settings.qml.
import qs.config

SettingsPage {
    id: page

    title: "Idle & power"
    subtitle: "What happens when you step away: lock, screen off and suspend."

    // services/Idle.qml is provided by another module; stay usable if it's missing.
    readonly property var idle: typeof Idle !== "undefined" ? Idle : null
    readonly property bool available: idle !== null
    readonly property bool active: available && idle.enabled && !Panels.caffeine

    readonly property int lockAfter: available ? idle.lockAfter : 0
    readonly property int screenOffAfter: available ? idle.screenOffAfter : 0
    readonly property int suspendAfter: available ? idle.suspendAfter : 0

    readonly property var presets: [0, 60, 120, 180, 300, 600, 900, 1200, 1800, 2700, 3600, 7200]

    function fmt(s) {
        if (!s) return "Never";
        if (s < 60) return s + " s";
        if (s < 3600) return Math.round(s / 60) + " min";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return h + " h" + (m ? " " + m + " min" : "");
    }

    function options(current) {
        const list = presets.slice();
        if (current && !list.includes(current)) list.push(current);
        return list.sort((a, b) => (a || Infinity) - (b || Infinity))
            .map(v => ({ value: v, label: fmt(v), icon: v ? "" : "block" }));
    }

    function set(name, value) {
        if (!available) return;
        const setter = idle["set" + name[0].toUpperCase() + name.slice(1)];
        if (typeof setter === "function") setter(value);
        else idle[name] = value;
    }

    // ---- Unavailable -------------------------------------------------------------
    EmptyState {
        visible: !page.available
        icon: "bedtime_off"
        accent: Theme.error
        title: "Idle service unavailable"
        body: "rice couldn't find its idle service (services/Idle.qml), so lock, screen-off and suspend timers can't be changed here."
    }

    // ---- Timeline summary ----------------------------------------------------------
    Rectangle {
        id: summary
        visible: page.available
        Layout.fillWidth: true
        implicitHeight: summaryCol.implicitHeight + Tokens.space.xl * 2
        radius: Tokens.radius.xl
        color: Panels.caffeine ? Theme.tertiaryContainer : page.active ? Theme.primaryContainer : Theme.surfaceHigh
        Behavior on color { ColorAnim {} }

        readonly property color fg: Panels.caffeine ? Theme.tertiaryContainerFg
            : page.active ? Theme.primaryContainerFg : Theme.surfaceVariantFg

        // Timeline scale: the furthest configured step, at least 10 minutes.
        readonly property real span: Math.max(600, page.lockAfter, page.screenOffAfter, page.suspendAfter) * 1.08

        ColumnLayout {
            id: summaryCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.space.xl
            spacing: Tokens.space.l

            RowLayout {
                spacing: Tokens.space.l
                Rectangle {
                    implicitWidth: 52; implicitHeight: 52
                    radius: page.active ? Tokens.radius.l : 26
                    color: Theme.alpha(summary.fg, 0.12)
                    Behavior on radius { Anim {} }
                    Icon {
                        anchors.centerIn: parent
                        text: Panels.caffeine ? "coffee" : page.active ? "bedtime" : "bedtime_off"
                        size: 28
                        fill: 1
                        color: summary.fg
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        Layout.fillWidth: true
                        text: Panels.caffeine ? "Caffeine is on" : page.active ? "Idle actions are on" : "Idle actions are off"
                        color: summary.fg
                        font.pixelSize: Tokens.font.xl
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: summary.fg
                        opacity: 0.85
                        text: {
                            if (Panels.caffeine) return "Your computer stays awake until you turn caffeine off.";
                            if (!page.active) return "Nothing happens automatically while you're away.";
                            const steps = [];
                            if (page.lockAfter) steps.push("locks after " + page.fmt(page.lockAfter));
                            if (page.screenOffAfter) steps.push("turns the screen off after " + page.fmt(page.screenOffAfter));
                            if (page.suspendAfter) steps.push("suspends after " + page.fmt(page.suspendAfter));
                            if (!steps.length) return "All steps are set to never.";
                            const s = steps.join(", ").replace(/, ([^,]*)$/, " and $1");
                            return "When idle, rice " + s + ".";
                        }
                    }
                }
            }

            // Timeline track with one marker per distinct time. Steps at the same
            // time share a marker; nearby markers alternate label rows.
            Item {
                id: timeline
                readonly property var groups: {
                    const steps = [
                        { at: page.lockAfter, icon: "lock", label: "Lock" },
                        { at: page.screenOffAfter, icon: "desktop_access_disabled", label: "Screen off" },
                        { at: page.suspendAfter, icon: "mode_standby", label: "Suspend" }
                    ].filter(st => st.at > 0);
                    const byTime = {};
                    for (const st of steps) {
                        if (!byTime[st.at]) byTime[st.at] = { at: st.at, icons: [], labels: [] };
                        byTime[st.at].icons.push(st.icon);
                        byTime[st.at].labels.push(st.label);
                    }
                    const out = Object.values(byTime).sort((a, b) => a.at - b.at);
                    // Put a label on the second row when it would collide with the previous one.
                    let lastX = -1e9, lastRow = 1;
                    for (const g of out) {
                        const x = track.width * g.at / summary.span;
                        g.row = x - lastX < 150 && lastRow === 0 ? 1 : 0;
                        lastX = x; lastRow = g.row;
                    }
                    return out;
                }

                Layout.fillWidth: true
                implicitHeight: groups.some(g => g.row === 1) ? 60 : 44
                opacity: page.active ? 1 : 0.45
                Behavior on opacity { Anim {} }

                Rectangle {
                    id: track
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: 6
                    height: 6
                    radius: 3
                    color: Theme.alpha(summary.fg, 0.18)
                }

                Repeater {
                    model: timeline.groups

                    Item {
                        id: mark
                        required property var modelData
                        readonly property string text: modelData.labels.join(" + ") + " · " + page.fmt(modelData.at)
                        width: Math.max(84, labelText.implicitWidth + 8)
                        x: Math.min(track.width - width, Math.max(0, track.width * modelData.at / summary.span - width / 2))
                        height: parent.height
                        Behavior on x { Anim { easing.bezierCurve: Motion.curve.emphasizedDecel } }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 0
                            spacing: -4
                            Repeater {
                                model: mark.modelData.icons
                                Rectangle {
                                    required property string modelData
                                    width: 18; height: 18; radius: 9
                                    color: summary.fg
                                    border.width: 1
                                    border.color: summary.color
                                    Icon { anchors.centerIn: parent; text: parent.modelData; size: 12; fill: 1; color: summary.color }
                                }
                            }
                        }
                        StyledText {
                            id: labelText
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: mark.modelData.row === 1 ? 38 : 22
                            text: mark.text
                            color: summary.fg
                            font.pixelSize: Tokens.font.xs
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }

    // ---- Controls --------------------------------------------------------------------
    SettingsSection {
        visible: page.available
        title: "When idle"

        SettingsRow {
            icon: "timer"
            label: "Idle actions"
            description: "Run the steps below after a period without input"
            SettingsSwitch {
                checked: page.available && page.idle.enabled
                onToggled: page.set("enabled", !checked)
            }
        }

        SettingsRow {
            icon: "lock"
            label: "Lock screen"
            description: "Show the lock screen"
            opacity: page.active ? 1 : 0.5
            Dropdown {
                implicitWidth: 170
                enabled: page.active
                model: page.options(page.lockAfter)
                value: page.lockAfter
                onActivated: v => page.set("lockAfter", v)
            }
        }

        SettingsRow {
            icon: "desktop_access_disabled"
            label: "Turn off screen"
            description: page.screenOffAfter && page.lockAfter && page.screenOffAfter < page.lockAfter
                ? "Turns off before locking; the screen will lock while it's dark"
                : "Blank all displays (DPMS)"
            opacity: page.active ? 1 : 0.5
            Dropdown {
                implicitWidth: 170
                enabled: page.active
                model: page.options(page.screenOffAfter)
                value: page.screenOffAfter
                onActivated: v => page.set("screenOffAfter", v)
            }
        }

        SettingsRow {
            icon: "mode_standby"
            label: "Suspend"
            description: "Put the computer to sleep"
            opacity: page.active ? 1 : 0.5
            Dropdown {
                implicitWidth: 170
                enabled: page.active
                model: page.options(page.suspendAfter)
                value: page.suspendAfter
                onActivated: v => page.set("suspendAfter", v)
            }
        }

        // Safety hint: suspending without ever locking.
        Rectangle {
            Layout.fillWidth: true
            visible: page.active && page.suspendAfter > 0 && (page.lockAfter === 0 || page.lockAfter > page.suspendAfter)
            implicitHeight: warn.implicitHeight + Tokens.space.m * 2
            radius: Tokens.radius.m
            color: Theme.errorContainer

            RowLayout {
                id: warn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.space.l
                anchors.rightMargin: Tokens.space.s
                spacing: Tokens.space.m
                Icon { text: "warning"; color: Theme.errorContainerFg }
                StyledText {
                    Layout.fillWidth: true
                    text: "Your computer will suspend before the screen locks, so it wakes up unlocked."
                    color: Theme.errorContainerFg
                    font.pixelSize: Tokens.font.s
                    wrapMode: Text.Wrap
                }
                ActionButton {
                    style: "text"
                    text: "Lock first"
                    onClicked: page.set("lockAfter", Math.max(60, Math.min(300, page.suspendAfter - 60)))
                }
            }
        }
    }

    SettingsSection {
        visible: page.available
        title: "Caffeine"

        SettingsRow {
            icon: "coffee"
            label: "Keep awake"
            description: "Pause every idle action until you turn this off. Also in quick settings."
            SettingsSwitch {
                checked: Panels.caffeine
                onToggled: Panels.caffeine = !Panels.caffeine
            }
        }
    }
}
