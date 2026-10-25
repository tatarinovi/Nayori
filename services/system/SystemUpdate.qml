pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Проверка наличия pacman и yay не запускает обновление.
QtObject {
    id: root

    property string terminalId: "kitty"
    property bool pacmanFound: false
    property bool yayFound: false
    property bool toolsReady: false
    property bool busy: false
    property string error: ""
    property string status: ""
    property string pacmanCommand: ""
    property string yayCommand: ""
    property string activeTool: ""

    property var terminalEntry: null

    onTerminalIdChanged: refreshCommands()
    onToolsReadyChanged: refreshCommands()

    property Connections appsWatcher: Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.refreshCommands() }
    }

    function resolveEntry(id) {
        const key = String(id || "").trim()
        if (key === "")
            return null
        let entry = DesktopEntries.byId(key)
        if (!entry && key.indexOf(".desktop") < 0)
            entry = DesktopEntries.byId(key + ".desktop")
        if (!entry)
            entry = DesktopEntries.heuristicLookup(key)
        return entry
    }

    function executableOf(entry) {
        const command = entry && entry.command ? entry.command : []
        for (let i = 0; i < command.length; i++) {
            const part = String(command[i] || "")
            if (part === "" || part === "env")
                continue
            if (part.indexOf("=") >= 0 && part.indexOf("/") < 0)
                continue
            return part
        }
        return ""
    }

    function argvFor(tool) {
        const entry = terminalEntry
        if (!entry)
            return null
        const executable = executableOf(entry)
        if (executable === "")
            return null
        const base = executable.split("/").pop().toLowerCase()
        const id = String(entry.id || terminalId || "").toLowerCase()
        const kitty = base === "kitty" || id.indexOf("kitty") >= 0
        const hold = kitty || base === "alacritty" || base === "konsole" || base === "xterm"
        if (tool === "pacman") {
            if (hold && base === "xterm")
                return [executable, "-hold", "-e", "sudo", "pacman", "-Syu"]
            if (hold)
                return [executable, "--hold", "-e", "sudo", "pacman", "-Syu"]
        } else if (hold && base === "xterm") {
            return [executable, "-hold", "-e", "yay", "-Syu"]
        } else if (hold) {
            return [executable, "--hold", "-e", "yay", "-Syu"]
        }
        const script = tool === "pacman"
                ? "sudo pacman -Syu; status=$?; printf '\\nКод завершения: %s\\nЗакройте терминал, когда закончите.\\n' \"$status\"; read _"
                : "yay -Syu; status=$?; printf '\\nКод завершения: %s\\nЗакройте терминал, когда закончите.\\n' \"$status\"; read _"
        if (base === "gnome-terminal" || base.indexOf("gnome-terminal") >= 0)
            return [executable, "--wait", "--", "bash", "-c", script]
        if (base === "wezterm")
            return [executable, "start", "--", "bash", "-c", script]
        return [executable, "-e", "bash", "-c", script]
    }

    function formatCommand(argv) {
        if (!argv)
            return ""
        return argv.map(function(part) {
            const text = String(part)
            if (text.indexOf(" ") >= 0 || text.indexOf("'") >= 0)
                return "'" + text.replace(/'/g, "'\\''") + "'"
            return text
        }).join(" ")
    }

    function refreshCommands() {
        terminalEntry = resolveEntry(terminalId)
        pacmanCommand = formatCommand(argvFor("pacman"))
        yayCommand = formatCommand(argvFor("yay"))
    }

    function terminalError() {
        const id = String(terminalId || "").trim() || "kitty"
        if (!terminalEntry)
            return "Приложение терминала «" + id + "» не найдено. Обновление не запускалось"
        if (executableOf(terminalEntry) === "")
            return "У приложения «" + id + "» нет команды запуска. Обновление не запускалось"
        return ""
    }

    function launch(tool): bool {
        error = ""
        status = ""
        if (busy) {
            error = "Уже выполняется другое обновление"
            return false
        }
        if (tool !== "pacman" && tool !== "yay")
            return false
        if (!toolsReady) {
            error = "Проверка pacman и yay ещё не завершилась"
            return false
        }
        if (tool === "pacman" && !pacmanFound) {
            error = "pacman не установлен. Обновление не запускалось"
            return false
        }
        if (tool === "yay" && !yayFound) {
            error = "yay не установлен. Обновление не запускалось"
            return false
        }
        const reason = terminalError()
        if (reason !== "") {
            error = reason
            return false
        }
        const argv = argvFor(tool)
        if (!argv) {
            error = terminalError() || "Не удалось собрать команду обновления"
            return false
        }
        activeTool = tool
        busy = true
        runner.command = argv
        runner.running = true
        status = "Обновление запущено в терминале. Пароль спрашивает терминал, не Nayori"
        return true
    }

    function updatePacman(): bool { return launch("pacman") }
    function updateYay(): bool { return launch("yay") }

    property Process toolProbe: Process {
        command: ["sh", "-c", "command -v pacman >/dev/null && echo pacman; command -v yay >/dev/null && echo yay; true"]
        running: true
        stdout: StdioCollector {
            id: toolsOut
            waitForEnd: true
        }
        onExited: {
            const text = toolsOut.text || ""
            root.pacmanFound = text.indexOf("pacman") >= 0
            root.yayFound = text.indexOf("yay") >= 0
            root.toolsReady = true
            root.refreshCommands()
        }
    }

    property Process runner: Process {
        id: runner
        onExited: function(code) {
            root.busy = false
            if (code !== 0)
                root.error = "Терминал закрылся с кодом " + code + ". Смотрите вывод в его окне"
            else
                root.status = "Терминал закрыт"
            root.activeTool = ""
        }
    }

    Component.onCompleted: refreshCommands()
}
