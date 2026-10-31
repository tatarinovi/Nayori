pragma ComponentBehavior: Bound
import "../../services/ui/PanelModes.js" as PanelModes
import "../../services/island/NotificationPolicy.js" as NotificationPolicy
import QtQuick
import Quickshell
import "../../services/settings"

// Shell-owned: one UI instance, no storage and no dependency on panel geometry.
QtObject {
    id: root
    property var companionTokens: tokens
    property var updateService: null
    property var bluetoothService: null
    required property var tokens
    required property var settingsService
    property var polkitService: null
    required property var wallpaperManager
    property var niri: null
    property string accentStatus: ""
    property string niriAccentError: ""
    property var accentCandidates: []
    property string strataError: ""
    property string strataNotice: ""
    property var remindCompanion: null
    property var notificationBridge: null
    property SettingsUsage usage: SettingsUsage { }

    property string userName: Quickshell.env("USER") || ""
    property var window: null
    property bool opened: false
    property int windowId: -1
    property var retiredIds: []
    property bool activationPending: false
    property int activationAttempts: 0
    property string error: ""
    readonly property var pageIndexes: ({
        home: 0, panels: 1, appearance: 2, weather: 3, wallpapers: 4,
        display: 5, sound: 6, power: 7, network: 8, localsend: 9,
        bluetooth: 10, mouse: 11, keyboard: 12, shortcuts: 13, start: 14,
        island: 15, lockscreen: 16, windows: 17, alttab: 18, workspaces: 19,
        defaults: 20, autostart: 21, updates: 22, about: 23, integrations: 24, naomi: 25,
        "naomi-look": 26, "naomi-place": 27,         capture: 28, "naomi-remind": 29, notifications: 30, polkit: 31
    })

    function open() { return show("") }
    function openPage(page) {
        if (!Object.prototype.hasOwnProperty.call(pageIndexes, page)) {
            error = "Неизвестный раздел настроек: " + page
            return false
        }
        return show(page)
    }
    function show(page) {
        error = ""
        if (!window) {
            window = windowFactory.createObject(root)
            if (!window) { error = "Не удалось создать окно настроек."; return false }
        }
        if (page !== "") window.setPage(pageIndexes[page])
        opened = true
        window.visible = true
        activationPending = true
        activationAttempts = 0
        activate()
        return true
    }
    function retireWindow() {
        if (windowId >= 0) retiredIds = retiredIds.concat([windowId])
        windowId = -1
    }
    function closed() {
        retireWindow()
        opened = false
        activationPending = false
        retry.stop()
    }
    function close() {
        if (window) window.visible = false
        closed()
    }
    function activate() {
        if (!opened || !window || !window.visible) return
        if (niri && niri.available) {
            const windows = niri.windows
            let match = null
            if (windowId >= 0) {
                // Once registered, identity is the exact compositor ID plus this PID.
                match = windows.find(w => w.id === windowId && w.pid === Quickshell.processId)
                if (!match) windowId = -1
            }
            if (!match) {
                const candidates = windows.filter(w => w.pid === Quickshell.processId
                    && w.appId === Quickshell.appId && w.title === "Nayori Settings"
                    && retiredIds.indexOf(w.id) < 0)
                if (candidates.length === 1) match = candidates[0]
            }
            if (match) {
                windowId = match.id
                niri.focusWindow(windowId)
                activationPending = false
                retry.stop()
                return
            }
        }
        window.requestActivation()
        if (activationPending && activationAttempts++ < 40) retry.restart()
        else activationPending = false
    }
    property Connections compositorEvents: Connections {
        target: root.niri
        function onWindowsChanged() { if (root.activationPending) root.activate() }
        function onAvailableChanged() { if (root.opened) { root.activationPending = true; root.activate() } }
    }
    property Timer activationRetry: Timer {
        id: retry
        interval: 100
        onTriggered: root.activate()
    }
    property Component windowFactory: Component {
        SettingsWindow {
            id: surface
            bluetoothService: root.bluetoothService
            settingsService: root.settingsService
            polkitService: root.polkitService
            settingsReady: root.settingsService.ready
            captureSettings: root.settingsService.values
            onCaptureSettingsChangedRequested: patch => root.settingsService.update(patch)
            mixerSources: root.settingsService.mixerSources
            onMixerSourcesChangedRequested: sources => root.settingsService.update({mixerSources: sources})
            companionTokens: root.companionTokens
            tokens: root.tokens
            wallpaperManager: root.wallpaperManager
            userName: root.userName
            recentKeys: {
                const recency = root.usage.lastVisited
                return root.usage.recentKeys(7)
            }
            frequentKeys: {
                const counts = root.usage.counts
                const recency = root.usage.lastVisited
                return root.usage.topKeys(4)
            }
            onSectionVisited: key => root.usage.record(key)
            avatarSource: userName ? "file:///var/lib/AccountsService/icons/" + encodeURIComponent(userName) : ""
            topReserved: root.settingsService.topReserved
            bottomReserved: root.settingsService.bottomReserved
            hideSecondaryIsland: root.settingsService.hideSecondaryIsland
            fullscreenIslandOutput: root.settingsService.fullscreenIslandOutput
            panelReservations: root.settingsService.panelReservations
            panelModes: root.settingsService.panelModes
            autoHideTop: root.settingsService.autoHideTop
            autoHideApps: root.settingsService.autoHideApps
            autoHideWorkspaces: root.settingsService.autoHideWorkspaces
            autoHideStatus: root.settingsService.autoHideStatus
            weatherCity: root.settingsService.weatherCity
            weatherRefreshMinutes: root.settingsService.weatherRefreshMinutes
            islandRotationEnabled: root.settingsService.islandRotationEnabled
            islandRotationSeconds: root.settingsService.islandRotationSeconds
            startIconStyle: root.settingsService.startIconStyle
            onStartIconStyleChangedRequested: style => root.settingsService.update({startIconStyle: style})
            updateService: root.updateService
            preferredTerminal: root.settingsService.preferredTerminal
            preferredFileManager: root.settingsService.preferredFileManager
            niri: root.niri
            colorScheme: root.settingsService.colorScheme
            onColorSchemeChangedRequested: scheme => root.settingsService.update({colorScheme: scheme})
            surfaceStyle: root.settingsService.surfaceStyle
            accentMode: root.settingsService.accentMode
            manualAccent: root.settingsService.manualAccent
            accentStatus: root.accentStatus
            niriAccentError: root.niriAccentError
            accentPreview: root.tokens.color.accent
            accentCandidates: root.accentCandidates
            companionStyle: root.settingsService.companionStyle
            onCompanionStyleChangedRequested: style => root.settingsService.update({companionStyle: style})
            companionEnabled: root.settingsService.companionEnabled
            onCompanionChangedRequested: enabled => root.settingsService.update({companionEnabled: enabled})
            companionDesktopOnly: root.settingsService.companionDesktopOnly
            onCompanionDesktopOnlyChangedRequested: enabled => root.settingsService.update({companionDesktopOnly: enabled})
            companionReactToPointer: root.settingsService.companionReactToPointer
            onCompanionReactToPointerChangedRequested: enabled => root.settingsService.update({companionReactToPointer: enabled})
            companionSystemLines: root.settingsService.companionSystemLines
            onCompanionSystemLinesChangedRequested: enabled => root.settingsService.update({companionSystemLines: enabled})
            fullscreenCompanionOutput: root.settingsService.fullscreenCompanionOutput
            onFullscreenCompanionOutputChangedRequested: output => root.settingsService.update({fullscreenCompanionOutput: output})
            companionScreen: root.settingsService.companionScreen
            onCompanionScreenChangedRequested: screen => root.settingsService.update({companionScreen: screen})
            companionSide: root.settingsService.companionSide
            onCompanionSideChangedRequested: side => root.settingsService.update({companionSide: side})
            remindCompanion: root.remindCompanion
            animationsEnabled: root.settingsService.animationsEnabled
            notificationsEnabled: root.settingsService.notificationsEnabled
            onNotificationsEnabledChangedRequested: enabled => root.settingsService.update({notificationsEnabled: enabled})
            receptionEnabled: root.notificationBridge ? root.notificationBridge.enabled : false
            receptionAvailable: root.notificationBridge ? root.notificationBridge.available : false
            receptionError: root.notificationBridge ? root.notificationBridge.diagnostic : ""
            onReceptionChangedRequested: enabled => root.settingsService.update({notificationReception: enabled})
            notificationSources: root.settingsService.notificationSources
            onSourceModeRequested: (key, mode) => {
                const next = NotificationPolicy.setMode(root.settingsService.notificationSources, key, mode)
                if (next.changed) root.settingsService.update({notificationSources: next.list})
            }
            dndManual: root.settingsService.notificationsDndManual
            dndUntil: root.settingsService.notificationsDndUntil
            onDndUntilRequested: until => root.settingsService.update({notificationsDndManual: false, notificationsDndUntil: until})
            onDndManualRequested: root.settingsService.update({notificationsDndManual: true, notificationsDndUntil: 0})
            onDndClearRequested: root.settingsService.update({notificationsDndManual: false, notificationsDndUntil: 0})
            settingsMessage: root.settingsService.message
            canRecover: root.settingsService.canRecover
            canRetry: root.settingsService.canRetry
            onReservationChanged: (top, bottom) => root.settingsService.update({topReserved: top, bottomReserved: bottom})
            onPanelReservationChangedRequested: (output, top, bottom) => root.settingsService.update({
                panelReservations: PanelModes.updatedReservation(root.settingsService.panelReservations, output, top, bottom)})
            onPanelModeChangedRequested: (output, part, mode) => root.settingsService.update({
                panelModes: PanelModes.updated(root.settingsService.panelModes, output, part, mode)})
            onAutoHideChangedRequested: (top, apps, workspaces, status) => root.settingsService.update({
                autoHideTop: top, autoHideApps: apps, autoHideWorkspaces: workspaces, autoHideStatus: status})
            onHideSecondaryIslandChangedRequested: hidden => root.settingsService.update({hideSecondaryIsland: hidden})
            onFullscreenIslandOutputChangedRequested: output => root.settingsService.update({fullscreenIslandOutput: output})
            onWeatherCityChangedRequested: city => root.settingsService.update({weatherCity: city})
            onWeatherRefreshMinutesChangedRequested: minutes => root.settingsService.update({weatherRefreshMinutes: minutes})
            onSurfaceStyleChangedRequested: style => root.settingsService.update({surfaceStyle: style})
            onAccentModeChangedRequested: mode => root.settingsService.update({accentMode: mode})
            onManualAccentChangedRequested: color => root.settingsService.update({manualAccent: color, accentMode: "manual"})
            onAccentResetRequested: root.settingsService.update({accentMode: "default", manualAccent: "#C0AFD1"})
            onAnimationsChangedRequested: enabled => root.settingsService.update({animationsEnabled: enabled})
            onIslandRotationEnabledChangedRequested: enabled => root.settingsService.update({islandRotationEnabled: enabled})
            onIslandRotationSecondsChangedRequested: seconds => root.settingsService.update({islandRotationSeconds: seconds})
            onPreferredTerminalChangedRequested: terminalId => root.settingsService.update({preferredTerminal: terminalId})
            onPreferredFileManagerChangedRequested: fileManagerId => root.settingsService.update({preferredFileManager: fileManagerId})
            niriColorIntegration: root.settingsService.niriColorIntegration
            onNiriColorIntegrationChangedRequested: enabled => root.settingsService.update({niriColorIntegration: enabled})
            strataThemeIntegration: root.settingsService.strataThemeIntegration
            onStrataThemeIntegrationChangedRequested: enabled => root.settingsService.update({strataThemeIntegration: enabled})
            strataError: root.strataError
            strataNotice: root.strataNotice
            onRecoverRequested: root.settingsService.recover()
            onRetryRequested: root.settingsService.flush(false)
            onCloseRequested: root.close()
            onClosed: root.closed()
            onVisibleChanged: if (!visible && root.opened) root.closed()
            Component.onDestruction: {
                if (root.window === surface) {
                    root.window = null
                    root.closed()
                }
            }
        }
    }
}
