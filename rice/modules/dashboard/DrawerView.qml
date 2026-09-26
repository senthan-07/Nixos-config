import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// App drawer: every application in a searchable grid.
//   type to search · arrows move · Enter launches · Esc clears, then closes
Item {
    id: root

    property bool active: false
    signal launched()
    signal dismissed()

    readonly property int columns: 4
    readonly property var apps: search.text.trim() ? Apps.query(search.text) : Apps.entries

    function typeAhead(ch) {
        search.forceActiveFocus();
        search.insert(search.cursorPosition, ch);
    }

    function launch(entry) {
        if (!entry) return;
        Apps.launch(entry);
        root.launched();
    }

    onActiveChanged: {
        if (active) {
            search.text = "";
            grid.currentIndex = 0;
            grid.positionViewAtBeginning();
            search.forceActiveFocus();
            enter.restart();
        }
    }

    ParallelAnimation {
        id: enter
        NumberAnimation { target: grid; property: "opacity"; from: 0; to: 1; duration: Motion.duration.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.standardDecel }
        NumberAnimation { target: grid; property: "anchors.topMargin"; from: Tokens.space.m + 24; to: Tokens.space.m; duration: Motion.duration.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curve.emphasizedDecel }
    }

    Rectangle {
        id: field
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: 52
        radius: height / 2
        color: Theme.surfaceHighest
        border.width: search.activeFocus ? 2 : 0
        border.color: Theme.primary

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.space.l
            anchors.rightMargin: Tokens.space.s
            spacing: Tokens.space.m

            Icon { text: "search"; size: 22; color: Theme.primary }

            TextInput {
                id: search
                Layout.fillWidth: true
                color: Theme.surfaceFg
                font.family: Tokens.font.sans
                font.pixelSize: Tokens.font.l
                selectionColor: Theme.primary
                selectedTextColor: Theme.primaryFg
                clip: true
                onTextChanged: grid.currentIndex = 0

                StyledText {
                    anchors.fill: parent
                    visible: !parent.text
                    text: `Search ${Apps.entries.length} apps`
                    color: Theme.surfaceVariantFg
                    font.pixelSize: parent.font.pixelSize
                }

                Keys.onPressed: event => {
                    const n = root.apps.length;
                    let i = grid.currentIndex;
                    switch (event.key) {
                    case Qt.Key_Escape:
                        if (text) text = "";
                        else { root.dismissed(); DashboardState.close(); }
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.launch(root.apps[i]);
                        break;
                    case Qt.Key_Right: if (!text || cursorPosition === text.length) i = Math.min(n - 1, i + 1); else return; break;
                    case Qt.Key_Left: if (!text || cursorPosition === 0) i = Math.max(0, i - 1); else return; break;
                    case Qt.Key_Down: i = Math.min(n - 1, i + root.columns); break;
                    case Qt.Key_Up: i = Math.max(0, i - root.columns); break;
                    case Qt.Key_PageDown: i = Math.min(n - 1, i + root.columns * 4); break;
                    case Qt.Key_PageUp: i = Math.max(0, i - root.columns * 4); break;
                    default: return;
                    }
                    grid.currentIndex = i;
                    event.accepted = true;
                }
            }

            IconButton {
                visible: search.text !== ""
                size: 34
                icon: "close"
                iconSize: 18
                onClicked: { search.text = ""; search.forceActiveFocus(); }
            }
        }
    }

    GridView {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: field.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Tokens.space.m
        cellWidth: Math.floor(width / root.columns)
        cellHeight: 104
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.apps
        currentIndex: 0
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Motion.duration.short
        keyNavigationEnabled: false

        highlight: Rectangle {
            radius: Tokens.radius.l
            color: Theme.secondaryContainer
            visible: grid.count > 0
        }

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight

            Surface {
                anchors.fill: parent
                anchors.margins: 2
                radius: Tokens.radius.l
                interactive: true
                base: Theme.alpha(Theme.surface, 0)
                content: Theme.surfaceFg
                onClicked: root.launch(cell.modelData)
                onHoveredChanged: if (hovered) grid.currentIndex = cell.index

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.space.s
                    spacing: Tokens.space.xs

                    AppIcon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Tokens.space.xs
                        name: cell.modelData.icon
                        size: 44
                        scale: parent.parent.pressed ? 0.9 : 1
                        Behavior on scale { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.springFast } }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignTop
                        text: cell.modelData.name
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        font.pixelSize: Tokens.font.s
                        color: grid.currentIndex === cell.index ? Theme.secondaryContainerFg : Theme.surfaceFg
                    }
                }
            }
        }

        // Empty state.
        ColumnLayout {
            anchors.centerIn: parent
            visible: grid.count === 0
            spacing: Tokens.space.s
            Icon { Layout.alignment: Qt.AlignHCenter; text: "search_off"; size: 48; color: Theme.surfaceVariantFg }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Apps.entries.length ? `No apps match “${search.text}”` : "No applications found"
                color: Theme.surfaceVariantFg
            }
        }
    }
}
