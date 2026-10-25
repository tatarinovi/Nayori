pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: root
    required property var tokens
    property string preferredTerminal: "kitty"
    property string preferredFileManager: "org.gnome.Nautilus"
    signal preferredTerminalChangedRequested(string terminalId)
    signal preferredFileManagerChangedRequested(string fileManagerId)
    spacing: 16

    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: "Кнопка «Пуск» открывает эти приложения. Укажите идентификатор desktop-файла. Пустое поле вернёт значение по умолчанию" 
    }
    Label { text: "Терминал" }
    SettingsField {
        id: terminalField
        objectName: "preferredTerminalInput"
        tokens: root.tokens
        text: root.preferredTerminal
        placeholderText: "kitty"
        Accessible.name: "Терминал для кнопки Пуск"
    }
    Action {
        text: "Сохранить терминал"
        selected: true
        onClicked: root.preferredTerminalChangedRequested(terminalField.text.trim())
    }
    Label { text: "Файловый менеджер" }
    SettingsField {
        id: filesField
        objectName: "preferredFileManagerInput"
        tokens: root.tokens
        text: root.preferredFileManager
        placeholderText: "org.gnome.Nautilus"
        Accessible.name: "Файловый менеджер для кнопки Пуск"
    }
    Action {
        text: "Сохранить файловый менеджер"
        selected: true
        onClicked: root.preferredFileManagerChangedRequested(filesField.text.trim())
    }
}
