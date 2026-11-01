pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// A single shell-owned process survives closing the settings window.
QtObject {
    id: root
    property bool pacmanFound: false
    property bool yayFound: false
    property bool sudoFound: false
    property bool zenityFound: false
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("../../scripts/system-update").toString()).replace(/^file:\/\//, "")
    property bool toolsReady: false
    property bool busy: false
    property string status: ""
    property string error: ""
    property string lastError: ""
    property bool sawNoUpdates: false
    property bool sawPackageChanges: false
    readonly property string tool: yayFound ? "yay" : "pacman"

    function start(): bool {
        if (busy || !toolsReady || !pacmanFound || !sudoFound || !zenityFound) return false
        error = ""
        lastError = ""
        sawNoUpdates = false
        sawPackageChanges = false
        status = "Запускаем обновление"
        // The helper retains no password and permits at most one askpass dialog.
        runner.command = [root.script, root.tool]
        busy = true
        runner.running = true
        return true
    }
    function receive(line, isError) {
        const text = String(line || "").trim()
        if (!text) return
        if (text === "NAYORI_UPDATE_PASSWORD_WAIT") {
            status = "Введите пароль в окне подтверждения"
            return
        }
        if (text === "NAYORI_UPDATE_PASSWORD_DONE") {
            status = "Продолжаем обновление"
            return
        }
        if (isError) lastError = text.slice(0, 400)
        const lower = text.toLowerCase()
        if (lower.indexOf("there is nothing to do") >= 0) sawNoUpdates = true
        if (lower.indexOf("installing ") >= 0 || lower.indexOf("upgrading ") >= 0
                || lower.indexOf("making package:") >= 0 || lower.indexOf("building ") >= 0)
            sawPackageChanges = true
        if (lower.indexOf("synchronizing package databases") >= 0) status = "Обновляем базы пакетов"
        else if (lower.indexOf("retrieving packages") >= 0 || lower.indexOf("downloading") >= 0) status = "Загружаем пакеты"
        else if (lower.indexOf("building") >= 0 || lower.indexOf("making package") >= 0) status = "Собираем пакеты AUR"
        else if (lower.indexOf("installing") >= 0 || lower.indexOf("upgrading") >= 0 || lower.indexOf("running post-transaction hooks") >= 0) status = "Устанавливаем пакеты"
        else if (lower.indexOf("checking") >= 0 || lower.indexOf("resolving") >= 0) status = "Проверяем пакеты"
    }
    property Process probe: Process {
        command: ["sh", "-c", "command -v pacman >/dev/null && echo pacman; command -v yay >/dev/null && echo yay; command -v sudo >/dev/null && echo sudo; command -v zenity >/dev/null && echo zenity; true"]
        running: true
        stdout: StdioCollector { id: probeOutput; waitForEnd: true }
        onExited: {
            const found = (probeOutput.text || "").split(/\s+/)
            root.pacmanFound = found.indexOf("pacman") >= 0
            root.yayFound = found.indexOf("yay") >= 0
            root.sudoFound = found.indexOf("sudo") >= 0
            root.zenityFound = found.indexOf("zenity") >= 0
            root.toolsReady = true
        }
    }
    property Process updateRunner: Process {
        id: runner
        stdout: SplitParser { onRead: line => root.receive(line, false) }
        stderr: SplitParser { onRead: line => root.receive(line, true) }
        onExited: code => {
            root.busy = false
            if (code === 0) root.status = root.sawNoUpdates && !root.sawPackageChanges ? "Обновлений нет" : "Обновление завершено"
            else {
                root.status = "Обновление не завершено"
                root.error = (root.lastError || ("Код завершения: " + code)) + ". Если подтверждение истекло или пароль неверный, запустите обновление снова."
            }
        }
    }
}
