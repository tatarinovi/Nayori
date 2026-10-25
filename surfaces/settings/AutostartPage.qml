pragma ComponentBehavior: Bound

import QtQuick
import "../../services/system"

Column {
    id: root
    required property var tokens
    spacing: 12
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    AutostartStore { id: store }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: "Системные файлы не удаляются. Чтобы выключить системную запись, Nayori пишет Hidden=true в пользовательский файл с тем же именем" 
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: store.error !== ""
        text: store.error
    }
    Repeater {
        model: store.warnings
        delegate: Label {
            required property var modelData
            width: parent.width
            color: root.tokens.color.secondary
            font.pixelSize: 13
            text: modelData
        }
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: store.ready && store.entries.length === 0
        text: "Записей автозапуска нет"
    
    }
    Repeater {
        model: store.entries
        delegate: Column {
            id: entryRow
            required property var modelData
            width: parent.width
            spacing: 6
            Label { width: parent.width; text: modelData.name || modelData.fileName }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                 visible: modelData.exec !== ""; text: modelData.exec 
            }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                text: modelData.systemFile && modelData.userFile ? "Система, есть пользовательская копия"
                      : modelData.userFile ? "Пользователь" : "Система"
            
            }
            SettingsToggle {
                tokens: root.tokens
                text: "Автозапуск"
                enabled: !store.busy
                checked: entryRow.modelData.enabled
                onClicked: store.setEnabled(entryRow.modelData.fileName, checked)
            }
            Action {
                visible: entryRow.modelData.userFile
                enabled: !store.busy
                text: "Удалить"
                onClicked: store.remove(entryRow.modelData.fileName)
            }
        }
    }
    Label { text: "Новая запись"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label { text: "Имя" }
    SettingsField {
        id: nameField
        tokens: root.tokens
        placeholderText: "Например, Заметки"
        Accessible.name: "Имя записи автозапуска"
    }
    Label { text: "Команда" }
    SettingsField {
        id: commandField
        tokens: root.tokens
        placeholderText: "Например, kitty"
        Accessible.name: "Команда автозапуска"
    }
    Action {
        text: "Добавить"
        enabled: !store.busy && nameField.text.trim() !== "" && commandField.text.trim() !== ""
        selected: true
        onClicked: {
            if (store.add(nameField.text.trim(), commandField.text.trim())) {
                nameField.text = ""
                commandField.text = ""
            }
        }
    }
}
