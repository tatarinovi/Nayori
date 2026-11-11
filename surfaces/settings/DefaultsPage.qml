pragma ComponentBehavior: Bound

import QtQuick
import "../../services/system"

Column {
    id: root
    property var settingsService: null
    signal preferredAppsChangedRequested(var patch)
    required property var tokens
    spacing: 16
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    readonly property var kinds: [
        {key: "browser", title: "Браузер", hint: "x-scheme-handler/https"},
        {key: "files", title: "Файловый менеджер", hint: "inode/directory"},
        {key: "terminal", title: "Терминал", hint: "x-scheme-handler/terminal"},
        {key: "mail", title: "Почта", hint: "x-scheme-handler/mailto"},
        {key: "image", title: "Изображения", hint: "image/jpeg"}
    ]

    DefaultApps { id: apps }

    SettingsCard {
        tokens: root.tokens
        title: "Приложения для сочетаний Nayori"
        subtitle: "Эти же терминал и файловый менеджер используются в меню «Пуск». В менеджере сочетаний выберите приложение по умолчанию для нужного бинда или создайте действие Nayori."
        Repeater {
            model: [{key: "preferredTerminal", title: "Терминал"}, {key: "preferredBrowser", title: "Браузер"},
                {key: "preferredFileManager", title: "Файловый менеджер"}, {key: "preferredEditor", title: "Текстовый редактор"},
                {key: "preferredNotes", title: "Заметки"}]
            delegate: Column {
                id: role
                required property var modelData
                width: parent.width
                spacing: 6
                Label { text: role.modelData.title }
                SettingsField {
                    id: preferred
                    tokens: root.tokens
                    text: root.settingsService ? root.settingsService.values[role.modelData.key] : ""
                    placeholderText: "Идентификатор desktop-файла"
                    Accessible.name: role.modelData.title
                }
                Action {
                    text: "Сохранить"
                    enabled: !!root.settingsService && /^[A-Za-z0-9_.-]+$/.test(preferred.text.trim())
                    onClicked: {
                        const patch = {}
                        patch[role.modelData.key] = preferred.text.trim()
                        root.preferredAppsChangedRequested(patch)
                    }
                }
            }
        }
    }


    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: "Запрос и назначение идут через xdg-mime. Идентификатор — имя desktop-файла, например org.gnome.Nautilus" 
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: apps.ready && !apps.available
        text: apps.error || "Команда xdg-mime не найдена"
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: apps.error !== "" && apps.available
        text: apps.error
    }
    Repeater {
        model: root.kinds
        delegate: Column {
            id: kindRow
            required property var modelData
            width: parent.width
            spacing: 8
            Label { text: kindRow.modelData.title; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                 text: "Сейчас: " + ((apps.current && apps.current[kindRow.modelData.key]) || "не назначено") + " · " + kindRow.modelData.hint 
            }
            SettingsField {
                id: field
                tokens: root.tokens
                enabled: apps.available && !apps.busy
                placeholderText: "Идентификатор desktop-файла"
                Accessible.name: kindRow.modelData.title
            }
            Action {
                visible: apps.available
                enabled: !apps.busy && field.text.trim() !== ""
                text: "Назначить"
                onClicked: {
                    if (apps.assign(kindRow.modelData.key, field.text))
                        field.text = ""
                }
            }
        }
    }
}
