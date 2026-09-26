import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Weather tab: animated sky with the current conditions, hourly curve,
// 7-day outlook and a grid of detail cards that reveal as you scroll.
Item {
    id: root

    property bool active: false
    property bool editing: false

    readonly property var c: Weather.current
    readonly property var today: Weather.daily.length ? Weather.daily[0] : null
    readonly property bool hasData: Weather.ready && c !== null
    readonly property color ink: "#f7f9ff"
    readonly property color inkMuted: Qt.rgba(0.95, 0.97, 1, 0.74)

    function statusText() {
        if (Weather.loading) return "Updating…";
        if (Weather.status === "error") return Weather.ready ? "Update failed · showing saved forecast" : "Couldn't load the forecast";
        if (!Weather.lastUpdated) return "Waiting for data";
        const mins = Math.round((Time.now - Weather.lastUpdated) / 60000);
        const ago = mins < 1 ? "just now" : mins < 60 ? `${mins} min ago` : `at ${Weather.formatTime(Weather.lastUpdated)}`;
        return (Weather.status === "stale" ? "Out of date · updated " : "Updated ") + ago;
    }

    function scrollBy(dy) {
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + dy));
    }

    function openEditor() {
        editing = true;
        cityInput.text = Weather.city;
        cityInput.forceActiveFocus();
        cityInput.selectAll();
    }

    function closeEditor() {
        editing = false;
        root.forceActiveFocus();
    }

    onActiveChanged: {
        if (active) {
            flick.contentY = 0;
            // Refresh on open if the data is older than the refresh period.
            if (Weather.lastUpdated && Time.now - Weather.lastUpdated > Weather.refreshInterval && !Weather.loading)
                Weather.refresh();
        } else {
            editing = false;
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Tokens.radius.xl
        color: Theme.surfaceLow

        WeatherSky {
            id: sky
            anchors.fill: parent
            scene: root.hasData ? Weather.sceneFor(root.c.code) : "cloudy"
            night: root.hasData ? !root.c.isDay : false
            windSpeed: root.hasData && Weather.valid(root.c.windSpeed) ? root.c.windSpeed * (Weather.unit === "F" ? 1.609 : 1) : 0
            moonPhase: Weather.moon.phase
            animate: root.active
            celestialY: 150 - Math.min(flick.contentY, 400) * 0.45
        }

        // Settles the sky towards the surface colour as cards scroll over it.
        Rectangle {
            anchors.fill: parent
            color: Theme.surfaceLow
            opacity: Math.min(1, flick.contentY / 280) * 0.72
        }

        // ---- header ----
        ColumnLayout {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.space.l
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.xs
                layer.enabled: true
                layer.effect: InkShadow {}

                Icon {
                    text: Weather.city ? "location_on" : "near_me"
                    size: 18
                    fill: 1
                    color: root.inkMuted
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Weather.location || (Weather.loading ? "Locating…" : "Weather")
                    font.pixelSize: Tokens.font.xl
                    font.weight: Font.Bold
                    color: root.ink
                }

                // °C / °F segmented switch.
                Rectangle {
                    implicitWidth: 76
                    implicitHeight: 30
                    radius: 15
                    color: Qt.rgba(1, 1, 1, 0.16)
                    Rectangle {
                        x: Weather.unit === "C" ? 3 : parent.width / 2
                        y: 3
                        width: parent.width / 2 - 3
                        height: parent.height - 6
                        radius: height / 2
                        color: root.ink
                        Behavior on x { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.emphasizedDecel } }
                    }
                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: ["C", "F"]
                            Item {
                                required property string modelData
                                width: 38
                                height: 30
                                StyledText {
                                    anchors.centerIn: parent
                                    text: "°" + parent.modelData
                                    font.weight: Font.DemiBold
                                    color: Weather.unit === parent.modelData ? "#1b2230" : root.ink
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Weather.setUnit(parent.modelData)
                                }
                            }
                        }
                    }
                }

                SkyButton {
                    icon: "edit_location_alt"
                    active: root.editing
                    onClicked: root.editing ? root.closeEditor() : root.openEditor()
                }
                SkyButton {
                    id: refreshButton
                    icon: "refresh"
                    enabled: !Weather.loading
                    onClicked: Weather.refresh()
                    RotationAnimation on iconRotation {
                        running: Weather.loading
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 900
                        onRunningChanged: if (!running) refreshButton.iconRotation = 0
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.xs
                layer.enabled: true
                layer.effect: InkShadow {}
                Icon {
                    text: Weather.status === "error" || Weather.status === "stale" ? "error" : "schedule"
                    size: 15
                    color: Weather.status === "error" ? "#ffb4ab" : root.inkMuted
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.statusText()
                    font.pixelSize: Tokens.font.s
                    font.weight: Weather.status === "error" ? Font.DemiBold : Font.Normal
                    color: Weather.status === "error" ? root.ink : root.inkMuted
                }
            }

            // City editor; empty = detect from IP.
            Item {
                Layout.fillWidth: true
                Layout.topMargin: root.editing ? Tokens.space.s : 0
                implicitHeight: root.editing ? 44 : 0
                clip: true
                Behavior on implicitHeight { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 22
                    color: Theme.surfaceHighest

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.space.l
                        anchors.rightMargin: Tokens.space.xs
                        spacing: Tokens.space.s

                        Icon { text: "search"; size: 18; color: Theme.primary }
                        TextInput {
                            id: cityInput
                            Layout.fillWidth: true
                            color: Theme.surfaceFg
                            font.family: Tokens.font.sans
                            font.pixelSize: Tokens.font.m
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.primaryFg
                            clip: true
                            StyledText {
                                anchors.fill: parent
                                visible: !parent.text
                                text: "City name — leave empty to auto-detect"
                                color: Theme.surfaceVariantFg
                            }
                            Keys.onReturnPressed: { Weather.setCity(text); root.closeEditor(); }
                            Keys.onEnterPressed: { Weather.setCity(text); root.closeEditor(); }
                            Keys.onEscapePressed: root.closeEditor()
                        }
                        IconButton {
                            size: 34
                            icon: "my_location"
                            iconSize: 18
                            onClicked: { Weather.setCity(""); root.closeEditor(); }
                        }
                        IconButton {
                            size: 34
                            icon: "check"
                            iconSize: 18
                            toggled: true
                            onClicked: { Weather.setCity(cityInput.text); root.closeEditor(); }
                        }
                    }
                }
            }
        }

        // ---- content ----
        Flickable {
            id: flick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.topMargin: Tokens.space.s
            contentWidth: width
            contentHeight: content.implicitHeight + Tokens.space.l
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            interactive: root.hasData

            ColumnLayout {
                id: content
                x: Tokens.space.m
                width: flick.width - Tokens.space.m * 2
                spacing: Tokens.space.m

                // Current conditions.
                Item {
                    id: hero
                    Layout.fillWidth: true
                    implicitHeight: 214
                    visible: root.hasData
                    opacity: root.active ? 1 : 0
                    Behavior on opacity { Anim { duration: Motion.duration.long } }
                    layer.enabled: true
                    layer.effect: InkShadow {}

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Tokens.space.xs
                        anchors.bottomMargin: Tokens.space.s
                        width: parent.width * 0.7
                        spacing: 0

                        RowLayout {
                            spacing: 2
                            StyledText {
                                text: root.hasData ? Math.round(root.c.temp) : "--"
                                font.pixelSize: 92
                                font.weight: Font.Light
                                font.features: { "tnum": 1 }
                                color: root.ink
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 16
                                text: Weather.tempUnit
                                font.pixelSize: 28
                                color: root.inkMuted
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.c?.description ?? ""
                            font.pixelSize: Tokens.font.xxl - 2
                            font.weight: Font.DemiBold
                            color: root.ink
                        }
                        StyledText {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            text: `Feels like ${Weather.fmtTemp(root.c?.feelsLike)}` + (root.today ? `  ·  H ${Weather.fmtTemp(root.today.max)}  L ${Weather.fmtTemp(root.today.min)}` : "")
                            font.pixelSize: Tokens.font.m
                            color: root.inkMuted
                        }
                    }
                }

                // Quick glance pills.
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.hasData
                    spacing: Tokens.space.s
                    GlancePill { icon: "humidity_percentage"; text: `${Weather.fmt(root.c?.humidity)}%` }
                    GlancePill { icon: "air"; text: `${Weather.fmt(root.c?.windSpeed)} ${Weather.speedUnit}` }
                    GlancePill { icon: "umbrella"; text: root.today ? `${Math.round(root.today.precipProb)}%` : "--" }
                    GlancePill { icon: "cloud"; text: `${Weather.fmt(root.c?.cloudCover)}%` }
                }

                HourlyCard {
                    id: hourly
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    visible: root.hasData
                    flick: flick
                    contentTop: y
                    active: root.active
                }

                DailyCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    visible: root.hasData
                    flick: flick
                    contentTop: y
                    active: root.active
                    stagger: 1
                }

                // Two-column grid of square detail cards, laid out by hand
                // (a Grid here fights the ColumnLayout over its width).
                Item {
                    id: grid
                    Layout.fillWidth: true
                    visible: root.hasData
                    readonly property real gap: Tokens.space.m
                    readonly property real cell: (width - gap) / 2
                    implicitHeight: Math.ceil(10 / 2) * (cell + gap) - gap

                    FeelsLikeCard { x: 0 * (grid.cell + grid.gap); y: 0 * (grid.cell + grid.gap); width: grid.cell; height: grid.cell; flick: flick; contentTop: grid.y + y; active: root.active; stagger: 0 }
                    HumidityCard { x: 1 * (grid.cell + grid.gap); y: 0 * (grid.cell + grid.gap); width: grid.cell; height: grid.cell; flick: flick; contentTop: grid.y + y; active: root.active; stagger: 1 }
                    WindCard { x: 0 * (grid.cell + grid.gap); y: 1 * (grid.cell + grid.gap); width: grid.cell; height: grid.cell; flick: flick; contentTop: grid.y + y; active: root.active; stagger: 0 }
                    UvCard { x: 1 * (grid.cell + grid.gap); y: 1 * (grid.cell + grid.gap); width: grid.cell; height: grid.cell; flick: flick; contentTop: grid.y + y; active: root.active; stagger: 1 }
                    PrecipCard { x: 0 * (grid.cell + grid.gap); y: 2 * (grid.cell + grid.gap); width: grid.cell; height: grid.cell; flick: flick; contentTop: grid.y + y; active: root.active; stagger: 0 }
                    AqiCard { x: 1 * (grid.cell + grid.gap); y: 2 * (grid.cell + grid.gap); width: grid.cell; height: grid.cell; flick: flick; contentTop: grid.y + y; active: root.active; stagger: 1 }
                    PressureCard { x: 0 * (grid.cell + grid.gap); y: 3 * (grid.cell + grid.gap); width: grid.cell; height: grid.cell; flick: flick; contentTop: grid.y + y; active: root.active; stagger: 0 }
                    VisibilityCard { x: 1 * (grid.cell + grid.gap); y: 3 * (grid.cell + grid.gap); width: grid.cell; height: grid.cell; flick: flick; contentTop: grid.y + y; active: root.active; stagger: 1 }
                    SunCard { x: 0 * (grid.cell + grid.gap); y: 4 * (grid.cell + grid.gap); width: grid.cell; height: grid.cell; flick: flick; contentTop: grid.y + y; active: root.active; stagger: 0 }
                    MoonCard { x: 1 * (grid.cell + grid.gap); y: 4 * (grid.cell + grid.gap); width: grid.cell; height: grid.cell; flick: flick; contentTop: grid.y + y; active: root.active; stagger: 1 }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.space.xs
                    visible: root.hasData
                    horizontalAlignment: Text.AlignHCenter
                    text: "Weather data by Open-Meteo.com"
                    font.pixelSize: Tokens.font.xs
                    color: Theme.surfaceVariantFg
                }
            }
        }

        // ---- loading / error (no data yet) ----
        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -40
            width: parent.width - Tokens.space.xxl * 2
            visible: !root.hasData
            spacing: Tokens.space.m

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 72
                implicitHeight: 72

                // Spinner while loading.
                Ring {
                    anchors.fill: parent
                    visible: Weather.loading || Weather.status !== "error"
                    thickness: 5
                    value: 0.28
                    color: root.ink
                    track: Qt.rgba(1, 1, 1, 0.18)
                    RotationAnimation on rotation {
                        running: parent.visible && root.active
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 1100
                    }
                }
                Icon {
                    anchors.centerIn: parent
                    text: Weather.loading || Weather.status !== "error" ? "partly_cloudy_day" : "cloud_off"
                    size: Weather.loading || Weather.status !== "error" ? 30 : 56
                    fill: 1
                    color: root.ink
                }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Weather.loading || Weather.status !== "error" ? "Fetching the forecast…" : "Weather unavailable"
                font.pixelSize: Tokens.font.xl
                font.weight: Font.DemiBold
                color: root.ink
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Weather.loading || Weather.status !== "error"
                    ? (Weather.city ? `Looking up ${Weather.city}` : "Detecting your location")
                    : `${Weather.error}. Check your connection or set a city.`
                color: root.inkMuted
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: !Weather.loading && Weather.status === "error"
                spacing: Tokens.space.s
                PillButton { icon: "refresh"; label: "Retry"; primary: true; onClicked: Weather.refresh() }
                PillButton { icon: "edit_location_alt"; label: "Set city"; onClicked: root.openEditor() }
            }
        }
    }

    // Soft shadow that keeps white text legible over bright clouds.
    component InkShadow: MultiEffect {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.45
        shadowBlur: 0.7
        shadowVerticalOffset: 1
        shadowHorizontalOffset: 0
        blurMax: 16
    }

    component SkyButton: Surface {
        id: sb
        property string icon
        property bool active: false
        property real iconRotation: 0
        implicitWidth: 34
        implicitHeight: 34
        radius: 17
        interactive: enabled
        opacity: enabled ? 1 : 0.6
        base: active ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0)
        content: "white"
        Icon {
            anchors.centerIn: parent
            text: sb.icon
            size: 20
            rotation: sb.iconRotation
            color: root.ink
        }
    }

    component GlancePill: Rectangle {
        id: gp
        property string icon
        property string text
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        Row {
            anchors.centerIn: parent
            spacing: Tokens.space.xs
            Icon { anchors.verticalCenter: parent.verticalCenter; text: gp.icon; size: 15; color: root.ink }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: gp.text; font.pixelSize: Tokens.font.s; font.weight: Font.DemiBold; color: root.ink }
        }
    }

    component PillButton: Surface {
        id: pb
        property string icon
        property string label
        property bool primary: false
        implicitWidth: pbRow.implicitWidth + Tokens.space.l * 2
        implicitHeight: 40
        radius: 20
        interactive: true
        base: primary ? root.ink : Qt.rgba(0.05, 0.08, 0.14, 0.28)
        content: primary ? "#1b2230" : "white"
        Row {
            id: pbRow
            anchors.centerIn: parent
            spacing: Tokens.space.s
            Icon { anchors.verticalCenter: parent.verticalCenter; text: pb.icon; size: 18; color: pb.primary ? "#1b2230" : root.ink }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: pb.label; font.weight: Font.DemiBold; color: pb.primary ? "#1b2230" : root.ink }
        }
    }
}
