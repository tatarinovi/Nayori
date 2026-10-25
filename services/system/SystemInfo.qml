pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool ready: false
    property string osName: ""
    property string kernel: ""
    property string niriVersion: ""
    property string quickshellVersion: ""
    // В репозитории Nayori номер версии не задан.
    readonly property string nayoriVersion: ""
    property string error: ""

    readonly property string summary: {
        if (!ready)
            return "Читаем сведения о системе"
        const parts = []
        if (osName !== "")
            parts.push(osName)
        if (kernel !== "")
            parts.push("ядро " + kernel)
        return parts.length ? parts.join(" · ") : "Сведения о системе не прочитаны"
    }

    function take(text, key) {
        const lines = String(text || "").split("\n")
        const prefix = key + "="
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].indexOf(prefix) === 0)
                return lines[i].slice(prefix.length).trim()
        }
        return ""
    }

    property Process probe: Process {
        command: ["sh", "-c", ". /etc/os-release 2>/dev/null; printf 'OS=%s\\n' \"${PRETTY_NAME:-}\"; printf 'KERNEL=%s\\n' \"$(uname -r 2>/dev/null)\"; printf 'NIRI=%s\\n' \"$(niri --version 2>/dev/null)\"; printf 'QS=%s\\n' \"$(qs --version 2>/dev/null | head -n 1)\""]
        running: true
        stdout: StdioCollector {
            id: output
            waitForEnd: true
        }
        onExited: function(code) {
            const text = output.text || ""
            root.osName = root.take(text, "OS")
            root.kernel = root.take(text, "KERNEL")
            root.niriVersion = root.take(text, "NIRI")
            root.quickshellVersion = root.take(text, "QS")
            root.error = code !== 0 && root.osName === "" ? "Не удалось прочитать сведения о системе" : ""
            root.ready = true
        }
    }
}
