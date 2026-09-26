pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// Search pill with a mode chip and the morphing mode rail.
Item {
    id: root

    property string mode: "apps"
    property var modeInfo: ({})
    property var railModes: []          // [{ id, icon, label }]
    property bool railExpanded: true
    property string placeholder: "Search"
    property bool busy: false
    property real errorFlash: 0

    readonly property alias input: input
    property alias text: input.text

    signal modeClicked(string id)
    signal chipClosed()

    implicitWidth: Spot.searchWidth + Spot.bleed * 2
    implicitHeight: Spot.searchHeight + Spot.bleed * 2

    readonly property int count: railModes.length
    readonly property real expandedWidth: Spot.searchWidth - count * (Spot.railButton + Spot.railGap)

    function flashError() { errorAnim.restart(); }

    SequentialAnimation {
        id: errorAnim
        NumberAnimation { target: root; property: "errorFlash"; to: 1; duration: 90 }
        PauseAnimation { duration: 420 }
        NumberAnimation { target: root; property: "errorFlash"; to: 0; duration: 260 }
    }

    // Rail progress runs linearly; the springs in MorphSurface shape it.
    property real railProgress: railExpanded ? 1 : 0
    // Expanding runs linearly (the springs ease it); collapsing is front-loaded
    // so the buttons start merging back straight away.
    Behavior on railProgress {
        NumberAnimation {
            duration: root.railExpanded ? Spot.railDuration : Spot.railDuration * 0.8
            easing.type: root.railExpanded ? Easing.Linear : Easing.OutQuad
        }
    }

    MorphSurface {
        id: morph
        anchors.fill: parent
        progress: root.railProgress
        mainLeft: Spot.bleed
        collapsedWidth: Spot.searchWidth
        expandedWidth: root.expandedWidth
        shapeHeight: Spot.searchHeight
        diameter: Spot.railButton
        gap: Spot.railGap
        count: root.count
        color: Spot.surface
        shadowColor: Spot.shadow
    }

    // ---------------------------------------------------------------- field
    Item {
        id: field
        x: Spot.bleed
        y: Spot.bleed
        width: morph.mainWidth
        height: Spot.searchHeight
        clip: true

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onPressed: m => { input.forceActiveFocus(); m.accepted = false; }
        }

        Icon {
            id: lead
            x: 22
            anchors.verticalCenter: parent.verticalCenter
            text: root.busy ? "progress_activity" : "search"
            size: 24
            color: Theme.surfaceVariantFg
            RotationAnimator on rotation {
                running: root.busy
                from: 0; to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running) lead.rotation = 0
            }
        }

        // Mode chip ("Files ×"), shown for every mode except the default.
        Rectangle {
            id: chip
            readonly property bool shown: root.mode !== "apps"
            property real reveal: shown ? 1 : 0
            Behavior on reveal { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }

            x: lead.x + lead.width + 12
            anchors.verticalCenter: parent.verticalCenter
            height: 34
            width: (chipRow.implicitWidth + 12 + 30) * reveal
            radius: height / 2
            color: Theme.secondaryContainer
            opacity: Spot.smoothstep(reveal * 1.4)
            visible: reveal > 0.01
            clip: true

            Row {
                id: chipRow
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.modeInfo.icon || "search"
                    size: 18
                    fill: 1
                    color: Theme.secondaryContainerFg
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.modeInfo.label || ""
                    font.pixelSize: Tokens.font.m + 1
                    font.weight: Font.DemiBold
                    color: Theme.secondaryContainerFg
                }
            }

            Surface {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: 13
                interactive: true
                base: Theme.alpha(Theme.secondaryContainer, 0)
                content: Theme.secondaryContainerFg
                onClicked: { root.chipClosed(); input.forceActiveFocus(); }
                Icon {
                    anchors.centerIn: parent
                    text: "close"
                    size: 16
                    color: Theme.secondaryContainerFg
                }
            }
        }

        TextInput {
            id: input
            x: chip.visible ? chip.x + chip.width + 12 : lead.x + lead.width + 14
            width: Math.max(0, parent.width - x - 22)
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.tint(Theme.surfaceFg, Theme.alpha(Theme.error, root.errorFlash))
            selectionColor: Theme.primary
            selectedTextColor: Theme.primaryFg
            font.family: Tokens.font.sans
            font.pixelSize: 20
            selectByMouse: true
            clip: true
            focus: true
            activeFocusOnTab: false

            StyledText {
                anchors.fill: parent
                visible: !input.text && !input.preeditText
                text: root.placeholder
                color: Theme.alpha(Theme.surfaceVariantFg, 0.75)
                font.pixelSize: 20
            }
        }
    }

    // ---------------------------------------------------------------- rail
    Repeater {
        model: root.railModes

        Item {
            id: btn
            required property var modelData
            required property int index
            readonly property real reveal: morph.iconProgress(index)
            readonly property bool active: root.mode === modelData.id

            x: morph.centerX(index) - width / 2
            y: Spot.bleed
            width: Spot.railButton
            height: Spot.railButton
            opacity: reveal
            scale: 0.85 + 0.15 * reveal
            visible: reveal > 0.01

            Rectangle {
                anchors.fill: parent
                anchors.margins: btn.active ? 6 : 4
                radius: width / 2
                color: btn.active ? Theme.secondaryContainer
                    : mouse.containsMouse ? Theme.alpha(Theme.surfaceFg, mouse.pressed ? 0.12 : 0.07) : "transparent"
                Behavior on color { ColorAnim {} }
                Behavior on anchors.margins { Anim { duration: Motion.duration.short } }
            }

            Icon {
                anchors.centerIn: parent
                text: btn.modelData.icon
                size: 24
                fill: btn.active ? 1 : 0
                color: btn.active ? Theme.secondaryContainerFg : Theme.surfaceVariantFg
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                enabled: btn.reveal > 0.5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.modeClicked(btn.modelData.id);
                    input.forceActiveFocus();
                }
            }

            // Tooltip
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 6
                width: tip.implicitWidth + 16
                height: 26
                radius: 8
                color: Theme.inverseSurface
                opacity: mouse.containsMouse ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { Anim { duration: Motion.duration.short } }
                StyledText {
                    id: tip
                    anchors.centerIn: parent
                    text: `${btn.modelData.label}  ·  Ctrl+${btn.index + 1}`
                    font.pixelSize: Tokens.font.s
                    color: Theme.inverseOnSurface
                }
            }
        }
    }
}
