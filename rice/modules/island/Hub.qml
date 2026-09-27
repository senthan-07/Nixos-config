import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Expanded island: tab strip + Media / Focus / Tools pages.
// Keys: Esc close, Tab / Shift+Tab or 1-4 switch tabs; per tab:
//   Media: Space play/pause, ←/→ seek 5 s, Shift+←/→ previous/next
//   Focus: Space pomodoro start/pause, R reset, N skip
//   Tools: ←/→ select, Enter run
FocusScope {
    id: root

    readonly property string tab: IslandState.tab
    readonly property Item page: tab === "media" ? media : tab === "focus" ? focusPage
        : tab === "notifications" ? notifsPage : tools
    readonly property int pad: Tokens.space.l

    implicitWidth: page.implicitWidth + pad * 2
    implicitHeight: tabs.height + Tokens.space.m + page.implicitHeight + pad * 2

    Keys.onPressed: e => {
        const shift = e.modifiers & Qt.ShiftModifier;
        if (e.key === Qt.Key_Escape) IslandState.close();
        else if (e.key === Qt.Key_Tab) IslandState.cycleTab(1);
        else if (e.key === Qt.Key_Backtab) IslandState.cycleTab(-1);
        else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) IslandState.tab = IslandState.tabs[e.key - Qt.Key_1];
        else if (tab === "media" && Media.active) {
            if (e.key === Qt.Key_Space) Media.active.togglePlaying();
            else if (e.key === Qt.Key_Left) shift ? Media.active.previous() : media.seekBy(-5);
            else if (e.key === Qt.Key_Right) shift ? Media.active.next() : media.seekBy(5);
            else return;
        } else if (tab === "focus") {
            if (e.key === Qt.Key_Space) Timers.toggle();
            else if (e.key === Qt.Key_R) Timers.reset();
            else if (e.key === Qt.Key_N) Timers.skip();
            else return;
        } else if (tab === "tools") {
            if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) tools.move(-1);
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) tools.move(1);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) tools.trigger();
            else return;
        } else return;
        e.accepted = true;
    }

    // ---- Tab strip ----
    Rectangle {
        id: tabs
        anchors.top: parent.top
        anchors.topMargin: root.pad
        anchors.horizontalCenter: parent.horizontalCenter
        width: tabRow.implicitWidth + 8
        height: 40
        radius: height / 2
        color: Theme.alpha(Theme.surfaceFg, 0.07)

        // Sliding active indicator
        Rectangle {
            readonly property Item target: tabRow.children[IslandState.tabs.indexOf(root.tab)] ?? null
            x: 4 + (target?.x ?? 0)
            y: 4
            width: target?.width ?? 0
            height: parent.height - 8
            radius: height / 2
            color: Theme.secondaryContainer
            Behavior on x { Anim { easing.bezierCurve: Motion.curve.springDefault } }
            Behavior on width { Anim { easing.bezierCurve: Motion.curve.springDefault } }
        }

        Row {
            id: tabRow
            x: 4
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: [
                    { id: "media", icon: "music_note", label: "Media" },
                    { id: "focus", icon: "avg_pace", label: "Focus" },
                    { id: "tools", icon: "construction", label: "Tools" },
                    { id: "notifications", icon: "notifications", label: "Alerts" }
                ]

                Item {
                    id: tabItem
                    required property var modelData
                    readonly property bool active: root.tab === modelData.id
                    width: tabContent.implicitWidth + Tokens.space.xl
                    height: 32

                    Row {
                        id: tabContent
                        anchors.centerIn: parent
                        spacing: Tokens.space.xs
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabItem.modelData.icon
                            size: 18
                            fill: tabItem.active ? 1 : 0
                            color: tabItem.active ? Theme.secondaryContainerFg : Theme.surfaceVariantFg
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabItem.modelData.label
                            font.weight: tabItem.active ? Font.Bold : Font.Medium
                            color: tabItem.active ? Theme.secondaryContainerFg : Theme.surfaceVariantFg
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tabItem.modelData.id === "notifications" && Notifs.history.length > 0
                            width: Math.max(18, badgeText.implicitWidth + 8)
                            height: 18
                            radius: 9
                            color: Theme.primary
                            StyledText {
                                id: badgeText
                                anchors.centerIn: parent
                                text: Notifs.history.length
                                font.pixelSize: Tokens.font.xs
                                font.weight: Font.Bold
                                color: Theme.primaryFg
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: IslandState.tab = tabItem.modelData.id
                    }
                }
            }
        }
    }

    // Close button
    IconButton {
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.verticalCenter: tabs.verticalCenter
        size: 32
        iconSize: 18
        icon: "close"
        onClicked: IslandState.close()
    }

    // ---- Pages (cross-fade; fixed size so the pill clips during morphs) ----
    Item {
        id: pages
        anchors.top: tabs.bottom
        anchors.topMargin: Tokens.space.m
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.page.implicitWidth
        height: root.page.implicitHeight

        HubMedia { id: media; opacity: root.tab === "media" ? 1 : 0; visible: opacity > 0; anchors.horizontalCenter: parent.horizontalCenter; Behavior on opacity { Anim { duration: Motion.duration.medium } } }
        HubFocus { id: focusPage; opacity: root.tab === "focus" ? 1 : 0; visible: opacity > 0; anchors.horizontalCenter: parent.horizontalCenter; Behavior on opacity { Anim { duration: Motion.duration.medium } } }
        HubNotifications { id: notifsPage; opacity: root.tab === "notifications" ? 1 : 0; visible: opacity > 0; anchors.horizontalCenter: parent.horizontalCenter; Behavior on opacity { Anim { duration: Motion.duration.medium } } }
        HubTools { id: tools; opacity: root.tab === "tools" ? 1 : 0; visible: opacity > 0; anchors.horizontalCenter: parent.horizontalCenter; Behavior on opacity { Anim { duration: Motion.duration.medium } } }
    }
}
