pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: root
    required property var tokens
    property var niri: null
    spacing: 12
    property var noEntries: []
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Число рабочих столов задаёт niri, и оно здесь не меняется. Можно перейти на уже существующий стол"
    
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: !niri || !niri.available
        text: "Niri сейчас недоступен. Список рабочих столов появится, когда композитор ответит"
    
    }
    Repeater {
        model: niri && niri.available ? niri.workspaces : noEntries
        delegate: Column {
            required property var modelData
            width: parent.width
            spacing: 4
            Label {
                width: parent.width
                text: (modelData.name || ("Стол " + modelData.idx))
                      + (modelData.output ? " · " + modelData.output : "")
                      + (modelData.active ? " · активный" : "")
                      + (modelData.focused ? " · в фокусе" : "")
            }
            Action {
                text: "Перейти"
                onClicked: root.niri.focusWorkspace(modelData.id)
            }
        }
    }
}
