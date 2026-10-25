pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: root
    required property var tokens
    property var niriConfig: null
    spacing: 12
    component Label: SettingsLabel { tokens: root.tokens }

    property var tabBinds: []
    function rebuild() {
        const source = niriConfig && niriConfig.binds ? niriConfig.binds : []
        const next = []
        for (let i = 0; i < source.length; i++) {
            const keys = String(source[i].keys || "")
            if (keys.toLowerCase().indexOf("tab") >= 0)
                next.push(source[i])
        }
        tabBinds = next
    }
    onNiriConfigChanged: rebuild()
    Connections {
        target: root.niriConfig
        function onBindsChanged() { root.rebuild() }
    }
    Component.onCompleted: rebuild()

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Отдельного переключателя Alt+Tab в Nayori нет. Ниже сочетания из конфигурации niri, в которых есть Tab. Изменить их здесь нельзя"
    
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: tabBinds.length === 0
        text: "Сочетаний с Tab в прочитанной конфигурации нет"
    
    }
    Repeater {
        model: root.tabBinds
        delegate: Column {
            required property var modelData
            width: parent.width
            spacing: 2
            Label { width: parent.width; text: modelData.keys }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                 text: modelData.title || modelData.action || "Действие не указано" 
            }
        }
    }
}
