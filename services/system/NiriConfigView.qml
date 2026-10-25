pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool ready: false
    property bool loading: false
    property string error: ""
    property var warnings: []
    property var binds: []
    property string mouseText: ""
    property string keyboardText: ""
    property string touchpadText: ""
    property string layoutText: ""
    property string layoutsText: ""
    property bool layoutsAvailable: false

    function scriptPath() {
        return decodeURIComponent(Qt.resolvedUrl("niri_config_view.py").toString()).replace(/^file:\/\//, "")
    }

    function reload() {
        if (loading)
            return
        loading = true
        error = ""
        reader.command = ["python3", scriptPath()]
        reader.running = true
    }

    property Process reader: Process {
        id: reader
        stdout: StdioCollector {
            id: readerOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: readerErr
            waitForEnd: true
        }
        onExited: function(code) {
            root.loading = false
            root.ready = true
            const text = (readerOut.text || "").trim()
            let payload = null
            try {
                payload = text ? JSON.parse(text) : null
            } catch (parseError) {
                payload = null
            }
            if (!payload) {
                root.error = (readerErr.text || "").trim() || "Не удалось прочитать конфигурацию niri"
                return
            }
            root.error = payload.error || ""
            root.warnings = payload.warnings || []
            root.binds = payload.binds || []
            root.mouseText = payload.mouse || ""
            root.keyboardText = payload.keyboard || ""
            root.touchpadText = payload.touchpad || ""
            root.layoutText = payload.layout || ""
            const layouts = payload.layouts || {}
            root.layoutsAvailable = layouts.available === true
            root.layoutsText = layouts.text || ""
            if (code !== 0 && root.error === "")
                root.error = "Чтение конфигурации niri завершилось с ошибкой"
        }
    }

    Component.onCompleted: reload()
}
