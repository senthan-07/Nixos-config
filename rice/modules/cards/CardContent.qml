import QtQuick

// Instantiates the card for a catalog `type`, filling this item.
//   CardContent { type: "cpu"; running: true }
Loader {
    id: root

    property string type
    property bool running: true
    property bool elevated: true

    readonly property var components: ({
        clock: clock, digital: digital, weather: weather,
        cpu: liquid, memory: liquid, gpu: liquid, temp: liquid,
        cpuTile: tile, memTile: tile, gpuTile: tile,
        network: network, storage: storage, battery: battery,
        calendar: calendar, todo: todo, cava: cava
    })

    sourceComponent: components[type] ?? missing

    Component { id: clock; CookieClock { running: root.running; elevated: root.elevated } }
    Component { id: digital; DigitalClock { elevated: root.elevated } }
    Component { id: weather; WeatherCard { running: root.running; elevated: root.elevated } }
    Component { id: liquid; LiquidMetric { metric: root.type; running: root.running; elevated: root.elevated } }
    Component {
        id: tile
        MetricTile { metric: ({ cpuTile: "cpu", memTile: "memory", gpuTile: "gpu" })[root.type]; running: root.running }
    }
    Component { id: network; NetworkCard { running: root.running; elevated: root.elevated } }
    Component { id: storage; StorageCard { elevated: root.elevated } }
    Component { id: battery; BatteryCard { running: root.running; elevated: root.elevated } }
    Component { id: calendar; CalendarCard { elevated: root.elevated } }
    Component { id: todo; TodoCard { elevated: root.elevated } }
    Component { id: cava; CavaCard { running: root.running; elevated: root.elevated } }
    Component {
        id: missing
        EmptyState { icon: "help"; text: `Unknown card "${root.type}"` }
    }
}
