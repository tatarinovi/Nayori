import QtQuick
import QtQuick.Window
import "components"

Item {
    id: root
    width: 1920
    height: 1080
    property bool authenticating: false
    property string message: ""
    property int selectedUser: typeof userModel !== "undefined" ? Math.max(0, userModel.lastIndex) : 0
    property int selectedSession: typeof sessionModel !== "undefined" ? Math.max(0, sessionModel.lastIndex) : 0
    readonly property string outputName: Screen.name
    readonly property string preferredOutput: value("primaryOutput", "")
    readonly property bool preferredConnected: preferredOutput !== "" && Qt.application.screens.some(s => s.name === preferredOutput)
    readonly property bool isPrimary: preferredConnected ? outputName === preferredOutput
        : typeof primaryScreen !== "undefined" ? primaryScreen
        : typeof screenModel !== "undefined" ? screenModel.primary === 0 : true
    readonly property var wallpaperData: {
        try { return JSON.parse(value("wallpapers", "{}")) } catch (e) { return ({}) }
    }
    readonly property var outputWallpaper: wallpaperData[outputName] || ({ source: value("wallpaper", ""), mode: value("wallpaperMode", "fill") })
    onIsPrimaryChanged: if (isPrimary) focusPrimary.restart()
    Timer {
        id: focusPrimary
        interval: 200
        running: true
        onTriggered: if (root.isPrimary) {
            if (root.Window.window) root.Window.window.requestActivate()
            view.focusPassword()
        }
    }
    function value(key, fallback) {
        if (typeof config === "undefined") return fallback
        const result = config[key]
        return result === undefined || result === "" ? fallback : String(result)
    }
    function login(secret) {
        if (!isPrimary || authenticating || !view.selectedLogin || selectedSession < 0) return
        authenticating = true
        message = ""
        sddm.login(view.selectedLogin, secret, selectedSession)
    }
    AuthPalette {
        id: palette
        background: root.value("background", "#121217")
        surface: root.value("surface", "#4F4F57")
        surfaceAlt: root.value("surfaceAlt", "#443D4E")
        text: root.value("text", "#F0E9DB")
        textMuted: root.value("textMuted", "#D5CEC4")
        accent: root.value("accent", "#C0AFD1")
        accentText: root.value("accentText", "#121217")
        border: root.value("border", "#57F0E9DB")
    }
    AuthView {
        id: view
        anchors.fill: parent
        colors: palette
        primary: root.isPrimary
        loginMode: true
        animationsEnabled: root.value("animationsEnabled", "true") === "true"
        enterDuration: Number(root.value("enterDuration", "220"))
        exitDuration: Number(root.value("exitDuration", "140"))
        username: view.selectedLogin
        avatar: view.selectedAvatar
        wallpaper: root.outputWallpaper.source || ""
        wallpaperMode: root.outputWallpaper.mode || "fill"
        usersModel: typeof userModel !== "undefined" ? userModel : []
        sessionsModel: typeof sessionModel !== "undefined" ? sessionModel : []
        userIndex: root.selectedUser
        sessionIndex: root.selectedSession
        busy: root.authenticating
        status: root.message
        capsLock: typeof keyboard !== "undefined" && keyboard.capsLock
        layoutName: typeof keyboard !== "undefined" && keyboard.layouts.length > 0 ? keyboard.layouts[keyboard.currentLayout].shortName : ""
        canSwitchLayout: typeof keyboard !== "undefined" && keyboard.enabled && keyboard.layouts.length > 1
        onLayoutRequested: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        canSuspend: typeof sddm !== "undefined" && sddm.canSuspend
        canReboot: typeof sddm !== "undefined" && sddm.canReboot
        canPowerOff: typeof sddm !== "undefined" && sddm.canPowerOff
        onSubmitted: secret => root.login(secret)
        onUserSelected: index => { root.selectedUser = index; root.message = ""; focusPassword() }
        onSessionSelected: index => { root.selectedSession = index; focusPassword() }
        onPowerRequested: action => {
            if (action === "suspend") sddm.suspend()
            else if (action === "reboot") sddm.reboot()
            else if (action === "powerOff") sddm.powerOff()
        }
    }
    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            root.authenticating = false
            root.message = "Не удалось войти. Проверьте пароль и раскладку клавиатуры"
            view.clearPassword()
            view.focusPassword()
        }
        function onLoginSucceeded() { view.clearPassword(); view.exiting = true }
    }
}
