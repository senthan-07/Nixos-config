import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Right-click menu for a dock slot. Rows are plain data, so keyboard and
// mouse share one code path:
//   { kind: "header"|"item"|"sep", label, icon, danger, run: function }
DockBubble {
    id: root

    property var rows: []
    property int current: -1
    readonly property real rowHeight: 40
    readonly property var actionable: {
        const out = [];
        for (let i = 0; i < rows.length; i++) if (rows[i].kind === "item") out.push(i);
        return out;
    }

    signal done()

    contentWidth: 264
    contentHeight: {
        let h = 0;
        for (const r of rows) h += r.kind === "sep" ? 9 : r.kind === "header" ? 44 : rowHeight;
        return h;
    }
    width: implicitWidth
    height: implicitHeight
    padding: Tokens.space.xs + 2
    radius: Tokens.radius.l

    onOpenChanged: if (open) { current = -1; Qt.callLater(() => keys.forceActiveFocus()); }

    function step(delta) {
        const a = actionable;
        if (!a.length) return;
        const pos = a.indexOf(current);
        current = a[pos < 0 ? (delta > 0 ? 0 : a.length - 1) : (pos + delta + a.length) % a.length];
    }

    function trigger(i) {
        const r = rows[i];
        if (!r || r.kind !== "item") return;
        root.done();
        if (r.run) r.run();
    }

    Item {
        id: keys
        width: parent.width
        height: col.implicitHeight
        focus: true
        Keys.onUpPressed: root.step(-1)
        Keys.onDownPressed: root.step(1)
        Keys.onTabPressed: root.step(1)
        Keys.onBacktabPressed: root.step(-1)
        Keys.onReturnPressed: root.trigger(root.current)
        Keys.onEnterPressed: root.trigger(root.current)
        Keys.onSpacePressed: root.trigger(root.current)
        Keys.onEscapePressed: root.done()

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 0

            Repeater {
                model: root.rows

                Loader {
                    id: row
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    sourceComponent: modelData.kind === "sep" ? sep : modelData.kind === "header" ? header : item

                    Component {
                        id: sep
                        Item {
                            implicitHeight: 9
                            Separator {
                                anchors.centerIn: parent
                                width: parent.width - Tokens.space.m * 2
                            }
                        }
                    }

                    Component {
                        id: header
                        Item {
                        implicitHeight: 44
                        RowLayout {
                            anchors.fill: parent
                            spacing: Tokens.space.m
                            AppIcon {
                                Layout.leftMargin: Tokens.space.s + 2
                                size: 26
                                name: row.modelData.icon || ""
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.modelData.label
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Tokens.font.l
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: row.modelData.sub || ""
                                    font.pixelSize: Tokens.font.xs
                                    color: Theme.surfaceVariantFg
                                }
                            }
                        }
                        }
                    }

                    Component {
                        id: item
                        Surface {
                            id: entry
                            readonly property bool active: root.current === row.index
                            readonly property bool danger: !!row.modelData.danger
                            implicitHeight: root.rowHeight
                            radius: Tokens.radius.m
                            interactive: true
                            base: active ? (danger ? Theme.errorContainer : Theme.secondaryContainer) : Theme.alpha(Theme.surfaceContainer, 0)
                            content: danger ? (active ? Theme.errorContainerFg : Theme.error) : (active ? Theme.secondaryContainerFg : Theme.surfaceFg)
                            onHoveredChanged: if (hovered) root.current = row.index
                            onClicked: root.trigger(row.index)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.space.m
                                anchors.rightMargin: Tokens.space.m
                                spacing: Tokens.space.m
                                Item {
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    Icon {
                                        anchors.centerIn: parent
                                        visible: !row.modelData.appIcon
                                        text: row.modelData.icon || "radio_button_unchecked"
                                        size: 20
                                        fill: entry.active ? 1 : 0
                                        color: entry.content
                                    }
                                    AppIcon {
                                        anchors.centerIn: parent
                                        visible: !!row.modelData.appIcon
                                        size: 18
                                        name: row.modelData.appIcon || ""
                                    }
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.modelData.label
                                    color: entry.content
                                }
                                StyledText {
                                    visible: text !== ""
                                    text: row.modelData.hint || ""
                                    font.pixelSize: Tokens.font.xs
                                    color: Theme.surfaceVariantFg
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
