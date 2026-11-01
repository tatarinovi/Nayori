pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: root
    required property var tokens
    property var systemUpdateService: null
    property var updateService: null
    spacing: 12
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

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

    Label { text: "Система и приложения"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: !root.systemUpdateService ? "Служба обновлений недоступна"
            : !root.systemUpdateService.toolsReady ? "Проверяем доступные команды…"
            : !root.systemUpdateService.pacmanFound ? "pacman не найден"
            : !root.systemUpdateService.sudoFound || !root.systemUpdateService.zenityFound ? "Для подтверждения нужны sudo и zenity"
            : root.systemUpdateService.yayFound ? "Обновятся пакеты репозиториев и AUR через yay."
            : "Обновятся пакеты репозиториев через pacman. yay не найден."
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Ответы по умолчанию принимаются автоматически. Пароль sudo запросит отдельное окно."
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        objectName: "systemUpdateStatus"
        visible: root.systemUpdateService !== null && root.systemUpdateService.status !== ""
        text: root.systemUpdateService ? root.systemUpdateService.status : ""
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: root.systemUpdateService !== null && root.systemUpdateService.error !== ""
        text: root.systemUpdateService ? root.systemUpdateService.error : ""
    }
    Action {
        text: "Обновить систему и приложения"
        selected: true
        enabled: root.systemUpdateService !== null && root.systemUpdateService.toolsReady && root.systemUpdateService.pacmanFound && root.systemUpdateService.sudoFound && root.systemUpdateService.zenityFound && !root.systemUpdateService.busy
        onClicked: root.systemUpdateService.start()
    }
}
