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
        text: "Скорость мыши, ускорение и жесты тачпада в этой сессии задаёт niri. Настройки GNOME сюда не применяются. Nayori их не меняет: безопасная перезапись конфигурации с откатом не сделана"
    
    }
    Label { text: "Мышь"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: niriConfig && niriConfig.mouseText !== "" ? niriConfig.mouseText : "В конфигурации niri нет блока mouse" 
    }
    Label { text: "Тачпад"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: niriConfig && niriConfig.touchpadText !== "" ? niriConfig.touchpadText : "В конфигурации niri нет блока touchpad" 
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: niriConfig && niriConfig.error !== ""
        text: niriConfig ? niriConfig.error : ""
    
    }
}
