pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: root
    required property var tokens
    property var niriConfig: null
    spacing: 16
    component Label: SettingsLabel { tokens: root.tokens }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Раскладка и повтор клавиш читаются из конфигурации niri и из ответа композитора. Изменить их здесь нельзя: безопасная перезапись конфигурации с откатом не сделана. Настройки GNOME в этой сессии niri не применяются"
    
    }
    Label { text: "Конфигурация"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: niriConfig && niriConfig.keyboardText !== "" ? niriConfig.keyboardText : "В конфигурации niri нет блока keyboard" 
    }
    Label { text: "Текущие раскладки"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: niriConfig && niriConfig.layoutsText !== "" ? niriConfig.layoutsText : "Раскладки ещё не прочитаны" 
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: niriConfig && niriConfig.error !== ""
        text: niriConfig ? niriConfig.error : ""
    
    }
}
