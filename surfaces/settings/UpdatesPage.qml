pragma ComponentBehavior: Bound

import QtQuick
import "../../services/system"

Column {
    id: root
    required property var tokens
    property string preferredTerminal: "kitty"
    property var updateService: null
    spacing: 12
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    SystemUpdate {
        id: updates
        terminalId: root.preferredTerminal
    }

    Label { text: "Nayori"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: !root.updateService ? "Служба обновлений недоступна"
              : root.updateService.busy ? "Проверяем или устанавливаем обновление…"
              : root.updateService.error !== "" ? root.updateService.error
              : !root.updateService.ready ? "Проверяем обновления…"
              : !root.updateService.installed ? "Для запуска из Git-клона обновления отключены"
              : root.updateService.available ? "Доступно обновление: " + root.updateService.latest.slice(0, 8)
              : root.updateService.latest === "" ? "Проверьте обновления"
              : "Установлена последняя версия"
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: root.updateService !== null && root.updateService.message !== ""
        text: root.updateService ? root.updateService.message : ""
    }
    Action {
        text: "Проверить обновления"
        enabled: root.updateService !== null && root.updateService.installed && !root.updateService.busy
        onClicked: root.updateService.check()
    }
    Action {
        text: "Установить обновление"
        selected: true
        visible: root.updateService !== null && root.updateService.available
        enabled: root.updateService !== null && !root.updateService.busy
        onClicked: root.updateService.apply()
    }
    Action {
        text: "Вернуть предыдущую версию"
        visible: root.updateService !== null && root.updateService.canRollback
        enabled: root.updateService !== null && !root.updateService.busy
        onClicked: root.updateService.rollback()
    }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: "Обновление запускается только по кнопке, в терминале. Пароль спрашивает терминал. Nayori его не видит и не сохраняет" 
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: updates.error !== ""
        text: updates.error
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         visible: updates.status !== ""; text: updates.status 
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         visible: !updates.toolsReady; text: "Проверяем pacman и yay" 
    }

    Label { text: "Pacman"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: !updates.toolsReady ? "Команда появится после проверки"
              : !updates.pacmanFound ? "pacman не установлен"
              : updates.terminalError() !== "" ? updates.terminalError()
              : updates.pacmanCommand
    
    }
    Action {
        text: "Обновить через pacman"
        selected: true
        enabled: updates.toolsReady && updates.pacmanFound && updates.terminalError() === "" && !updates.busy
        onClicked: updates.updatePacman()
    }

    Label { text: "Yay"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: !updates.toolsReady ? "Команда появится после проверки"
              : !updates.yayFound ? "yay не установлен. Для обновления системы он не обязателен"
              : updates.terminalError() !== "" ? updates.terminalError()
              : updates.yayCommand
    
    }
    Action {
        text: "Обновить через yay"
        visible: !updates.toolsReady || updates.yayFound
        enabled: updates.toolsReady && updates.yayFound && updates.terminalError() === "" && !updates.busy
        onClicked: updates.updateYay()
    }
}
