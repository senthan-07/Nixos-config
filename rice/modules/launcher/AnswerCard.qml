import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Hero result for the calculator, unit and currency conversions.
//   answer: { type: calc|unit|currency, label, lhs, lhsUnit, rhs, rhsUnit,
//             detail, state: ready|loading|error, error }
Rectangle {
    id: root

    property var answer: ({})
    property bool selected: false
    property bool copied: false

    readonly property bool conversion: answer.type === "unit" || answer.type === "currency"
    readonly property bool loading: answer.state === "loading"
    readonly property bool failed: answer.state === "error"

    implicitHeight: Spot.answerHeight
    radius: Tokens.radius.l
    color: selected ? Theme.primaryContainer : Theme.alpha(Theme.primaryContainer, 0.55)
    Behavior on color { ColorAnim {} }

    readonly property color fg: Theme.primaryContainerFg

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        spacing: 18

        // Expression / source side
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 2
            StyledText {
                Layout.fillWidth: true
                text: root.answer.label || ""
                font.pixelSize: Tokens.font.s
                font.weight: Font.DemiBold
                color: Theme.alpha(root.fg, 0.75)
            }
            StyledText {
                Layout.fillWidth: true
                text: root.answer.lhs || ""
                textFormat: Text.PlainText
                font.pixelSize: root.conversion ? 30 : Tokens.font.xl
                font.weight: root.conversion ? Font.DemiBold : Font.Normal
                font.family: root.conversion ? Tokens.font.sans : Tokens.font.mono
                color: root.conversion ? root.fg : Theme.alpha(root.fg, 0.85)
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 14
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.conversion
                text: root.answer.lhsUnit || ""
                font.pixelSize: Tokens.font.m
                color: Theme.alpha(root.fg, 0.75)
            }
        }

        // Arrow chip
        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: Theme.alpha(root.fg, 0.1)
            Icon {
                anchors.centerIn: parent
                text: root.conversion ? "arrow_forward" : "equal"
                size: 22
                color: root.fg
            }
        }

        // Result side
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.loading ? "Fetching rates…" : root.failed ? "Unavailable" : (root.copied ? "Copied" : root.answer.detail || "")
                font.pixelSize: Tokens.font.s
                font.weight: Font.DemiBold
                color: root.failed ? Theme.error : Theme.alpha(root.fg, 0.75)
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: resultText.implicitHeight

                StyledText {
                    id: resultText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    horizontalAlignment: Text.AlignRight
                    text: root.loading || root.failed ? "—" : (root.answer.rhs || "")
                    textFormat: Text.PlainText
                    font.pixelSize: 34
                    font.weight: Font.Bold
                    color: root.fg
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 16
                    opacity: root.loading ? 0.4 : 1
                    Behavior on opacity { Anim { duration: Motion.duration.short } }
                }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                visible: text !== ""
                text: root.failed ? (root.answer.error || "") : (root.answer.rhsUnit || "")
                font.pixelSize: Tokens.font.m
                color: Theme.alpha(root.fg, 0.75)
            }
        }
    }
}
