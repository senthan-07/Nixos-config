import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Empty / loading / error placeholder.
//   info: { icon, title, subtitle, loading, error, action, actionLabel }
Item {
    id: root

    property var info: ({})
    signal actionClicked()

    implicitHeight: 220

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 460)
        spacing: 10

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 4
            implicitWidth: 72
            implicitHeight: 72
            radius: root.info.loading ? 36 : 24
            color: root.info.error ? Theme.errorContainer : Theme.surfaceHighest
            Behavior on radius { Anim {} }

            Icon {
                id: glyph
                anchors.centerIn: parent
                text: root.info.loading ? "progress_activity" : (root.info.icon || "search")
                size: 34
                color: root.info.error ? Theme.errorContainerFg : Theme.surfaceVariantFg
                RotationAnimator on rotation {
                    running: !!root.info.loading
                    from: 0; to: 360
                    duration: 900
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) glyph.rotation = 0
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.info.title || ""
            font.pixelSize: Tokens.font.l + 1
            font.weight: Font.DemiBold
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: root.info.subtitle || ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            color: Theme.surfaceVariantFg
            lineHeight: 1.15
        }

        Surface {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            visible: !!root.info.actionLabel
            implicitWidth: actionText.implicitWidth + 32
            implicitHeight: 36
            radius: 18
            interactive: true
            base: Theme.primary
            content: Theme.primaryFg
            onClicked: root.actionClicked()
            StyledText {
                id: actionText
                anchors.centerIn: parent
                text: root.info.actionLabel || ""
                font.weight: Font.DemiBold
                color: Theme.primaryFg
            }
        }
    }
}
