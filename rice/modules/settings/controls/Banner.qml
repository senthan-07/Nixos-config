import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Inline status message. tone: info | error | warning | success.
Rectangle {
    id: root

    property string tone: "info"
    property string icon: tone === "error" ? "error" : tone === "warning" ? "warning" : tone === "success" ? "check_circle" : "info"
    property string text
    property bool busy: false
    default property alias actions: act.data

    readonly property color fg: tone === "error" ? Theme.errorContainerFg
        : tone === "warning" ? Theme.tertiaryContainerFg
        : tone === "success" ? Theme.primaryContainerFg : Theme.secondaryContainerFg

    Layout.fillWidth: true
    implicitHeight: Math.max(52, row.implicitHeight + Tokens.space.m * 2)
    radius: Tokens.radius.m
    color: tone === "error" ? Theme.errorContainer
        : tone === "warning" ? Theme.tertiaryContainer
        : tone === "success" ? Theme.primaryContainer : Theme.secondaryContainer
    Behavior on color { ColorAnim {} }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.l
        anchors.rightMargin: Tokens.space.s
        spacing: Tokens.space.m

        Spinner { visible: root.busy; size: 20; color: root.fg }
        Icon { visible: !root.busy; text: root.icon; size: 20; fill: 1; color: root.fg }
        StyledText {
            Layout.fillWidth: true
            text: root.text
            color: root.fg
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        RowLayout { id: act; spacing: Tokens.space.xs }
    }
}
