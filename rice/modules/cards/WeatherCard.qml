import QtQuick
import qs.config
import qs.components

// Weather card. The body is loaded only when services/Weather.qml exists, so
// this module keeps working without the weather service; `available` lets
// hosts hide the card entirely in that case.
Item {
    id: root

    property bool elevated: true
    property bool running: true
    readonly property bool available: CardStyle.weatherAvailable

    implicitWidth: 368
    implicitHeight: 176

    Loader {
        anchors.fill: parent
        active: root.available
        source: "WeatherBody.qml"
        onLoaded: {
            item.elevated = Qt.binding(() => root.elevated);
            item.running = Qt.binding(() => root.running);
        }
    }
}
