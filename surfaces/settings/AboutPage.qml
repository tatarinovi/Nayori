pragma ComponentBehavior: Bound

import QtQuick
import "../../services/system"

Column {
    id: root
    required property var tokens
    spacing: 12
    component Label: SettingsLabel { tokens: root.tokens }

    SystemInfo { id: info }

    function row(title, value) {
        return value !== "" ? title + ": " + value : title + ": не прочитано"
    }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         visible: !info.ready; text: "Читаем сведения о системе" 
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: info.error !== ""
        text: info.error
    }
    Label { text: "Nayori"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: info.nayoriVersion !== "" ? info.nayoriVersion : "Номер версии Nayori в репозитории не задан" 
    }
    Label { text: "Окружение"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: root.row("Система", info.osName) 
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: root.row("Ядро", info.kernel) 
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: root.row("niri", info.niriVersion) 
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: root.row("Quickshell", info.quickshellVersion) 
    }
}
