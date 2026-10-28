pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../../services/system"

// Левое меню Пуска. Действия сеанса выполняются через SessionActions.
PanelWindow {
    id: root

    required property var tokens
    required property var shellState
    required property var panelScreen
    required property Item anchorItem
    property var anchorWindow: null

    property bool opened: false
    property real reveal: opened ? 1 : 0
    readonly property bool presenting: visible
    readonly property alias menuContent: menuSurface
    readonly property int menuHeight: menuColumn.implicitHeight + inset * 2
    readonly property int revealedHeight: Math.round(menuHeight * reveal)
    readonly property alias blurBounds: glassRegion
    readonly property int panelGap: tokens.spacing.medium
    Behavior on reveal {
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.base
            easing.type: root.opened ? Easing.BezierSpline : Easing.Linear
            easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        }
    }
    onRevealChanged: {
        if (!opened && reveal === 0) visible = false
    }
    property bool keepFailure: false
    property string page: "main"
    property string notice: ""
    property string failure: ""

    readonly property int inset: tokens.spacing.medium
    readonly property int menuWidth: 360
    readonly property int lift: Math.round((tokens.panel.height - tokens.panel.control) / 2 + tokens.spacing.medium)
    readonly property string terminalId: {
        const raw = shellState.preferredTerminal
        const text = raw === undefined || raw === null ? "" : String(raw).trim()
        return text || "kitty"
    }
    readonly property string fileManagerId: {
        const raw = shellState.preferredFileManager
        const text = raw === undefined || raw === null ? "" : String(raw).trim()
        return text || "io.github.lgse.Strata"
    }
    readonly property string blockedReason: {
        const value = session.unavailableReason
        return value ? String(value) : ""
    }
    readonly property bool sessionBusy: session.busy

    function toggle() {
        opened = !opened
    }

    function dismissEscape() {
        if (page !== "main") {
            page = "main"
            return
        }
        opened = false
    }

    function resetTransient() {
        page = "main"
        notice = ""
        failure = ""
    }

    function showPage(next) {
        notice = ""
        failure = ""
        page = next
        Qt.callLater(root.focusPage)
    }

    function applicationName(desktopId) {
        const entry = apps.lookup(desktopId)
        return entry ? String(entry.name) : "Приложение недоступно"
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

    function runAction(kind) {
        if (session.busy || !opened || page !== "power")
            return
        failure = ""
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
        else
            settingsAction.forceActiveFocus()
    }

    visible: false
    screen: panelScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: opened
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nayori-start"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Release pointer input immediately, but keep the same surface mapped until
    // the exit finishes. No compositor dismissal or screenshot window swap.
    mask: Region { width: root.opened ? root.width : 0; height: root.opened ? root.height : 0 }
    // The compositor blur has no opacity control. Its region must follow the
    // actual clipped reveal, rather than the full invisible menu rectangle.
    Region {
        id: glassRegion
        x: revealClip.x
        y: revealClip.y
        width: revealClip.width
        height: root.revealedHeight
        radius: Math.min(root.tokens.radius.small + root.tokens.spacing.small, height / 2)
    }
    BackgroundEffect.blurRegion: root.tokens.frosted && root.revealedHeight > 0 ? glassRegion : null

    function dismissOutside() {
        if (!opened) return
        opened = false
    }

    onOpenedChanged: {
        if (!opened) {
            if (tokens.motion.off || reveal === 0) visible = false
            return
        }
        visible = true
        profile.refresh()
        if (!keepFailure) resetTransient()
        Qt.callLater(root.focusPage)
    }
    onVisibleChanged: {
        if (!visible && opened) opened = false
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: function(mouse) {
            if (mouse.x < revealClip.x || mouse.x >= revealClip.x + revealClip.width
                    || mouse.y < revealClip.y || mouse.y >= revealClip.y + revealClip.height)
                root.dismissOutside()
        }
        onWheel: function(wheel) { wheel.accepted = true }
    }

    UserProfile { id: profile; active: root.opened }

    Apps { id: apps }

    SessionActions { id: session }

    Connections {
        target: session
        function onFailed(action, message) {
            const text = message ? String(message).trim() : ""
            root.failure = text || "Не получилось"
            root.page = "power"
            root.keepFailure = true
            root.opened = true
            root.keepFailure = false
        }
        function onStarted(action) {
            if (root.failure === "")
                root.opened = false
        }
    }

    Item {
        id: revealClip
        x: Math.max(0, Math.min(root.tokens.spacing.large, root.width - width))
        y: Math.max(root.tokens.spacing.small,
                    root.height - root.tokens.spacing.small - root.tokens.panel.height - root.panelGap - height)
        width: Math.min(root.menuWidth, root.width)
        height: root.revealedHeight
        clip: true

    Rectangle {
        id: menuSurface
        width: parent.width
        height: root.menuHeight
        y: parent.height - height
        enabled: root.opened
        opacity: root.reveal
        radius: root.tokens.radius.small + root.tokens.spacing.small
        color: root.tokens.material.dense
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
                      : mainPage.implicitHeight

            Column {
                id: mainPage
                width: parent.width
                spacing: root.tokens.spacing.small
                visible: root.page === "main"

                Item {
                    width: parent.width
                    height: 80
                    UserAvatar {
                        x: 8; y: 8
                        width: 64; height: 64
                        tokens: root.tokens
                        source: profile.avatar
                        username: profile.username
                    }
                    Column {
                        x: 88
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - 60
                        spacing: 5
                        Text {
                            width: parent.width
                            text: profile.username
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: root.tokens.color.text
                            font.family: root.tokens.type.display.family
                            font.pixelSize: 20
                            font.weight: 500
                        }
                        Text {
                            width: parent.width
                            text: profile.hostname + (profile.uptime ? " · " + profile.uptime : "")
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: root.tokens.color.textMuted
                            font.family: root.tokens.type.small.family
                            font.pixelSize: 12
                            Accessible.name: profile.hostname + (profile.uptime ? ", время работы " + profile.uptime : "")
                        }
                    }
                    MenuRow {
                        id: settingsAction
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44; height: 44
                        tokens: root.tokens
                        text: "Настройки"
                        Accessible.name: text
                        contentItem: Item {
                            MenuGlyph {
                                anchors.centerIn: parent
                                kind: "settings"
                                ink: root.tokens.color.menuIcon
                                width: 24; height: 24
                            }
                        }
                        background: Rectangle {
                            radius: root.tokens.radius.medium
                            color: settingsAction.down ? root.tokens.color.accentSoft
                                 : settingsAction.hovered ? root.tokens.color.surface : root.tokens.color.surfaceAlt
                            border.width: settingsAction.visualFocus ? 1 : 0
                            border.color: root.tokens.color.accent
                        }
                        KeyNavigation.down: launcherAction
                        KeyNavigation.up: powerAction
                        onEscapePressed: root.dismissEscape()
                        onClicked: root.openSettings()
                    }
                }
                MenuRow {
                    id: launcherAction
                    width: parent.width
                    tokens: root.tokens
                    text: "Лаунчер"
                    subtitle: "Все приложения"
                    glyph: "apps"
                    KeyNavigation.up: settingsAction
                    KeyNavigation.down: terminalAction
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.openLauncher()
                }
                MenuRow {
                    id: terminalAction
                    width: parent.width
                    tokens: root.tokens
                    text: "Терминал"
                    subtitle: root.applicationName(root.terminalId)
                    glyph: "terminal"
                    KeyNavigation.up: launcherAction
                    KeyNavigation.down: filesAction
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.launchDesktop(root.terminalId, "Терминал недоступен")
                }
                MenuRow {
                    id: filesAction
                    width: parent.width
                    tokens: root.tokens
                    text: "Файловый менеджер"
                    subtitle: root.applicationName(root.fileManagerId)
                    glyph: "folder"
                    KeyNavigation.up: terminalAction
                    KeyNavigation.down: powerAction
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.launchDesktop(root.fileManagerId, "Файлы недоступны")
                }
                Item {
                    width: parent.width
                    height: 17
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 20; height: 1
                        color: root.tokens.color.border
                    }
                }
                MenuRow {
                    id: powerAction
                    width: parent.width
                    tokens: root.tokens
                    text: "Питание"
                    glyph: "power"
                    enabled: !root.sessionBusy
                    KeyNavigation.up: filesAction
                    KeyNavigation.down: settingsAction
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.showPage("power")
                }
            }

            Column {
                id: powerPage
                width: parent.width
                spacing: root.tokens.spacing.small
                visible: root.page === "power"

                MenuRow {
                    id: powerBack
                    width: parent.width
                    tokens: root.tokens
                    showChevron: false
                    text: "Назад"
                    glyph: "back"
                    KeyNavigation.down: lockAction
                    KeyNavigation.up: shutdownAction
                    onEscapePressed: root.dismissEscape()
                    onClicked: root.showPage("main")
                }
                Rectangle {
                    x: 10
                    width: parent.width - 20
                    height: 1
                    color: root.tokens.color.border
                }
                HoldMenuRow {
                    id: lockAction
                    width: parent.width
                    tokens: root.tokens
                    showChevron: false
                    text: "Заблокировать"
                    glyph: "lock"
                    enabled: !root.sessionBusy
                    KeyNavigation.up: powerBack
                    KeyNavigation.down: logoutAction
                    onEscapePressed: root.dismissEscape()
                    holdEnabled: root.opened && root.page === "power"
                    onHeld: root.runAction("lock")
                }
                HoldMenuRow {
                    id: logoutAction
                    width: parent.width
                    tokens: root.tokens
                    showChevron: false
                    text: "Выйти из сессии"
                    glyph: "logout"
                    enabled: !root.sessionBusy
                    KeyNavigation.up: lockAction
                    KeyNavigation.down: rebootAction
                    onEscapePressed: root.dismissEscape()
                    holdEnabled: root.opened && root.page === "power"
                    onHeld: root.runAction("logout")
                }
                HoldMenuRow {
                    id: rebootAction
                    width: parent.width
                    tokens: root.tokens
                    showChevron: false
                    text: "Перезагрузить"
                    glyph: "reboot"
                    enabled: !root.sessionBusy
                    KeyNavigation.up: logoutAction
                    KeyNavigation.down: shutdownAction
                    onEscapePressed: root.dismissEscape()
                    holdEnabled: root.opened && root.page === "power"
                    onHeld: root.runAction("reboot")
                }
                HoldMenuRow {
                    id: shutdownAction
                    width: parent.width
                    tokens: root.tokens
                    showChevron: false
                    text: "Выключить"
                    glyph: "power"
                    enabled: !root.sessionBusy
                    KeyNavigation.up: rebootAction
                    KeyNavigation.down: powerBack
                    onEscapePressed: root.dismissEscape()
                    holdEnabled: root.opened && root.page === "power"
                    onHeld: root.runAction("powerOff")
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
}
