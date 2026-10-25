pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: root
    required property var tokens
    property var niriConfig: null
    spacing: 12
    property var noEntries: []
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Список только для чтения. Изменение сочетаний выключено: безопасная перезапись конфигурации niri с откатом не сделана"
    
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: niriConfig && niriConfig.error !== ""
        text: niriConfig ? niriConfig.error : ""
    
    }
    Action {
        text: "Прочитать снова"
        enabled: niriConfig && !niriConfig.loading
        onClicked: niriConfig.reload()
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: !niriConfig || niriConfig.loading
        text: "Читаем сочетания"
    
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: niriConfig && niriConfig.ready && (!niriConfig.binds || niriConfig.binds.length === 0)
        text: "В конфигурации niri не найдено сочетаний"
    
    }
    Repeater {
        model: niriConfig && niriConfig.binds ? niriConfig.binds : noEntries
        delegate: Column {
            required property var modelData
            width: parent.width
            spacing: 2
            Label { width: parent.width; text: modelData.keys || "Сочетание" }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                text: (modelData.title ? modelData.title : modelData.action || "Действие не указано")
            
            }
        }
    }
}
