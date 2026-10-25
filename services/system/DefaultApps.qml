pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool ready: false
    property bool available: false
    property bool busy: false
    property string error: ""
    property var current: ({
        "browser": "",
        "files": "",
        "terminal": "",
        "mail": "",
        "image": ""
    })

    readonly property var kinds: [
        {key: "browser", mime: "x-scheme-handler/https"},
        {key: "files", mime: "inode/directory"},
        {key: "terminal", mime: "x-scheme-handler/terminal"},
        {key: "mail", mime: "x-scheme-handler/mailto"},
        {key: "image", mime: "image/jpeg"}
    ]

    function mimeFor(key) {
        for (let i = 0; i < kinds.length; i++) {
            if (kinds[i].key === key)
                return kinds[i].mime
        }
        return ""
    }

    function desktopId(value) {
        const text = String(value || "").trim()
        if (!/^[A-Za-z0-9_.-]+$/.test(text))
            return ""
        return text.indexOf(".desktop") === text.length - 8 ? text : text + ".desktop"
    }

    function refresh() {
        if (busy)
            return
        busy = true
        error = ""
        worker.command = ["sh", "-c", "command -v xdg-mime >/dev/null || { echo MISSING; exit 0; }; printf 'browser\\t%s\\n' \"$(xdg-mime query default x-scheme-handler/https 2>/dev/null)\"; printf 'files\\t%s\\n' \"$(xdg-mime query default inode/directory 2>/dev/null)\"; printf 'terminal\\t%s\\n' \"$(xdg-mime query default x-scheme-handler/terminal 2>/dev/null)\"; printf 'mail\\t%s\\n' \"$(xdg-mime query default x-scheme-handler/mailto 2>/dev/null)\"; printf 'image\\t%s\\n' \"$(xdg-mime query default image/jpeg 2>/dev/null)\""]
        worker.running = true
    }

    function assign(key, id): bool {
        if (busy) {
            error = "Уже выполняется другой запрос xdg-mime"
            return false
        }
        if (!available) {
            error = "Команда xdg-mime не найдена. Приложения по умолчанию отсюда не назначаются"
            return false
        }
        const mime = mimeFor(key)
        const desktop = desktopId(id)
        if (mime === "" || desktop === "") {
            error = "Укажите идентификатор desktop-файла без пробелов, например org.gnome.Nautilus"
            return false
        }
        busy = true
        error = ""
        worker.command = ["xdg-mime", "default", desktop, mime]
        worker.pendingRefresh = true
        worker.running = true
        return true
    }

    function applyQuery(text) {
        if (String(text).indexOf("MISSING") >= 0) {
            available = false
            error = "Команда xdg-mime не найдена. Список приложений по умолчанию недоступен"
            return
        }
        available = true
        const next = {
            "browser": "",
            "files": "",
            "terminal": "",
            "mail": "",
            "image": ""
        }
        const lines = String(text || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            const tab = line.indexOf("\t")
            if (tab < 0)
                continue
            const key = line.slice(0, tab)
            if (Object.prototype.hasOwnProperty.call(next, key))
                next[key] = line.slice(tab + 1).trim()
        }
        current = next
    }

    property Process worker: Process {
        id: worker
        property bool pendingRefresh: false
        stdout: StdioCollector {
            id: workerOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: workerErr
            waitForEnd: true
        }
        onExited: function(code) {
            if (worker.pendingRefresh) {
                worker.pendingRefresh = false
                if (code !== 0) {
                    root.busy = false
                    root.ready = true
                    root.error = (workerErr.text || "").trim() || "xdg-mime не смог назначить приложение"
                    return
                }
                root.busy = false
                Qt.callLater(root.refresh)
                return
            }
            root.applyQuery(workerOut.text || "")
            root.ready = true
            root.busy = false
            if (code !== 0 && root.error === "")
                root.error = (workerErr.text || "").trim() || "Не удалось прочитать приложения по умолчанию"
        }
    }

    Component.onCompleted: refresh()
}
