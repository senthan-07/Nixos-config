import QtQuick
import QtQuick.Layouts
import qs.modules.settings
import "../controls"
import qs.components
import qs.services
import qs.config

// Night light: warm the screen colour temperature, optionally on a daily schedule.
// Drives services/NightLight.qml (enabled, temperature, scheduled, from, to,
// toggle(), setTemperature(k), setSchedule(on, from, to)).
SettingsPage {
    id: root

    // The service is provided by another module; degrade gracefully when it's absent.
    readonly property var nl: typeof NightLight !== "undefined" ? NightLight : null
    readonly property bool on: nl?.enabled ?? false
    readonly property int kelvin: nl?.temperature ?? 4000
    readonly property bool scheduled: nl?.scheduled ?? false
    readonly property string from: nl?.from ?? "20:00"
    readonly property string to: nl?.to ?? "07:00"

    property real liveKelvin: kelvin      // follows the slider while dragging
    onKelvinChanged: liveKelvin = kelvin

    readonly property var presets: [
        { k: 2700, label: "Candle", icon: "local_fire_department" },
        { k: 3400, label: "Warm", icon: "wb_incandescent" },
        { k: 4500, label: "Soft", icon: "wb_twilight" },
        { k: 5500, label: "Neutral", icon: "wb_sunny" }
    ]

    // Approximate black-body colour (Tanner Helland's fit), for previews only.
    function kelvinColor(k) {
        const t = k / 100;
        let r, g, b;
        if (t <= 66) {
            r = 255;
            g = 99.4708025861 * Math.log(t) - 161.1195681661;
            b = t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
        } else {
            r = 329.698727446 * Math.pow(t - 60, -0.1332047592);
            g = 288.1221695283 * Math.pow(t - 60, -0.0755148492);
            b = 255;
        }
        const c = v => Math.max(0, Math.min(255, v)) / 255;
        return Qt.rgba(c(r), c(g), c(b), 1);
    }
    function minutes(hhmm) {
        const [h, m] = hhmm.split(":").map(Number);
        return (h || 0) * 60 + (m || 0);
    }
    function nowMinutes() {
        const d = new Date();
        return d.getHours() * 60 + d.getMinutes();
    }
    function inWindow(t) {
        const a = minutes(from), b = minutes(to);
        return a <= b ? t >= a && t < b : t >= a || t < b;
    }
    function duration() {
        const a = minutes(from), b = minutes(to);
        const d = (b - a + 1440) % 1440;
        return `${Math.floor(d / 60)} h${d % 60 ? ` ${d % 60} min` : ""}`;
    }
    property int now: nowMinutes()

    title: "Night light"
    subtitle: "Reduce blue light in the evening to make the screen easier on your eyes"

    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = root.nowMinutes() }

    EmptyState {
        visible: !root.nl
        icon: "nightlight"
        title: "Night light service not available"
        text: "The NightLight service isn't loaded in this build of rice."
    }

    // ---- hero ----
    Rectangle {
        id: hero
        visible: root.nl !== null
        Layout.fillWidth: true
        implicitHeight: 200
        radius: Tokens.radius.xl
        clip: true
        color: Theme.surfaceContainer

        // warm wash that follows the temperature
        Rectangle {
            anchors.fill: parent
            opacity: root.on ? 1 : 0
            Behavior on opacity { Anim { duration: Motion.duration.long } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.alpha(root.kelvinColor(root.liveKelvin), 0.35) }
                GradientStop { position: 1; color: Theme.alpha(root.kelvinColor(root.liveKelvin), 0.08) }
            }
        }
        // soft moon/sun glow
        Rectangle {
            x: parent.width - width * 0.75
            y: -height * 0.3
            width: 280
            height: 280
            radius: 140
            color: root.on ? root.kelvinColor(root.liveKelvin) : Theme.surfaceHighest
            opacity: root.on ? 0.25 : 0.4
            Behavior on color { ColorAnim { duration: Motion.duration.long } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.space.xl
            spacing: Tokens.space.xl

            Rectangle {
                implicitWidth: 88
                implicitHeight: 88
                radius: root.on ? 30 : 44
                color: root.on ? root.kelvinColor(root.liveKelvin) : Theme.surfaceHighest
                Behavior on radius { Anim { easing.bezierCurve: Motion.curve.springDefault } }
                Behavior on color { ColorAnim {} }
                Icon {
                    anchors.centerIn: parent
                    text: root.on ? "nightlight" : "light_mode"
                    size: 44
                    fill: 1
                    color: root.on ? "#3a2000" : Theme.surfaceVariantFg
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.xs
                StyledText {
                    text: !root.on ? "Night light is off" : root.scheduled && !root.inWindow(root.now) ? "Night light is scheduled" : "Night light is on"
                    font.pixelSize: Tokens.font.xxl + 4
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.scheduled
                        ? (root.inWindow(root.now) ? `Scheduled · on until ${root.to}` : `Scheduled · turns on at ${root.from}`)
                        : root.on ? `${Math.round(root.liveKelvin)} K · until you turn it off` : "Turn on now or set a schedule"
                    color: Theme.surfaceVariantFg
                }
            }
            SettingsSwitch {
                checked: root.on
                onToggled: root.nl.toggle()
            }
        }
    }

    // ---- temperature ----
    SettingsSection {
        title: "Colour temperature"
        visible: root.nl !== null

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Tokens.space.l
            spacing: Tokens.space.l

            LevelSlider {
                label: "Warmth"
                icon: "thermostat"
                from: 2500
                to: 6500
                step: 100
                value: root.kelvin
                format: v => `${Math.round(v)} K`
                gradient: [root.kelvinColor(2500), root.kelvinColor(4000), root.kelvinColor(6500)]
                onMoved: v => root.liveKelvin = v
                onCommitted: v => root.nl.setTemperature(Math.round(v))
            }
            RowLayout {
                Layout.fillWidth: true
                StyledText { text: "Warmer"; font.pixelSize: Tokens.font.s; color: Theme.surfaceVariantFg }
                Item { Layout.fillWidth: true }
                StyledText { text: "Cooler"; font.pixelSize: Tokens.font.s; color: Theme.surfaceVariantFg }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.space.s
                Repeater {
                    model: root.presets
                    Surface {
                        id: chip
                        required property var modelData
                        readonly property bool active: Math.abs(root.kelvin - modelData.k) < 50
                        implicitHeight: 40
                        implicitWidth: chipRow.implicitWidth + Tokens.space.l * 2
                        radius: active ? Tokens.radius.m : height / 2
                        interactive: true
                        base: active ? Theme.secondaryContainer : Theme.surfaceHigh
                        content: active ? Theme.secondaryContainerFg : Theme.surfaceFg
                        onClicked: root.nl.setTemperature(modelData.k)
                        Behavior on radius { Anim { duration: Motion.duration.short } }
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: Tokens.space.s
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14; height: 14; radius: 7
                                color: root.kelvinColor(chip.modelData.k)
                            }
                            StyledText { text: chip.modelData.label; color: chip.content; font.weight: Font.Medium }
                            StyledText { text: `${chip.modelData.k} K`; color: Theme.surfaceVariantFg; font.pixelSize: Tokens.font.s; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }
    }

    // ---- schedule ----
    SettingsSection {
        title: "Schedule"
        visible: root.nl !== null

        SettingsRow {
            icon: "schedule"
            label: "Turn on automatically"
            description: root.scheduled ? `Every day from ${root.from} to ${root.to} (${root.duration()})` : "Only when you turn it on"
            SettingsSwitch {
                checked: root.scheduled
                onToggled: root.nl.setSchedule(!root.scheduled, root.from, root.to)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Tokens.space.l
            visible: root.scheduled
            spacing: Tokens.space.l

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.l
                TimeField {
                    label: "From"
                    value: root.from
                    onEdited: v => root.nl.setSchedule(true, v, root.to)
                }
                Icon { text: "arrow_forward"; color: Theme.surfaceVariantFg }
                TimeField {
                    label: "To"
                    value: root.to
                    onEdited: v => root.nl.setSchedule(true, root.from, v)
                }
                Item { Layout.fillWidth: true }
            }

            // 24 h timeline with the night window shaded and a "now" marker.
            Item {
                id: timeline
                Layout.fillWidth: true
                implicitHeight: 52

                readonly property real a: root.minutes(root.from) / 1440
                readonly property real b: root.minutes(root.to) / 1440

                Rectangle {
                    id: bar
                    width: parent.width
                    height: 24
                    radius: 12
                    color: Theme.surfaceHighest
                    clip: true

                    // window may wrap past midnight → up to two segments
                    Rectangle {
                        x: bar.width * timeline.a
                        width: bar.width * (timeline.a <= timeline.b ? timeline.b - timeline.a : 1 - timeline.a)
                        height: parent.height
                        radius: 12
                        color: root.kelvinColor(root.liveKelvin)
                        opacity: 0.85
                    }
                    Rectangle {
                        visible: timeline.a > timeline.b
                        x: 0
                        width: bar.width * timeline.b
                        height: parent.height
                        radius: 12
                        color: root.kelvinColor(root.liveKelvin)
                        opacity: 0.85
                    }
                }
                Rectangle {
                    x: bar.width * root.now / 1440 - 1
                    y: -4
                    width: 3
                    height: bar.height + 8
                    radius: 1.5
                    color: Theme.primary
                }
                Repeater {
                    model: [0, 6, 12, 18, 24]
                    StyledText {
                        required property int modelData
                        x: Math.min(timeline.width - width, Math.max(0, timeline.width * modelData / 24 - width / 2))
                        y: bar.height + 8
                        text: `${String(modelData % 24).padStart(2, "0")}:00`
                        font.pixelSize: Tokens.font.xs
                        color: Theme.surfaceVariantFg
                    }
                }
            }
        }
    }
}
