pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Shell-owned: one UI instance, no storage and no dependency on panel geometry.
QtObject {
    id: root
    required property var tokens
    required property var settingsService
    required property var wallpaperManager
    property var niri: null
    property string userName: Quickshell.env("USER") || ""
    property var window: null
    property bool opened: false
    property int windowId: -1
    property var retiredIds: []
    property bool activationPending: false
    property int activationAttempts: 0
    property string error: ""
    readonly property var pageIndexes: ({ home: 0, panels: 1, appearance: 2, weather: 3, wallpapers: 4 })

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
            settingsReady: root.settingsService.ready
            tokens: root.tokens
            wallpaperManager: root.wallpaperManager
            userName: root.userName
            avatarSource: userName ? "file:///var/lib/AccountsService/icons/" + encodeURIComponent(userName) : ""
            topReserved: root.settingsService.topReserved
            bottomReserved: root.settingsService.bottomReserved
            hideSecondaryIsland: root.settingsService.hideSecondaryIsland
            autoHideTop: root.settingsService.autoHideTop
            autoHideApps: root.settingsService.autoHideApps
            autoHideWorkspaces: root.settingsService.autoHideWorkspaces
            autoHideStatus: root.settingsService.autoHideStatus
            weatherCity: root.settingsService.weatherCity
            weatherRefreshMinutes: root.settingsService.weatherRefreshMinutes
            animationsEnabled: root.settingsService.animationsEnabled
            settingsMessage: root.settingsService.message
            canRecover: root.settingsService.canRecover
            canRetry: root.settingsService.canRetry
            onReservationChanged: (top, bottom) => root.settingsService.update({topReserved: top, bottomReserved: bottom})
            onAutoHideChangedRequested: (top, apps, workspaces, status) => root.settingsService.update({
                autoHideTop: top, autoHideApps: apps, autoHideWorkspaces: workspaces, autoHideStatus: status})
            onHideSecondaryIslandChangedRequested: hidden => root.settingsService.update({hideSecondaryIsland: hidden})
            onWeatherCityChangedRequested: city => root.settingsService.update({weatherCity: city})
            onWeatherRefreshMinutesChangedRequested: minutes => root.settingsService.update({weatherRefreshMinutes: minutes})
            onAnimationsChangedRequested: enabled => root.settingsService.update({animationsEnabled: enabled})
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
