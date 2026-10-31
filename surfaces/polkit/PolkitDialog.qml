pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Пароль только на основном мониторе: первый в Quickshell.screens, как у блокировки.
Scope {
    id: root
    required property var tokens
    required property var service
    property bool suspended: false
    readonly property bool open: !suspended && !!service && service.dialogOpen
    onSuspendedChanged: if (suspended && service) service.invalidateInput()

    Variants {
        model: root.open ? Quickshell.screens : []
        PanelWindow {
            id: window
            required property var modelData
            readonly property bool primary: {
                const name = root.service.primaryName
                const screens = Quickshell.screens
                if (name && modelData.name === name) return true
                const named = name && screens.some(screen => screen && screen.name === name)
                return !named && screens.length > 0 && screens[0] === modelData
            }
            screen: modelData
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            focusable: primary
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: primary ? "nayori-polkit" : "nayori-polkit-side"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: root.tokens.color.background
                opacity: window.primary ? 0.55 : 0.4
            }
            MouseArea {
                anchors.fill: parent
                onPressed: event => event.accepted = true
            }
            Loader {
                anchors.centerIn: parent
                active: window.primary
                sourceComponent: primaryCard
                onLoaded: if (item) item.applyGeneration()
            }
            Column {
                visible: !window.primary
                anchors.centerIn: parent
                width: Math.min(420, parent.width - 48)
                spacing: 12
                Text {
                    width: parent.width
                    text: root.service.view && root.service.view.message ? root.service.view.message : "Система просит подтвердить действие"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: root.tokens.color.text
                    font.family: root.tokens.type.body.family
                    font.pixelSize: root.tokens.type.body.size
                    textFormat: Text.PlainText
                }
                Text {
                    width: parent.width
                    text: "Подтверждение на\u00A0основном мониторе"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: root.tokens.color.textMuted
                    font.family: root.tokens.type.body.family
                    font.pixelSize: root.tokens.type.body.size
                    textFormat: Text.PlainText
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
            }
            Component {
                id: primaryCard
                PolkitCard {
                    width: Math.min(440, window.width - 48)
                    tokens: root.tokens
                    service: root.service
                    view: root.service.view
                    primary: true
                    onCancelRequested: root.service.cancelCurrent()
                }
            }
        }
    }
}
