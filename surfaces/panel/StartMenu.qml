pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../services"
import "../../services/system"

// Левое меню Пуска. Питание только через SessionActions и только после подтверждения.
PopupWindow {
    id: root

    required property var tokens
    required property var shellState
    required property var panelScreen
    required property Item anchorItem
    property var anchorWindow: null

    property bool opened: false
    property bool blockOpen: false
    property bool keepFailure: false
    property string page: "main"
    property string pendingAction: ""
    property string notice: ""
    property string failure: ""

    readonly property int inset: tokens.spacing.small
    readonly property int menuWidth: 272
    readonly property int lift: Math.round((tokens.panel.height - tokens.panel.control) / 2 + tokens.spacing.small)
    readonly property string terminalId: {
        const raw = shellState.preferredTerminal
        const text = raw === undefined || raw === null ? "" : String(raw).trim()
        return text || "kitty"
    }
    readonly property string fileManagerId: {
        const raw = shellState.preferredFileManager
        const text = raw === undefined || raw === null ? "" : String(raw).trim()
        return text || "org.gnome.Nautilus"
    }
    readonly property string blockedReason: {
        const value = session.unavailableReason
        return value ? String(value) : ""
    }
    readonly property bool sessionBusy: session.busy

    function toggle() {
        if (blockOpen) {
            blockOpen = false
            blockTimer.stop()
            return
        }
        opened = !opened
    }

    function dismissEscape() {
        if (page !== "main") {
            page = "main"
            pendingAction = ""
            return
        }
        opened = false
    }

    function resetTransient() {
        page = "main"
        pendingAction = ""
        notice = ""
        failure = ""
    }

    function showPage(next) {
        notice = ""
        if (next === "main")
            pendingAction = ""
        page = next
        Qt.callLater(root.focusPage)
    }

    function ask(kind) {
        failure = ""
        pendingAction = kind
        showPage("confirm")
    }

    function confirmTitle() {
        if (pendingAction === "lock")
            return "Заблокировать экран?"
        if (pendingAction === "logout")
            return "Выйти из сессии?"
        if (pendingAction === "reboot")
            return "Перезагрузить компьютер?"
        if (pendingAction === "powerOff")
            return "Выключить компьютер?"
        return ""
    }

    function confirmBody() {
        if (pendingAction === "lock")
            return "Сессия останется открытой"
        if (pendingAction === "logout")
            return "Открытые приложения закроются"
        if (pendingAction === "reboot" || pendingAction === "powerOff")
            return "Несохраненная работа пропадет"
        return ""
    }

    function confirmLabel() {
        if (pendingAction === "lock")
            return "Заблокировать"
        if (pendingAction === "logout")
            return "Выйти"
        if (pendingAction === "reboot")
            return "Перезагрузить"
        if (pendingAction === "powerOff")
            return "Выключить"
        return ""
    }

    function openSettings() {
        shellState.overlayScreen = panelScreen
        shellState.openSettings("home")
        opened = false
    }

    function openLauncher() {
        shellState.overlayScreen = panelScreen
        shellState.launcherOpened = true
        opened = false
    }

    function launchDesktop(desktopId, unavailable) {
        notice = ""
        const entry = apps.lookup(desktopId)
        if (!entry || !apps.launch(desktopId)) {
            notice = unavailable
            return
        }
        opened = false
    }

    function runPending() {
        if (session.busy || pendingAction === "")
            return
        failure = ""
        const kind = pendingAction
        let ok = false
        if (kind === "lock")
            ok = session.lock()
        else if (kind === "logout")
            ok = session.logout()
        else if (kind === "reboot")
            ok = session.reboot()
        else if (kind === "powerOff")
            ok = session.powerOff()
        if (failure !== "")
            return
        if (!ok)
            failure = blockedReason || "Не получилось"
    }

    function focusPage() {
        if (!opened)
            return
        if (page === "power")
            powerBack.forceActiveFocus()
        else if (page === "confirm")
            confirmAction.forceActiveFocus()
        else
            settingsAction.forceActiveFocus()
    }

    visible: false
    screen: panelScreen
    color: "transparent"
    grabFocus: opened
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
        if (!opened)
            return
        blockOpen = false
        blockTimer.stop()
        if (!keepFailure)
            resetTransient()
    }
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(root.focusPage)
            return
        }
        if (!opened)
            return
        blockOpen = true
        blockTimer.restart()
        opened = false
    }

    Apps { id: apps }

    SessionActions { id: session }

    Connections {
        target: session
        function onFailed(action, message) {
            const text = message ? String(message).trim() : ""
            root.failure = text || "Не получилось"
            root.pendingAction = action || root.pendingAction
            root.page = "confirm"
            root.keepFailure = true
            root.opened = true
            root.keepFailure = false
        }
        function onStarted(action) {
            if (root.failure === "")
                root.opened = false
        }
    }

    Timer {
        id: blockTimer
        interval: 200
        onTriggered: root.blockOpen = false
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
                root.dismissEscape()
                event.accepted = true
            }

            Item {
                width: parent.width
                implicitWidth: width
                implicitHeight: height
                height: root.page === "power" ? powerPage.implicitHeight
                      : root.page === "confirm" ? confirmPage.implicitHeight
                      : mainPage.implicitHeight

            Column {
                id: mainPage
                width: parent.width
                spacing: root.tokens.spacing.small
                visible: root.page === "main"

                Item {
                    width: parent.width
                    height: root.tokens.panel.control
                    Accessible.ignored: true
                    NayoriMark {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        ink: root.tokens.color.text
                    }
                }
                MenuRow {
                    id: settingsAction
                    width: parent.width
                    tokens: root.tokens
                    text: "Настройки"
                    KeyNavigation.down: powerAction
                    KeyNavigation.up: filesAction
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.openSettings()
                }
                MenuRow {
                    id: powerAction
                    width: parent.width
                    tokens: root.tokens
                    text: "Питание ›"
                    enabled: !root.sessionBusy
                    KeyNavigation.up: settingsAction
                    KeyNavigation.down: launcherAction
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.showPage("power")
                }
                MenuRow {
                    id: launcherAction
                    width: parent.width
                    tokens: root.tokens
                    text: "Лаунчер"
                    KeyNavigation.up: powerAction
                    KeyNavigation.down: terminalAction
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.openLauncher()
                }
                MenuRow {
                    id: terminalAction
                    width: parent.width
                    tokens: root.tokens
                    text: "Терминал"
                    KeyNavigation.up: launcherAction
                    KeyNavigation.down: filesAction
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.launchDesktop(root.terminalId, "Терминал недоступен")
                }
                MenuRow {
                    id: filesAction
                    width: parent.width
                    tokens: root.tokens
                    text: "Файлы"
                    KeyNavigation.up: terminalAction
                    KeyNavigation.down: settingsAction
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.launchDesktop(root.fileManagerId, "Файлы недоступны")
                }
            }

            Column {
                id: powerPage
                width: parent.width
                spacing: root.tokens.spacing.small
                visible: root.page === "power"

                Text {
                    width: parent.width
                    text: "Питание"
                    textFormat: Text.PlainText
                    color: root.tokens.color.text
                    font.family: root.tokens.type.display.family
                    font.pixelSize: root.tokens.type.display.size
                    font.weight: root.tokens.type.display.weight
                    font.letterSpacing: root.tokens.type.display.letterSpacing
                    lineHeight: root.tokens.type.display.lineHeight
                    lineHeightMode: Text.ProportionalHeight
                    renderType: Text.NativeRendering
                }
                MenuRow {
                    width: parent.width
                    tokens: root.tokens
                    text: "Блокировка"
                    enabled: !root.sessionBusy
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.ask("lock")
                }
                MenuRow {
                    width: parent.width
                    tokens: root.tokens
                    text: "Выход"
                    enabled: !root.sessionBusy
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.ask("logout")
                }
                MenuRow {
                    width: parent.width
                    tokens: root.tokens
                    text: "Перезагрузка"
                    enabled: !root.sessionBusy
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.ask("reboot")
                }
                MenuRow {
                    width: parent.width
                    tokens: root.tokens
                    text: "Выключение"
                    enabled: !root.sessionBusy
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.ask("powerOff")
                }
                MenuRow {
                    id: powerBack
                    width: parent.width
                    tokens: root.tokens
                    text: "Назад"
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.showPage("main")
                }
            }

            Column {
                id: confirmPage
                width: parent.width
                spacing: root.tokens.spacing.small
                visible: root.page === "confirm"

                Text {
                    width: parent.width
                    text: root.confirmTitle()
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    color: root.tokens.color.text
                    font.family: root.tokens.type.display.family
                    font.pixelSize: root.tokens.type.display.size
                    font.weight: root.tokens.type.display.weight
                    font.letterSpacing: root.tokens.type.display.letterSpacing
                    lineHeight: root.tokens.type.display.lineHeight
                    lineHeightMode: Text.ProportionalHeight
                    renderType: Text.NativeRendering
                }
                Text {
                    width: parent.width
                    text: root.confirmBody()
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    color: root.tokens.color.textMuted
                    font.family: root.tokens.type.body.family
                    font.pixelSize: root.tokens.type.body.size
                    font.weight: root.tokens.type.body.weight
                    lineHeight: root.tokens.type.body.lineHeight
                    lineHeightMode: Text.ProportionalHeight
                    renderType: Text.NativeRendering
                }
                MenuRow {
                    id: confirmAction
                    width: parent.width
                    tokens: root.tokens
                    text: root.confirmLabel()
                    enabled: root.pendingAction !== "" && !root.sessionBusy
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.runPending()
                }
                MenuRow {
                    width: parent.width
                    tokens: root.tokens
                    text: "Отмена"
                    onEscapePressed: root.dismissEscape()
                    onClicked: {
                        root.pendingAction = ""
                        root.failure = ""
                        root.showPage("power")
                    }
                }
            }
            }

            Text {
                width: parent.width
                visible: root.notice !== "" && root.page === "main"
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
            Text {
                width: parent.width
                visible: root.failure !== ""
                text: root.failure
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
            Text {
                width: parent.width
                visible: root.page !== "main" && root.failure === "" && root.blockedReason !== ""
                text: root.blockedReason
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
