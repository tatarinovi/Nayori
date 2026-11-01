pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Popup {
    id: root
    required property var tokens
    property bool pending: false
    property bool busy: false
    property int secondsLeft: 0
    property string error: ""
    signal confirmed()
    signal canceled()

    objectName: "display-confirmation"
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: Math.min(420, Math.max(0, parent.width - 32))
    padding: 24
    modal: true
    focus: true
    visible: pending
    closePolicy: Popup.NoAutoClose
    onOpened: cancelButton.forceActiveFocus()

    background: Rectangle {
        color: root.tokens.material.dense
        radius: root.tokens.radius.medium
        border.color: root.tokens.color.border
        border.width: 1
    }
    contentItem: Column {
        Keys.onEscapePressed: function(event) {
            event.accepted = true
            if (!root.busy) root.canceled()
        }
        spacing: 12
        SettingsLabel {
            width: parent.width
            tokens: root.tokens
            text: "Картинка на месте?"
            font.family: root.tokens.type.display.family
            font.pixelSize: root.tokens.type.display.size + 2
        }
        SettingsLabel {
            width: parent.width
            tokens: root.tokens
            color: root.tokens.color.textMuted
            text: "Если не подтвердить изменения, Nayori вернёт прежние настройки экрана"
        }
        SettingsLabel {
            width: parent.width
            tokens: root.tokens
            text: "Осталось " + root.secondsLeft + " с"
        }
        SettingsLabel {
            width: parent.width
            tokens: root.tokens
            visible: root.error !== ""
            color: root.tokens.color.secondary
            text: root.error
        }
        Row {
            spacing: 8
            SettingsButton {
                objectName: "display-confirm"
                tokens: root.tokens
                text: "Применить"
                primary: true
                enabled: !root.busy
                onClicked: root.confirmed()
            }
            SettingsButton {
                id: cancelButton
                objectName: "display-cancel"
                tokens: root.tokens
                text: "Отменить"
                enabled: !root.busy
                onClicked: root.canceled()
            }
        }
    }
}
