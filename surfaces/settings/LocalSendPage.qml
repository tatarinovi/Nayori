pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: root
    required property var tokens
    spacing: 16
    property bool probed: false
    property bool binaryFound: false
    property string error: ""

    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    property var entry: null
    readonly property bool installed: entry !== null || binaryFound

    function resolveEntry() {
        let found = DesktopEntries.byId("localsend")
        if (!found)
            found = DesktopEntries.byId("localsend.desktop")
        if (!found)
            found = DesktopEntries.heuristicLookup("LocalSend")
        entry = found
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.resolveEntry() }
    }
    Component.onCompleted: resolveEntry()

    function openApp() {
        error = ""
        if (entry) {
            try {
                entry.execute()
            } catch (launchError) {
                error = "Не удалось запустить LocalSend"
            }
            return
        }
        if (binaryFound) {
            launcher.command = ["localsend"]
            launcher.startDetached()
            return
        }
        error = "LocalSend не установлен"
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v localsend >/dev/null && echo yes || echo no"]
        running: true
        stdout: StdioCollector {
            id: probeOut
            waitForEnd: true
        }
        onExited: {
            root.binaryFound = (probeOut.text || "").indexOf("yes") >= 0
            root.probed = true
        }
    }
    Process { id: launcher }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         visible: !probed; text: "Проверяем, установлен ли LocalSend" 
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: probed && installed
        text: "Откроется приложение LocalSend. Передача файлов идёт в нём, не в Nayori"
    
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: probed && !installed
        text: "LocalSend не установлен"
    
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: root.error !== ""
        text: root.error
    }
    Action {
        visible: probed && installed
        text: "Открыть LocalSend"
        selected: true
        onClicked: root.openApp()
    }
}
