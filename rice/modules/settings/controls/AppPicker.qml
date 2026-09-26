import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Modal application chooser with search (keyboard: type, ↑/↓, Enter, Esc).
QC.Popup {
    id: root

    property string title: "Choose an application"
    property var exclude: []          // desktop ids to grey out
    signal picked(var entry)

    readonly property var results: Apps.query(search.text).slice(0, 80)

    parent: QC.Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(520, (parent?.width ?? 600) - 48)
    height: Math.min(600, (parent?.height ?? 700) - 96)
    modal: true
    focus: true
    padding: Tokens.space.l
    closePolicy: QC.Popup.CloseOnEscape | QC.Popup.CloseOnPressOutside
    onOpened: { search.text = ""; list.currentIndex = 0; search.forceActiveFocus(); }

    QC.Overlay.modal: Rectangle { color: Theme.alpha(Theme.scrim, 0.4) }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.duration.short }
            NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: Motion.duration.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.emphasizedDecel }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.duration.tiny } }

    background: Rectangle { radius: Tokens.radius.xl; color: Theme.surfaceHigh }

    function accept(i) {
        const e = results[i];
        if (!e || exclude.includes(e.id)) return;
        close();
        picked(e);
    }

    contentItem: ColumnLayout {
        spacing: Tokens.space.m

        StyledText {
            Layout.leftMargin: Tokens.space.s
            text: root.title
            font.pixelSize: Tokens.font.xl
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: height / 2
            color: Theme.surfaceHighest
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.space.l
                anchors.rightMargin: Tokens.space.l
                spacing: Tokens.space.m
                Icon { text: "search"; color: Theme.surfaceVariantFg }
                TextInput {
                    id: search
                    Layout.fillWidth: true
                    color: Theme.surfaceFg
                    font.family: Tokens.font.sans
                    font.pixelSize: Tokens.font.l
                    clip: true
                    onTextChanged: list.currentIndex = 0
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed: list.decrementCurrentIndex()
                    onAccepted: root.accept(list.currentIndex)
                    StyledText {
                        anchors.fill: parent
                        visible: !parent.text
                        text: "Search applications"
                        font.pixelSize: Tokens.font.l
                        color: Theme.surfaceVariantFg
                    }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.results
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            QC.ScrollBar.vertical: QC.ScrollBar {}

            delegate: Surface {
                id: item
                required property var modelData
                required property int index
                readonly property bool taken: root.exclude.includes(modelData.id)
                width: ListView.view.width - 12
                implicitHeight: 56
                radius: Tokens.radius.m
                interactive: !taken
                opacity: taken ? 0.45 : 1
                base: ListView.isCurrentItem ? Theme.secondaryContainer : Theme.alpha(Theme.surfaceHigh, 0)
                content: ListView.isCurrentItem ? Theme.secondaryContainerFg : Theme.surfaceFg
                onClicked: root.accept(index)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space.m
                    anchors.rightMargin: Tokens.space.m
                    spacing: Tokens.space.m
                    AppIcon { name: item.modelData.icon; size: 32 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText { Layout.fillWidth: true; text: item.modelData.name; font.weight: Font.Medium; color: item.content }
                        StyledText {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: item.taken ? "Already starts automatically" : (item.modelData.comment || item.modelData.genericName || "")
                            font.pixelSize: Tokens.font.s
                            color: Theme.surfaceVariantFg
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.results.length === 0
            text: "No applications match"
            color: Theme.surfaceVariantFg
        }
    }
}
