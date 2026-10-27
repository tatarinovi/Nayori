pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Обычный компонент. Меню «Пуск» создаёт свой экземпляр.
// Пароли не принимаются и не передаются в аргументы.
QtObject {
    id: root

    signal failed(string action, string message)
    signal started(string action)

    property bool _busy: false
    readonly property bool busy: _busy
    property bool _toolsReady: false
    property bool _probeFailed: false
    property bool _loginctlFound: false
    property bool _systemctlFound: false
    property bool _niriFound: false
    property string _pending: ""
    property bool _sawStart: false

    readonly property string unavailableReason: {
        if (!_toolsReady || _probeFailed && !_loginctlFound && !_systemctlFound && !_niriFound)
            return _toolsReady ? "Не удалось проверить команды сеанса. Повторите действие" : ""
        const parts = []
        if (!_systemctlFound)
            parts.push("systemctl не найден, выключение и перезагрузка недоступны")
        if (!niriReady() && sessionId() === "")
            parts.push("Завершение сеанса недоступно: нет niri и нет идентификатора сеанса")
        return parts.join(". ")
    }

    function sessionId() {
        const value = String(Quickshell.env("XDG_SESSION_ID") || "").trim()
        return /^[A-Za-z0-9_-]+$/.test(value) ? value : ""
    }

    function niriReady() {
        return _niriFound && String(Quickshell.env("NIRI_SOCKET") || "").trim() !== ""
    }

    function lock(): bool {
        return begin("lock", ["qs", "ipc", "-p", Quickshell.shellDir, "call", "lock", "lock"])
    }

    function logout(): bool {
        if (niriReady())
            return begin("logout", ["niri", "msg", "action", "quit", "--skip-confirmation"])
        if (!_niriFound && String(Quickshell.env("NIRI_SOCKET") || "").trim() !== "")
            return reject("logout", "Команда niri не найдена. Завершить сеанс через niri нельзя")
        const id = sessionId()
        if (!_loginctlFound || id === "")
            return reject("logout", "Завершение сеанса недоступно: нет niri и нет идентификатора текущего сеанса")
        return begin("logout", ["loginctl", "terminate-session", id])
    }

    function reboot(): bool {
        if (!_systemctlFound)
            return reject("reboot", "Команда systemctl не найдена. Перезагрузка недоступна")
        return begin("reboot", ["systemctl", "reboot"])
    }

    function powerOff(): bool {
        if (!_systemctlFound)
            return reject("powerOff", "Команда systemctl не найдена. Выключение недоступно")
        return begin("powerOff", ["systemctl", "poweroff"])
    }

    function reject(action, message): bool {
        if (!_toolsReady) {
            failed(action, "Проверка команд ещё не завершилась. Повторите действие")
            return false
        }
        failed(action, message)
        return false
    }

    function begin(action, command): bool {
        if (!_toolsReady)
            return reject(action, "Проверка команд ещё не завершилась. Повторите действие")
        if (_busy) {
            failed(action, "Уже выполняется другое действие с сеансом")
            return false
        }
        _pending = action
        _sawStart = false
        _busy = true
        actionProcess.command = command
        actionProcess.running = true
        return true
    }

    property Process probe: Process {
        command: ["sh", "-c", "command -v loginctl >/dev/null && echo loginctl; command -v systemctl >/dev/null && echo systemctl; command -v niri >/dev/null && echo niri; true"]
        running: true
        stdout: StdioCollector {
            id: probeOut
            waitForEnd: true
        }
        onExited: function(code) {
            const text = probeOut.text || ""
            root._loginctlFound = text.indexOf("loginctl") >= 0
            root._systemctlFound = text.indexOf("systemctl") >= 0
            root._niriFound = /(^|\n)niri(\n|$)/.test(text)
            root._probeFailed = code !== 0
            root._toolsReady = true
        }
    }

    property Process actionProcess: Process {
        id: actionProcess
        onStarted: {
            root._sawStart = true
            root.started(root._pending)
        }
        onExited: function(code) {
            const action = root._pending
            const startedOk = root._sawStart
            root._busy = false
            root._pending = ""
            root._sawStart = false
            if (!action)
                return
            if (!startedOk)
                root.failed(action, "Не удалось запустить команду. Проверьте, что она установлена и доступна")
            else if (code !== 0)
                root.failed(action, "Команда завершилась с кодом " + code)
        }
    }
}
