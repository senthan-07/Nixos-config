import QtQuick
import qs.config
import qs.components
import qs.services

// Vertical level bars fed by services/Spectrum. Holds a Spectrum reference only
// while `running` (visible and wanted), so cava stops when nothing shows it.
Item {
    id: root

    property int count: 5
    property color color: Theme.primary
    property real barWidth: 3
    property real spacing: 2
    property bool running: visible
    property bool mirrored: true           // bars grow from the middle
    readonly property string token: `island-bars-${count}-${Math.random().toString(36).slice(2, 8)}`

    implicitWidth: count * barWidth + (count - 1) * spacing
    implicitHeight: 18

    onRunningChanged: running ? Spectrum.acquire(token) : Spectrum.release(token)
    Component.onCompleted: if (running) Spectrum.acquire(token)
    Component.onDestruction: Spectrum.release(token)

    // Map `count` bars onto the spectrum, low frequencies in the centre.
    function level(i) {
        const v = Spectrum.values;
        if (!v || !v.length) return 0;
        // Centre-out ordering (bass in the middle): rank 0,1,2... by distance.
        const centre = (count - 1) / 2;
        const rank = Math.round(Math.abs(i - centre) * 2 - (i < centre ? 1 : 0));
        const band = Math.min(v.length - 1, Math.floor(Math.max(0, rank) / count * v.length));
        const end = Math.min(v.length, band + Math.max(1, Math.floor(v.length / count)));
        let m = 0;
        for (let k = band; k < end; k++) m = Math.max(m, v[k]);
        return m;
    }

    Row {
        anchors.centerIn: parent
        spacing: root.spacing

        Repeater {
            model: root.count

            Rectangle {
                required property int index
                readonly property real lv: Spectrum.playing ? root.level(index) : 0
                anchors.verticalCenter: root.mirrored ? parent.verticalCenter : undefined
                y: root.mirrored ? 0 : root.height - height
                width: root.barWidth
                height: Math.max(root.barWidth, root.height * Math.min(1, lv * 1.15))
                radius: width / 2
                color: root.color
                opacity: Spectrum.playing ? 1 : 0.5
                Behavior on height { NumberAnimation { duration: Spectrum.live ? 50 : 90; easing.type: Easing.OutQuad } }
                Behavior on opacity { Anim { duration: Motion.duration.short } }
            }
        }
    }
}
