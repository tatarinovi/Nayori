pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: root
    required property var tokens
    property var niri: null
    property var niriConfig: null
    property bool animationsEnabled: true
    signal animationsRequested()
    signal animationsChangedRequested(bool enabled)
    spacing: 12

    property var noEntries: []
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Nayori умеет перевести фокус на окно. Правила окон, рамки и зазоры задаются в конфигурации niri и отсюда не меняются"
    
    }
    SettingsToggle {
        tokens: root.tokens
        text: "Анимации"
        description: "Движение лисы и переходы интерфейса Nayori"
        checked: root.animationsEnabled
        onClicked: root.animationsChangedRequested(checked)
    }
    Action { text: "Открыть анимации"; onClicked: root.animationsRequested() }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: !niri || !niri.available
        text: "Niri сейчас недоступен. Список окон появится, когда композитор ответит"
    
    }
    Repeater {
        model: niri && niri.available ? niri.windows : noEntries
        delegate: Action {
            required property var modelData
            width: parent.width
            text: "Перейти · " + (modelData.title || modelData.appId || "Окно")
            onClicked: root.niri.focusWindow(modelData.id)
        }
    }
    Label { text: "Макет из конфигурации"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: niriConfig && niriConfig.layoutText !== "" ? niriConfig.layoutText : "Блок layout в конфигурации niri не найден" 
    }
}
