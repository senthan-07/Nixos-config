import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components

// Animated sky behind the weather view. Everything is drawn with QML items
// and shapes: gradient sky, sun with turning rays, moon and twinkling stars,
// drifting clouds, rain, snow, fog bands and lightning.
Item {
    id: root

    // "clear" | "partly" | "cloudy" | "fog" | "rain" | "snow" | "storm"
    property string scene: "cloudy"
    property bool night: false
    property bool animate: true
    property real windSpeed: 0          // km/h-ish; only affects the rain slant and cloud speed
    property real moonPhase: 0.5
    // Where the sun / moon sits (centre).
    property real celestialX: width - 96
    property real celestialY: 132

    readonly property bool showSun: !night && (scene === "clear" || scene === "partly")
    readonly property bool showMoon: night && (scene === "clear" || scene === "partly" || scene === "cloudy")
    readonly property bool showStars: night && (scene === "clear" || scene === "partly")
    readonly property int cloudCount: ({ clear: 0, partly: 3, cloudy: 5, fog: 2, rain: 5, snow: 4, storm: 6 })[scene] ?? 3
    readonly property int dropCount: scene === "storm" ? 110 : scene === "rain" ? 80 : 0
    readonly property int flakeCount: scene === "snow" ? 60 : 0
    readonly property real slant: Math.max(-22, Math.min(22, windSpeed * 0.6)) + 6

    readonly property var palettes: ({
        clear_day: ["#2f6fbf", "#8ab9e6"],       clear_night: ["#0b1433", "#2a376d"],
        partly_day: ["#3a73b8", "#9dbde0"],      partly_night: ["#111a38", "#36426f"],
        cloudy_day: ["#56657a", "#9ba8b8"],      cloudy_night: ["#1d2330", "#3b4354"],
        fog_day: ["#6b7683", "#b3bac2"],         fog_night: ["#262b33", "#4b525d"],
        rain_day: ["#3c4a5e", "#728296"],        rain_night: ["#141a26", "#303949"],
        snow_day: ["#5c7494", "#a8bad0"],        snow_night: ["#1b2537", "#45546c"],
        storm_day: ["#2a2f40", "#50566a"],       storm_night: ["#0f111a", "#2b2e3d"]
    })
    readonly property var palette: palettes[scene + (night ? "_night" : "_day")] || palettes.cloudy_day
    // A hint of the wallpaper's primary keeps the sky in tune with the theme.
    readonly property color skyTop: Qt.tint(palette[0], Theme.alpha(Theme.primary, 0.10))
    readonly property color skyBottom: Qt.tint(palette[1], Theme.alpha(Theme.primary, 0.10))
    readonly property color cloudColor: ({
        partly: night ? "#8a93a6" : "#f4f6fa", cloudy: night ? "#6d7689" : "#dde2ea", fog: night ? "#5d6470" : "#e6e9ee",
        rain: night ? "#4a5366" : "#8390a1", snow: night ? "#77839a" : "#dfe5ee", storm: night ? "#363a4b" : "#5d6376"
    })[scene] || "#e8ebf0"

    clip: true

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: root.skyTop; Behavior on color { ColorAnimation { duration: 900 } } }
            GradientStop { position: 0.75; color: root.skyBottom; Behavior on color { ColorAnimation { duration: 900 } } }
        }
    }

    // ---- stars ----
    Item {
        anchors.fill: parent
        opacity: root.showStars ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { duration: 900 } }

        Repeater {
            model: 42
            Rectangle {
                id: star
                readonly property real s: 1 + Math.random() * 2
                x: Math.random() * root.width
                y: Math.random() * 300
                width: s; height: s; radius: s / 2
                color: "white"
                opacity: 0.3
                SequentialAnimation on opacity {
                    running: root.animate && root.showStars
                    loops: Animation.Infinite
                    PauseAnimation { duration: Math.random() * 3000 }
                    NumberAnimation { to: 0.9; duration: 900 + Math.random() * 1400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.2; duration: 900 + Math.random() * 1400; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ---- sun ----
    Item {
        id: sun
        x: root.celestialX - width / 2
        y: root.celestialY - height / 2 + (root.showSun ? 0 : 40)
        width: 180
        height: 180
        opacity: root.showSun ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { duration: 900 } }
        Behavior on y { Anim { duration: 900; easing.bezierCurve: Motion.curve.emphasizedDecel } }

        Shape {
            id: glow
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: 90; centerY: 90; centerRadius: 90
                    focalX: 90; focalY: 90
                    GradientStop { position: 0; color: Qt.rgba(1, 0.93, 0.65, 0.55) }
                    GradientStop { position: 0.45; color: Qt.rgba(1, 0.86, 0.5, 0.18) }
                    GradientStop { position: 1; color: Qt.rgba(1, 0.86, 0.5, 0) }
                }
                PathAngleArc { centerX: 90; centerY: 90; radiusX: 90; radiusY: 90; startAngle: 0; sweepAngle: 360 }
            }
            SequentialAnimation on scale {
                running: root.animate && root.showSun
                loops: Animation.Infinite
                NumberAnimation { to: 1.08; duration: 2600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.94; duration: 2600; easing.type: Easing.InOutSine }
            }
        }

        Item {
            anchors.centerIn: parent
            width: 120
            height: 120
            RotationAnimation on rotation {
                running: root.animate && root.showSun
                loops: Animation.Infinite
                from: 0; to: 360; duration: 40000
            }
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    x: 60 - width / 2
                    y: 2
                    width: 5
                    height: index % 2 ? 12 : 16
                    radius: 2.5
                    color: "#ffe28a"
                    opacity: 0.85
                    transform: Rotation { origin.x: 2.5; origin.y: 58; angle: index * 30 }
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 64
            height: 64
            radius: 32
            gradient: Gradient {
                GradientStop { position: 0; color: "#fff3b0" }
                GradientStop { position: 1; color: "#ffc94a" }
            }
        }
    }

    // ---- moon ----
    Item {
        x: root.celestialX - width / 2
        y: root.celestialY - height / 2 + (root.showMoon ? 0 : 40)
        width: 150
        height: 150
        opacity: root.showMoon ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { duration: 900 } }
        Behavior on y { Anim { duration: 900; easing.bezierCurve: Motion.curve.emphasizedDecel } }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: 75; centerY: 75; centerRadius: 75
                    focalX: 75; focalY: 75
                    GradientStop { position: 0; color: Qt.rgba(0.85, 0.9, 1, 0.28) }
                    GradientStop { position: 1; color: Qt.rgba(0.85, 0.9, 1, 0) }
                }
                PathAngleArc { centerX: 75; centerY: 75; radiusX: 75; radiusY: 75; startAngle: 0; sweepAngle: 360 }
            }
        }

        MoonGlyph {
            anchors.centerIn: parent
            width: 58
            height: 58
            phase: root.moonPhase
            litColor: "#f2f0e6"
            darkColor: Qt.rgba(1, 1, 1, 0.10)
        }
    }

    // ---- clouds ----
    Repeater {
        model: root.cloudCount

        Cloud {
            id: cloud
            required property int index
            readonly property real depth: index / Math.max(1, root.cloudCount - 1)   // 0 = far, 1 = near
            readonly property real offset: (index * 0.37 + 0.13) % 1
            property real t: 0

            width: 150 + depth * 90 + (index % 2) * 30
            height: width * 0.46
            y: 16 + (index * 47) % 120 + depth * 16
            x: ((t + offset) % 1) * (root.width + width) - width
            color: root.cloudColor
            opacity: (root.scene === "partly" ? 0.45 : 0.6) + depth * 0.35
            Behavior on color { ColorAnimation { duration: 900 } }

            NumberAnimation on t {
                running: root.animate
                loops: Animation.Infinite
                from: 0; to: 1
                duration: (90000 - cloud.depth * 40000) / Math.max(1, 1 + root.windSpeed / 30)
            }
        }
    }

    // ---- fog ----
    Repeater {
        model: root.scene === "fog" ? 5 : 0
        Rectangle {
            id: band
            required property int index
            property real t: 0
            width: root.width * 1.6
            height: 46 + (index % 3) * 18
            radius: height / 2
            y: 70 + index * 58
            x: -root.width * 0.3 + Math.sin((t + index * 0.21) * Math.PI * 2) * root.width * 0.3
            color: Qt.rgba(1, 1, 1, 0.10 + (index % 2) * 0.06)
            NumberAnimation on t {
                running: root.animate
                loops: Animation.Infinite
                from: 0; to: 1
                duration: 26000 + band.index * 5000
            }
        }
    }

    // ---- rain ----
    Repeater {
        model: root.dropCount
        Rectangle {
            id: drop
            readonly property real offset: Math.random()
            readonly property real baseX: Math.random() * (root.width + 120) - 60
            readonly property real len: 10 + Math.random() * 12
            property real t: 0
            width: 1.6
            height: len
            radius: 0.8
            color: Qt.rgba(0.85, 0.92, 1, 0.35 + Math.random() * 0.3)
            rotation: root.slant
            readonly property real p: (t + offset) % 1
            y: p * (root.height + 60) - 40
            x: baseX - Math.tan(root.slant * Math.PI / 180) * y
            NumberAnimation on t {
                running: root.animate
                loops: Animation.Infinite
                from: 0; to: 1
                duration: 1500 + Math.random() * 700
            }
        }
    }

    // ---- snow ----
    Repeater {
        model: root.flakeCount
        Rectangle {
            id: flake
            readonly property real offset: Math.random()
            readonly property real baseX: Math.random() * root.width
            readonly property real s: 2 + Math.random() * 4
            property real t: 0
            width: s; height: s; radius: s / 2
            color: "white"
            opacity: 0.5 + s / 12
            readonly property real p: (t + offset) % 1
            y: p * (root.height + 20) - 10
            x: baseX + Math.sin(p * Math.PI * 6 + offset * 10) * 14
            NumberAnimation on t {
                running: root.animate
                loops: Animation.Infinite
                from: 0; to: 1
                duration: 14000 - flake.s * 1200 + Math.random() * 3000
            }
        }
    }

    // ---- lightning ----
    Rectangle {
        id: flash
        anchors.fill: parent
        color: "#e8ecff"
        opacity: 0
    }

    Shape {
        id: bolt
        property real bx: root.width * 0.3
        x: bx
        y: 60
        width: 60
        height: 160
        opacity: 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#fffbe0"
            strokeWidth: 3
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: [Qt.point(30, 0), Qt.point(18, 52), Qt.point(34, 58), Qt.point(14, 112), Qt.point(28, 116), Qt.point(8, 160)] }
        }
    }

    SequentialAnimation {
        id: strike
        ScriptAction { script: bolt.bx = root.width * (0.12 + Math.random() * 0.6) }
        ParallelAnimation {
            NumberAnimation { target: flash; property: "opacity"; to: 0.45; duration: 60 }
            NumberAnimation { target: bolt; property: "opacity"; to: 1; duration: 40 }
        }
        NumberAnimation { target: flash; property: "opacity"; to: 0.08; duration: 90 }
        NumberAnimation { target: flash; property: "opacity"; to: 0.32; duration: 70 }
        ParallelAnimation {
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 500; easing.type: Easing.OutQuad }
            NumberAnimation { target: bolt; property: "opacity"; to: 0; duration: 380; easing.type: Easing.OutQuad }
        }
    }

    Timer {
        running: root.animate && root.scene === "storm"
        repeat: true
        interval: 4200
        onTriggered: {
            interval = 2500 + Math.random() * 5500;
            strike.restart();
        }
    }
}
