pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Column {
    id: root
    required property var tokens
    property var systemUpdateService: null
    property var updateService: null
    property var settingsService: null
    spacing: 12
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    SettingsCard {
        tokens: root.tokens
        title: "Nayori"
        subtitle: "Обновление оболочки"
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
            objectName: "checkNayoriUpdate"
            text: "Проверить обновления"
            glyph: "update-check"
            iconColor: root.tokens.color.accent
            enabled: root.updateService !== null && root.updateService.installed && !root.updateService.busy
            onClicked: root.updateService.check()
        }
        Action {
            objectName: "installNayoriUpdate"
            text: "Установить обновление"
            glyph: "update-install"
            selected: true
            visible: root.updateService !== null && root.updateService.available
            enabled: root.updateService !== null && !root.updateService.busy
            onClicked: root.updateService.apply()
        }
        Action {
            objectName: "restartNayori"
            text: "Перезапустить оболочку"
            glyph: "update-restart"
            selected: true
            visible: root.updateService !== null && root.updateService.restartNeeded
            enabled: root.updateService !== null && !root.updateService.busy
                && (!root.systemUpdateService || !root.systemUpdateService.busy)
            onClicked: {
                if (root.settingsService) root.settingsService.flush(true)
                root.updateService.restart()
            }
        }
        Label {
            objectName: "restartBlockedReason"
            width: parent.width
            visible: root.updateService !== null && root.updateService.restartNeeded
                && (root.updateService.busy || (!!root.systemUpdateService && root.systemUpdateService.busy))
            text: root.systemUpdateService && root.systemUpdateService.busy
                ? "Дождитесь окончания обновления системы и приложений, затем перезапустите оболочку."
                : "Дождитесь завершения операции с Nayori, затем перезапустите оболочку."
            color: root.tokens.color.textMuted
            font.pixelSize: 13
        }
        Action {
            objectName: "rollbackNayoriUpdate"
            text: "Вернуть предыдущую версию"
            glyph: "update-rollback"
            actionColor: root.tokens.color.secondary
            iconColor: root.tokens.color.secondary
            visible: root.updateService !== null && root.updateService.canRollback
            enabled: root.updateService !== null && !root.updateService.busy
            onClicked: root.updateService.rollback()
        }
    }

    SettingsCard {
        tokens: root.tokens
        title: "Система и приложения"
        subtitle: "Пакеты репозиториев и AUR"
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
        ProgressBar {
            id: systemProgress
            objectName: "systemUpdateProgress"
            width: parent.width
            visible: root.systemUpdateService !== null && root.systemUpdateService.busy && !root.tokens.motion.off
            indeterminate: visible
            Accessible.name: root.systemUpdateService ? root.systemUpdateService.status : "Обновление системы"
            palette.highlight: root.tokens.color.accent
            palette.base: root.tokens.color.surfaceAlt
        }
        Rectangle {
            objectName: "systemUpdateProgressStatic"
            width: parent.width
            height: 6
            radius: height / 2
            visible: root.systemUpdateService !== null && root.systemUpdateService.busy && root.tokens.motion.off
            color: root.tokens.color.surfaceAlt
            Accessible.role: Accessible.ProgressBar
            Accessible.name: root.systemUpdateService ? root.systemUpdateService.status : "Обновление системы"
            Rectangle {
                anchors.centerIn: parent
                width: parent.width / 3
                height: parent.height
                radius: parent.radius
                color: root.tokens.color.accent
            }
        }
        Action {
            objectName: "installSystemUpdates"
            text: "Обновить систему и приложения"
            glyph: "update-install"
            selected: true
            enabled: root.systemUpdateService !== null && root.systemUpdateService.toolsReady && root.systemUpdateService.pacmanFound && root.systemUpdateService.sudoFound && root.systemUpdateService.zenityFound && !root.systemUpdateService.busy
            onClicked: root.systemUpdateService.start()
        }
    }
}
