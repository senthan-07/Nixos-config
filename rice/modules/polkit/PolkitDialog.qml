import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services
import qs.modules.keyboard

// Polkit authentication dialog (M3 basic dialog on a scrim). Takes exclusive
// keyboard focus while a request is open: Enter authenticates, Esc cancels.
PanelWindow {
    id: root

    readonly property bool open: Polkit.active && !Panels.locked

    screen: Quickshell.screens[0]
    visible: open || card.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "rice-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            field.clear();
            field.revealed = false;
            Qt.callLater(focusField);
        }
    }
    onVisibleChanged: if (visible) Qt.callLater(focusField)

    function focusField() {
        if (root.open) field.input.forceActiveFocus();
    }

    function authenticate() {
        if (Polkit.busy || field.text === "") {
            if (field.text === "") shake.restart();
            return;
        }
        Polkit.submit(field.text);
        field.clear();
    }

    Connections {
        target: Polkit
        function onFailed() {
            shake.restart();
            field.input.forceActiveFocus();
        }
        function onBusyChanged() {
            if (!Polkit.busy && root.open) field.input.forceActiveFocus();
        }
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Theme.alpha(Theme.scrim, 0.5)
        opacity: root.open ? 1 : 0
        Behavior on opacity { Anim { duration: Motion.duration.medium } }

        // Clicking outside does nothing on purpose: a stray click must not cancel.
        MouseArea { anchors.fill: parent }
    }

    Rectangle {
        id: card

        property real shakeX: 0

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: shakeX
        width: 440
        implicitHeight: content.implicitHeight + Tokens.space.xl * 2
        radius: Tokens.radius.xl
        color: Theme.surfaceHigh
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.5)

        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.92
        transformOrigin: Item.Center
        Behavior on opacity { Anim { duration: Motion.duration.short } }
        Behavior on scale { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }
        Behavior on implicitHeight { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.emphasizedDecel } }

        SequentialAnimation {
            id: shake
            Anim { target: card; property: "shakeX"; to: -10; duration: 50; easing.bezierCurve: Motion.curve.standard }
            Anim { target: card; property: "shakeX"; to: 10; duration: 80; easing.bezierCurve: Motion.curve.standard }
            Anim { target: card; property: "shakeX"; to: -6; duration: 70; easing.bezierCurve: Motion.curve.standard }
            Anim { target: card; property: "shakeX"; to: 4; duration: 60; easing.bezierCurve: Motion.curve.standard }
            Anim { target: card; property: "shakeX"; to: 0; duration: 60; easing.bezierCurve: Motion.curve.standard }
        }

        // Swallow clicks so they don't reach the scrim.
        MouseArea { anchors.fill: parent }

        Keys.onEscapePressed: Polkit.cancel()

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.space.xl
            spacing: Tokens.space.l

            // Hero icon with the requesting app's icon as a badge.
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 64
                implicitHeight: 64

                Rectangle {
                    anchors.fill: parent
                    radius: Polkit.failures > 0 ? Tokens.radius.l : width / 2
                    color: Polkit.failures > 0 ? Theme.errorContainer : Theme.secondaryContainer
                    Behavior on radius { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }
                    Behavior on color { ColorAnim {} }

                    Icon {
                        anchors.centerIn: parent
                        text: Polkit.failures > 0 ? "gpp_bad" : "shield_person"
                        size: 32
                        fill: 1
                        color: Polkit.failures > 0 ? Theme.errorContainerFg : Theme.secondaryContainerFg
                    }
                }

                Rectangle {
                    visible: badge.status === Image.Ready
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -4
                    width: 28
                    height: 28
                    radius: 14
                    color: Theme.surfaceHigh

                    IconImage {
                        id: badge
                        anchors.centerIn: parent
                        implicitSize: 22
                        source: Polkit.iconName ? Quickshell.iconPath(Polkit.iconName, true) : ""
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.s

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Authentication required"
                    font.pixelSize: Tokens.font.xxl
                    font.weight: Font.Normal
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Polkit.message
                    color: Theme.surfaceVariantFg
                    font.pixelSize: Tokens.font.m + 1
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    maximumLineCount: 5
                    lineHeight: 1.15
                }
            }

            // Who is authenticating. Click to switch when several users qualify.
            Surface {
                id: identity
                readonly property bool multiple: Polkit.identities.length > 1
                readonly property string name: Polkit.identities[Polkit.identityIndex] || Quickshell.env("USER") || ""

                Layout.alignment: Qt.AlignHCenter
                implicitHeight: 40
                implicitWidth: identityRow.implicitWidth + Tokens.space.s + Tokens.space.l
                radius: height / 2
                base: Theme.surfaceContainer
                interactive: multiple && !Polkit.busy
                onClicked: Polkit.selectIdentity((Polkit.identityIndex + 1) % Polkit.identities.length)

                RowLayout {
                    id: identityRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.space.xs + 2
                    spacing: Tokens.space.s

                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 15
                        color: Theme.primaryContainer
                        StyledText {
                            anchors.centerIn: parent
                            text: identity.name.charAt(0).toUpperCase()
                            color: Theme.primaryContainerFg
                            font.weight: Font.Bold
                        }
                    }

                    StyledText {
                        text: identity.name
                        font.weight: Font.DemiBold
                    }

                    Icon {
                        visible: identity.multiple
                        text: "swap_horiz"
                        size: 18
                        color: Theme.surfaceVariantFg
                    }
                }
            }

            PasswordField {
                id: field
                Layout.fillWidth: true
                label: Polkit.prompt
                secret: !Polkit.echo
                error: Polkit.infoIsError && Polkit.info !== ""
                enabled: !Polkit.busy
                opacity: Polkit.busy ? 0.6 : 1
                Behavior on opacity { Anim { duration: Motion.duration.short } }
                onAccepted: root.authenticate()
                input.onTextChanged: if (input.text !== "" && Polkit.infoIsError) Polkit.info = ""
                Keys.onEscapePressed: Polkit.cancel()
            }

            // Supporting text: PAM/polkit info or error, then Caps Lock warning.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: -Tokens.space.s
                spacing: Tokens.space.xs
                visible: infoText.text !== "" || LockKeys.capsLock

                RowLayout {
                    visible: infoText.text !== ""
                    spacing: Tokens.space.xs
                    Layout.leftMargin: Tokens.space.l
                    Icon {
                        text: Polkit.infoIsError ? "error" : "info"
                        size: 16
                        fill: 1
                        color: infoText.color
                    }
                    StyledText {
                        id: infoText
                        Layout.fillWidth: true
                        text: Polkit.info
                        color: Polkit.infoIsError ? Theme.error : Theme.surfaceVariantFg
                        font.pixelSize: Tokens.font.s
                        wrapMode: Text.Wrap
                    }
                }

                RowLayout {
                    visible: LockKeys.capsLock
                    spacing: Tokens.space.xs
                    Layout.leftMargin: Tokens.space.l
                    Icon {
                        text: "keyboard_capslock"
                        size: 16
                        color: Theme.tertiary
                    }
                    StyledText {
                        text: "Caps Lock is on"
                        color: Theme.tertiary
                        font.pixelSize: Tokens.font.s
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: Polkit.actionId !== ""
                text: Polkit.actionId
                color: Theme.outline
                font.family: Tokens.font.mono
                font.pixelSize: Tokens.font.xs
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.space.xs
                spacing: Tokens.space.s

                Item { Layout.fillWidth: true }

                DialogButton {
                    text: "Cancel"
                    onActivated: Polkit.cancel()
                    KeyNavigation.tab: field.input
                }

                DialogButton {
                    id: authButton
                    text: Polkit.busy ? "Checking" : "Authenticate"
                    icon: "lock_open"
                    filled: true
                    busy: Polkit.busy
                    enabled: field.text !== "" || Polkit.busy
                    onActivated: root.authenticate()
                }
            }
        }
    }
}
