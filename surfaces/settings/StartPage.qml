pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../panel"

Column {
    id: root
    required property var tokens
    property string startIconStyle: "current"
    signal startIconStyleChangedRequested(string style)
    property string preferredTerminal: "kitty"
    property string preferredFileManager: "io.github.lgse.Strata"
    signal preferredTerminalChangedRequested(string terminalId)
    signal preferredFileManagerChangedRequested(string fileManagerId)
    signal revealRequested(var item)
    spacing: 16

    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    Label { text: "Иконка кнопки Пуск"; font.pixelSize: 18 }
    Label {
        width: parent.width
        text: "Выберите значок для нижней панели. Логотип в настройках от этого не меняется."
        color: root.tokens.color.textMuted
        font.pixelSize: 13
    }
    ButtonGroup { id: iconChoices }
    Repeater {
        model: [{key: "current", label: "Текущая иконка"}, {key: "fox", label: "Логотип Nayori"}]
        RadioButton {
            id: choice
            required property var modelData
            objectName: "startIcon-" + modelData.key
            width: root.width
            padding: 12
            spacing: 12
            ButtonGroup.group: iconChoices
            checked: root.startIconStyle === modelData.key
            onClicked: root.startIconStyleChangedRequested(modelData.key)
            Accessible.name: modelData.label
            focusPolicy: Qt.StrongFocus
            onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
            background: Rectangle {
                color: root.tokens.color.surfaceAlt
                radius: root.tokens.radius.small
                border.width: choice.checked || choice.visualFocus ? 1 : 0
                border.color: root.tokens.color.accent
            }
            indicator: Rectangle {
                x: choice.leftPadding
                y: (choice.height - height) / 2
                width: 20; height: 20; radius: 10
                color: root.tokens.color.background
                border.width: 1
                border.color: choice.checked ? root.tokens.color.accent : root.tokens.color.accentSoft
                Rectangle {
                    anchors.centerIn: parent
                    width: 10; height: 10; radius: 5
                    color: root.tokens.color.accent
                    visible: choice.checked
                }
            }
            contentItem: Item {
                implicitHeight: Math.max(44, caption.implicitHeight)
                NayoriMark {
                    id: preview
                    variant: choice.modelData.key
                    ink: root.tokens.color.accent
                    x: choice.indicator.width + choice.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40
                }
                Label {
                    id: caption
                    anchors { left: preview.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
                    text: choice.modelData.label
                }
            }
        }
    }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: "Кнопка «Пуск» открывает эти приложения. Укажите идентификатор desktop-файла. Пустое поле вернёт значение по умолчанию" 
    }
    Label { text: "Терминал" }
    SettingsField {
        onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
        id: terminalField
        objectName: "preferredTerminalInput"
        tokens: root.tokens
        text: root.preferredTerminal
        placeholderText: "kitty"
        Accessible.name: "Терминал для кнопки Пуск"
    }
    Action {
        onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
        text: "Сохранить терминал"
        selected: true
        onClicked: root.preferredTerminalChangedRequested(terminalField.text.trim())
    }
    Label { text: "Файловый менеджер" }
    SettingsField {
        onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
        id: filesField
        objectName: "preferredFileManagerInput"
        tokens: root.tokens
        text: root.preferredFileManager
        placeholderText: "io.github.lgse.Strata"
        Accessible.name: "Файловый менеджер для кнопки Пуск"
    }
    Action {
        onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
        text: "Сохранить файловый менеджер"
        selected: true
        onClicked: root.preferredFileManagerChangedRequested(filesField.text.trim())
    }
}
