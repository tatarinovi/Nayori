pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property var themes: []
    property string theme: ""
    property int size: 24
    property bool ready: false
    property bool busy: false
    property string message: ""
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("cursor_theme.py").toString()).replace(/^file:\/\//, "")
    function request(data) {
        if (busy) return
        busy = true
        message = ""
        worker.command = ["python3", root.script, JSON.stringify(data)]
        worker.running = true
    }
    function apply(theme, size) { request({action: "apply", theme: theme, size: size}) }
    function reload() { request({action: "read"}) }
    Component.onCompleted: reload()
    property Process process: Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (!data.ok) {
                        root.message = data.error || "Не удалось применить курсор"
                        return
                    }
                    root.themes = data.themes
                    root.theme = data.theme
                    root.size = data.size
                    root.ready = true
                    root.message = [data.notice || ""].concat(data.warnings || []).filter(Boolean).join("\n")
                } catch (error) {
                    root.message = "Служба курсора вернула повреждённый ответ"
                }
            }
        }
        stderr: StdioCollector {}
        onExited: (code, status) => {
            root.busy = false
            if (code !== 0) root.message = "Не удалось запустить службу курсора"
        }
    }
}
