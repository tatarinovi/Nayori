pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"

// Правое меню Пуска. btop запускается в предпочтительном терминале, не через Apps.launch.
PopupWindow {
    id: root

    required property var tokens
    required property var shellState
    required property var panelScreen
    required property Item anchorItem
    property var anchorWindow: null

    property bool opened: false
    property bool blockOpen: false
    property bool grabArmed: false
    property string notice: ""
    property int launchSerial: 0
    property int startedSerial: 0
    property var queuedArgv: null

    readonly property int inset: tokens.spacing.small
    readonly property int menuWidth: 248
    readonly property int lift: Math.round((tokens.panel.height - tokens.panel.control) / 2 + tokens.spacing.small)
    readonly property string terminalId: {
        const raw = shellState.preferredTerminal
        const text = raw === undefined || raw === null ? "" : String(raw).trim()
        return text || "kitty"
    }

    function toggle() {
        if (blockOpen) {
            blockOpen = false
            blockTimer.stop()
            return
        }
        opened = !opened
    }

    function armGrab() {
        armTimer.restart()
    }

    function close() {
        opened = false
    }

    function openSettings() {
        shellState.overlayScreen = panelScreen
        shellState.openSettings("home")
        opened = false
    }

    function commandParts(entry) {
        const parts = []
        const source = entry ? entry.command : null
        if (source && typeof source !== "string" && typeof source.length === "number") {
            for (let i = 0; i < source.length; i++) {
                const value = source[i]
                const part = value === undefined || value === null ? "" : String(value).trim()
                if (part.length > 0)
                    parts.push(part)
            }
        }
        if (parts.length === 0 && entry && entry.execString) {
            const token = String(entry.execString).trim().split(/\s+/)[0]
            if (token)
                parts.push(token)
        }
        if (parts.length > 0 && root.baseName(parts[0]) === "env") {
            let index = 1
            while (index < parts.length && parts[index].indexOf("=") > 0)
                index += 1
            return parts.slice(index)
        }
        return parts
    }

    function baseName(path) {
        const text = String(path)
        const slash = Math.max(text.lastIndexOf("/"), text.lastIndexOf("\\"))
        return slash >= 0 ? text.slice(slash + 1) : text
    }

    function launchTasks() {
        notice = ""
        const entry = apps.lookup(terminalId)
        if (!entry) {
            notice = "Нет ярлыка терминала"
            return
        }
        const argv = commandParts(entry)
        if (!argv.length) {
            notice = "Нет ярлыка терминала"
            return
        }
        argv.push("-e")
        argv.push("btop")
        launchSerial += 1
        if (task.running) {
            queuedArgv = argv
            task.running = false
            return
        }
        task.command = argv
        task.running = true
    }

    visible: false
    screen: panelScreen
    color: "transparent"
    grabFocus: opened && grabArmed
    implicitWidth: menuWidth
    implicitHeight: menuColumn.implicitHeight + inset * 2
    anchor.window: anchorWindow
    anchor.item: anchorItem
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Top | Edges.Right
    anchor.margins.top: lift
    anchor.adjustment: PopupAdjustment.Slide

    onOpenedChanged: {
        visible = opened
        if (opened) {
            blockOpen = false
            blockTimer.stop()
            notice = ""
            grabArmed = false
            return
        }
        grabArmed = false
    }
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(function() { tasksAction.forceActiveFocus() })
            return
        }
        if (!opened)
            return
        blockOpen = true
        blockTimer.restart()
        opened = false
    }

    Apps { id: apps }

    Process {
        id: task
        onStarted: {
            root.startedSerial = root.launchSerial
            root.opened = false
        }
        onExited: {
            if (root.queuedArgv) {
                const next = root.queuedArgv
                root.queuedArgv = null
                task.command = next
                task.running = true
                return
            }
            if (root.launchSerial === 0 || root.startedSerial === root.launchSerial)
                return
            root.notice = "Не получилось открыть терминал"
        }
    }

    Timer {
        id: blockTimer
        interval: 200
        onTriggered: root.blockOpen = false
    }
    Timer {
        id: armTimer
        interval: 50
        onTriggered: {
            if (root.opened)
                root.grabArmed = true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.tokens.radius.small + root.tokens.spacing.small
        color: root.tokens.color.surfaceAlt
        border.width: 1
        border.color: root.tokens.color.border
        antialiasing: true

        Column {
            id: menuColumn
            x: root.inset
            y: root.inset
            width: parent.width - root.inset * 2
            spacing: root.tokens.spacing.small
            Keys.onEscapePressed: function(event) {
                root.close()
                event.accepted = true
            }

            MenuRow {
                id: tasksAction
                width: parent.width
                tokens: root.tokens
                text: "Диспетчер задач"
                KeyNavigation.down: settingsAction
                KeyNavigation.up: settingsAction
                onEscapePressed: root.close()
                onClicked: root.launchTasks()
            }
            MenuRow {
                id: settingsAction
                width: parent.width
                tokens: root.tokens
                text: "Настройки"
                KeyNavigation.up: tasksAction
                KeyNavigation.down: tasksAction
                onEscapePressed: root.close()
                onClicked: root.openSettings()
            }
            Text {
                width: parent.width
                visible: root.notice !== ""
                text: root.notice
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: root.tokens.color.secondary
                font.family: root.tokens.type.body.family
                font.pixelSize: root.tokens.type.body.size
                font.weight: root.tokens.type.body.weight
                lineHeight: root.tokens.type.body.lineHeight
                lineHeightMode: Text.ProportionalHeight
                renderType: Text.NativeRendering
            }
        }
    }
}
