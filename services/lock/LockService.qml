pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../../sddm/nayori/components"
import "../../surfaces/lock"
import "../system"

// ext-session-lock + PAM, following Angel OS's architecture. A preview never
// acquires a lock and cannot dismiss a real one. There is no IPC unlock method.
Scope {
    id: root
    required property var tokens
    required property var wallpapers
    required property var music
    property string primaryOutput: ""
    property bool previewing: false
    property bool sleeping: false
    property bool requested: false
    property bool systemIntegration: true
    property string status: ""
    property string secret: ""
    property bool initialResponse: false
    property bool unlocking: false
    property bool hintWanted: false
    // Quickshell 0.3.2 does not notify locked consistently on unlock.
    readonly property bool locked: lockState.engaged
    readonly property bool secure: sessionLock.secure
    readonly property bool shown: locked || previewing
    readonly property bool busy: unlocking || (pam.active && !pam.responseRequired)
    readonly property string mainOutput: {
        const screens = Quickshell.screens
        return screens.some(s => s.name === primaryOutput) ? primaryOutput : screens.length ? screens[0].name : ""
    }
    readonly property string sessionPath: {
        const id = String(Quickshell.env("XDG_SESSION_ID") || "")
        let encoded = ""
        for (let i = 0; i < id.length; ++i) {
            const c = id[i]
            encoded += /[A-Za-z0-9]/.test(c) && !(i === 0 && /[0-9]/.test(c)) ? c : "_" + c.charCodeAt(0).toString(16).padStart(2, "0")
        }
        return id ? "/org/freedesktop/login1/session/" + encoded : ""
    }
    signal relay(string text, int key)
    signal clearInput
    signal focusInput

    PersistentProperties {
        id: lockState
        property bool engaged: false
        property bool watchWasEnabled: false
        property bool pausedWatching: false
    }

    onSleepingChanged: if (sleeping) {
        unlockTimer.stop()
        unlocking = false
        if (pam.active) pam.abort()
        secret = ""
        initialResponse = false
        clearInput()
    }

    function lock() {
        if (locked || requested) return
        previewing = false
        status = ""
        clearInput()
        requested = true
        lockState.watchWasEnabled = Quickshell.watchFiles
        lockState.pausedWatching = true
        // 0.3.2 can create duplicate lock surfaces on reload. Keep the live
        // lock stable while editing source, then restore the prior setting.
        Quickshell.watchFiles = false
        lockState.engaged = true
    }
    function preview() {
        if (locked || requested) return
        status = "Предпросмотр: пароль не проверяется"
        previewing = true
    }
    function closePreview() {
        if (!locked) { previewing = false; clearInput() }
    }
    function submit(value) {
        if (!locked) { if (previewing) status = "Предпросмотр: для выхода нажмите «Закрыть предпросмотр»"; return }
        if (busy) return
        if (pam.active && pam.responseRequired) {
            pam.respond(value)
            return
        }
        secret = value
        initialResponse = true
        status = "Проверка…"
        if (!pam.start()) {
            secret = ""
            initialResponse = false
            status = "Не удалось начать проверку пароля. Повторите попытку"
        }
    }
    function finishUnlock() {
        if (!unlocking || sleeping || !locked) return
        unlocking = false
        setLockedHint(false)
        lockState.engaged = false
        requested = false
        status = ""
        if (lockState.pausedWatching) {
            lockState.pausedWatching = false
            Quickshell.watchFiles = lockState.watchWasEnabled
        }
    }
    Timer {
        id: unlockTimer
        interval: root.tokens.motion.off ? 0 : root.tokens.motion.fast
        onTriggered: root.finishUnlock()
    }
    function setLockedHint(value) {
        hintWanted = value
        flushLockedHint()
    }
    function flushLockedHint() {
        if (!systemIntegration || !sessionPath || hint.running) return
        hint.submittedState = hintWanted
        hint.command = ["gdbus", "call", "--system", "--dest", "org.freedesktop.login1", "--object-path", sessionPath,
            "--method", "org.freedesktop.login1.Session.SetLockedHint", hintWanted ? "true" : "false"]
        hint.running = true
    }
    UserProfile { id: profile; active: root.shown }
    onShownChanged: if (music) music.consumer("lockscreen", shown)
    onMainOutputChanged: { clearInput(); focusInput() }
    Component.onDestruction: if (music) music.consumer("lockscreen", false)

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function preview(): void { root.preview() }
        function closePreview(): void { root.closePreview() }
    }
    PamContext {
        id: pam
        configDirectory: Quickshell.shellDir + "/pam"
        config: "nayori-lock"
        onResponseRequiredChanged: {
            if (!responseRequired) return
            if (root.initialResponse) {
                root.initialResponse = false
                const response = root.secret
                root.secret = ""
                respond(response)
            } else {
                root.status = message || "Введите ответ для продолжения"
                root.focusInput()
            }
        }
        onCompleted: result => {
            root.secret = ""
            root.initialResponse = false
            root.clearInput()
            if (result === PamResult.Success && root.locked && !root.sleeping) {
                root.unlocking = true
                root.status = ""
                unlockTimer.restart()
            } else {
                root.status = "Не удалось разблокировать. Проверьте пароль и раскладку клавиатуры"
                root.focusInput()
            }
        }
        onError: error => {
            root.secret = ""
            root.initialResponse = false
            root.status = "Ошибка проверки пароля. Повторите попытку"
            root.clearInput()
            root.focusInput()
        }
    }
    WlSessionLock {
        id: sessionLock
        locked: lockState.engaged
        onSecureChanged: if (secure) { root.requested = false; root.setLockedHint(true) }
        WlSessionLockSurface {
            id: surface
            color: root.tokens.color.background
            AuthView {
                id: lockView
                anchors.fill: parent
                colors: root.tokens.color
                primary: !!surface.screen && surface.screen.name === root.mainOutput
                wallpaper: root.wallpapers.wallpaper(surface.screen ? surface.screen.name : "").source
                wallpaperMode: root.wallpapers.wallpaper(surface.screen ? surface.screen.name : "").mode
                username: profile.username
                avatar: profile.avatar
                busy: root.busy
                exiting: root.unlocking
                animationsEnabled: !root.tokens.motion.off
                enterDuration: root.tokens.motion.base
                exitDuration: root.tokens.motion.fast
                motionCurve: root.tokens.motion.easeOut
                status: root.status
                responseVisible: pam.active && pam.responseVisible
                passwordLabel: pam.active && pam.responseRequired ? "Ответ" : "Пароль"
                capsLock: keyboard.capsLock
                layoutName: keyboard.layout
                canSwitchLayout: keyboard.canSwitch
                onLayoutRequested: keyboard.nextLayout()
                canSuspend: true
                canReboot: true
                canPowerOff: true
                mediaAvailable: !!root.music && !!root.music.player
                onSubmitted: value => root.submit(value)
                onPowerRequested: action => {
                    root.runPower(action)
                }
            }
            Item {
                anchors.fill: parent
                visible: !lockView.primary
                focus: visible
                Keys.onPressed: event => {
                    root.relay(event.text, event.key)
                    event.accepted = true
                }
                MouseArea { anchors.fill: parent; onClicked: parent.forceActiveFocus() }
            }
            Connections {
                target: root
                function onRelay(text, key) { if (lockView.primary) lockView.relayKey(text, key) }
                function onClearInput() { lockView.clearPassword() }
                function onFocusInput() { lockView.focusPassword() }
            }
            Component.onCompleted: lockView.mediaComponent = musicCard
            Component {
                id: musicCard
                LockMusic { colors: root.tokens.color; music: root.music }
            }
        }
    }
    Loader {
        active: root.previewing && !root.locked
        onActiveChanged: {
            if (active) setSource(Qt.resolvedUrl("../../surfaces/lock/LockPreview.qml"), { controller: root })
            else source = ""
        }
    }
    LockKeyboard { id: keyboard; enabled: root.shown }
    Process {
        id: hint
        property bool submittedState: false
        onExited: if (submittedState !== root.hintWanted) root.flushLockedHint()
    }
    function runPower(action) {
        if (["suspend", "reboot", "powerOff"].indexOf(action) < 0 || power.running) return
        if (!systemIntegration) return
        power.command = ["systemctl", action === "powerOff" ? "poweroff" : action]
        power.running = true
    }
    Process {
        id: power
        onExited: code => {
            if (code !== 0) root.status = "Не удалось выполнить действие питания. Повторите попытку"
        }
    }
    // logind waits until ext-session-lock is confirmed before suspending.
    // Closing stdin releases the delay inhibitor; it is taken again on resume.
    Process {
        id: inhibitor
        running: root.systemIntegration && (!root.sleeping || !root.secure)
        stdinEnabled: true
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Nayori", "--why=Lock before sleep", "cat"]
    }
    Process {
        id: logind
        running: root.systemIntegration
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: line => {
                if (/\.Manager\.PrepareForSleep \(true/.test(line)) {
                    root.sleeping = true
                    root.lock()
                } else if (/\.Manager\.PrepareForSleep \(false/.test(line)) {
                    root.sleeping = false
                    root.lock()
                } else if (root.sessionPath && line.startsWith(root.sessionPath + ":") && /\.Session\.Lock \(\)/.test(line)) root.lock()
            }
        }
        onExited: if (root.systemIntegration) logindRestart.restart()
    }
    Timer { id: logindRestart; interval: 2000; onTriggered: logind.running = true }
}
