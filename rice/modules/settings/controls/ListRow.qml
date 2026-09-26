import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Rich list row: leading badge (or AppIcon), title, subtitle, trailing controls and an
// optional expandable area underneath.
//   ListRow { icon: "wifi"; title: "Home"; subtitle: "Connected"; highlighted: true
//             ActionButton { … }                // trailing
//             expansion: [ RowLayout { … } ] }  // shown while `expanded`
Surface {
    id: root

    property string icon
    property string appIcon            // themed icon name; replaces the badge when set
    property string title
    property string subtitle
    property color subtitleColor: Theme.surfaceVariantFg
    property bool highlighted: false
    property bool chevron: false
    property bool expanded: false
    property bool busy: false
    property bool mono: false          // subtitle in monospace (commands, addresses)
    property alias badge: badgeItem
    default property alias trailing: trail.data
    property alias expansion: extra.data

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight
    radius: Tokens.radius.m
    clip: true
    base: highlighted ? Theme.secondaryContainer : Theme.alpha(Theme.surfaceContainer, 0)
    content: highlighted ? Theme.secondaryContainerFg : Theme.surfaceFg
    activeFocusOnTab: interactive
    Accessible.role: Accessible.ListItem
    Accessible.name: title

    Behavior on implicitHeight { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }

    Keys.onPressed: e => {
        if (interactive && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) {
            root.clicked(null);
            e.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
        visible: root.activeFocus
    }

    ColumnLayout {
        id: body
        width: parent.width
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: 60
            Layout.leftMargin: Tokens.space.m
            Layout.rightMargin: Tokens.space.m
            spacing: Tokens.space.m

            Item {
                implicitWidth: 40
                implicitHeight: 40
                visible: root.icon !== "" || root.appIcon !== ""
                IconBadge {
                    id: badgeItem
                    anchors.centerIn: parent
                    visible: root.appIcon === ""
                    icon: root.icon
                    active: root.highlighted
                    tint: root.highlighted ? Theme.primary : Theme.surfaceHighest
                }
                AppIcon {
                    anchors.centerIn: parent
                    visible: root.appIcon !== ""
                    name: root.appIcon
                    size: 32
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.space.s
                Layout.bottomMargin: Tokens.space.s
                spacing: 1
                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Tokens.font.l - 1
                    font.weight: Font.Medium
                    color: root.content
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.subtitle
                    font.pixelSize: Tokens.font.s
                    font.family: root.mono ? Tokens.font.mono : Tokens.font.sans
                    color: root.highlighted ? Theme.alpha(root.content, 0.8) : root.subtitleColor
                    elide: root.mono ? Text.ElideMiddle : Text.ElideRight
                }
            }

            Spinner {
                visible: root.busy
                size: 20
                color: root.highlighted ? root.content : Theme.primary
            }

            RowLayout {
                id: trail
                spacing: Tokens.space.xs
            }

            Icon {
                visible: root.chevron
                text: root.expanded ? "expand_less" : "chevron_right"
                size: 22
                color: Theme.surfaceVariantFg
            }
        }

        ColumnLayout {
            id: extra
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.space.m + 40 + Tokens.space.m
            Layout.rightMargin: Tokens.space.m
            Layout.bottomMargin: visible ? Tokens.space.m : 0
            visible: root.expanded
            opacity: root.expanded ? 1 : 0
            spacing: Tokens.space.s
            Behavior on opacity { Anim { duration: Motion.duration.short } }
        }
    }
}
