pragma ComponentBehavior: Bound

//@ pragma UseQApplication
//@ pragma AppId nayori

import QtQuick
import Quickshell
import "tokens"
import "services/startup"
import "surfaces/startup"

// Render the lightweight cover before even importing the shell's services.
// One process is enough: there is no extra daemon or IPC handoff to race.
ShellRoot {
    id: boot
    property var appearance: null
    property bool sessionStarted: false
    PersistentProperties { id: bootMemory; property bool finished: false }
    readonly property bool appearanceReady: appearance !== null
    StartupCache {
        id: cache
        onReadyChanged: {
            if (!ready || boot.appearanceReady) return
            if (!snapshot.enabled || bootMemory.finished) bootState.present = false
            boot.appearance = Object.assign({}, snapshot)
            boot.beginSession()
        }
    }
    StartupState {
        id: bootState
        outputs: Quickshell.screens.map(output => output.name)
        onCoveredChanged: boot.beginSession()
        onPresentChanged: {
            if (!present) bootMemory.finished = true
            boot.beginSession()
        }
    }
    Tokens {
        id: bootTokens
        animationsEnabled: session.item && session.item.settingsService.ready
            ? session.item.settingsService.animationsEnabled
            : boot.appearanceReady ? boot.appearance.animationsEnabled : true
    }
    function beginSession() {
        if (sessionStarted || !appearanceReady || (bootState.present && !bootState.covered)) return
        sessionStarted = true
        session.setSource(Qt.resolvedUrl("surfaces/ShellSession.qml"), {startup: bootState, startupCache: cache})
        session.active = true
    }
    Loader {
        id: session
        active: false
        asynchronous: true
        onStatusChanged: if (status === Loader.Error) {
            bootState.error = "Не удалось загрузить оболочку. Откройте рабочий стол и перезапустите Nayori."
            bootState.stalled = true
        }
    }
    Variants {
        model: boot.appearanceReady && bootState.present ? Quickshell.screens : []
        StartupWindow {
            required property var modelData
            screen: modelData
            startup: bootState
            tokens: bootTokens
            // Freeze appearance for the whole launch. Live palette updates only
            // affect the next launch's cache, never the visible splash.
            splashAccent: boot.appearance.dynamicAccent ? boot.appearance.accent : "#C0AFD1"
            fadeDuration: boot.appearance.fadeDuration
            waitingFor: session.status === Loader.Error ? "не удалось загрузить оболочку"
                : session.item ? session.item.startupWaitingFor : "загрузка оболочки"
        }
    }
}
