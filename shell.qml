pragma ComponentBehavior: Bound

//@ pragma UseQApplication
//@ pragma AppId nayori

import QtQuick
import Quickshell
import Quickshell.Io
import "tokens"
import "services/niri"
import "services/strata"
import "services/settings"
import "services/system"
import "services/weather"
import "surfaces/settings"
import "surfaces/panel"
import "services/canvas"
import "services/palette"
import "services/ui"
import "services/ui/StartRouting.js" as StartRouting
import "services/status/MixerSources.js" as MixerSources
import "services/ui/IslandRouting.js" as IslandRouting
import "services/island"
import "surfaces/canvas"
import "surfaces/companion"
import "services/clipboard"
import "services/shelf"
import "services/lock"
import "surfaces/lock"
import "surfaces/clipboard"
import "services/capture"
import "surfaces/capture"

ShellRoot {
    id: root

    readonly property var islandMusic: musicStore
    MusicService { id: musicStore }
    readonly property var islandAudio: audioReaction
    readonly property var islandNotifications: notificationModel
    AudioReaction { id: audioReaction }
    NotificationModel { id: notificationModel }
    Notifications { model: notificationModel }

    NayoriUpdate { id: nayoriUpdate }
    SettingsService { id: settingsStore }
    BluetoothService { id: bluetoothStore }
    readonly property var bluetoothService: bluetoothStore
    readonly property var settingsService: settingsStore
    readonly property var mixerSources: settingsStore.mixerSources
    property var pendingMixerSources: []
    function noteMixerSources(seen) {
        pendingMixerSources = Array.isArray(seen) ? seen : []
        if (!settingsStore.ready)
            return
        const merged = MixerSources.merge(settingsStore.mixerSources, pendingMixerSources)
        if (merged.changed)
            settingsStore.update({ mixerSources: merged.list })
    }
    Connections {
        target: settingsStore
        function onReadyChanged() {
            if (settingsStore.ready)
                root.noteMixerSources(root.pendingMixerSources)
        }
    }
    ClipboardService { id: clipboardStore }
    readonly property var shelfService: shelfStore
    ShelfService { id: shelfStore; clipboard: clipboardStore }
    readonly property var captureService: captureStore
    CaptureService { id: captureStore; settings: settingsStore; notifications: notificationModel }
    function beginCapture(kind) {
        if (lockService.locked) return
        const output = root.screenNamed(Niri.focusedOutput)
        if (output) captureStore.begin(kind, output.name)
    }
    IpcHandler {
        target: "capture"
        function screenshot(): void { root.beginCapture("shot") }
        function record(): void { root.beginCapture("video") }
        function stop(): void { captureStore.stop() }
        function pause(): void { captureStore.pause() }
        function cancel(): void { captureStore.cancel() }
    }
    Variants {
        model: captureStore.editing ? Quickshell.screens : []
        CaptureOverlay {
            required property var modelData
            screen: modelData
            outputName: modelData.name
            tokens: root.tokenSet
            service: captureStore
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (captureStore.state !== "idle" && !Quickshell.screens.some(s => s.name === captureStore.output)) {
                if (captureStore.recording) captureStore.stop()
                else captureStore.cancel()
            }
        }
    }
    Variants {
        model: captureStore.recording || captureStore.state === "starting" ? Quickshell.screens : []
        CaptureFrame {
            required property var modelData
            screen: modelData
            outputName: modelData.name
            tokens: root.tokenSet
            service: captureStore
        }
    }
    WeatherService {
        id: weatherStore
        enabled: settingsStore.ready
        city: settingsStore.weatherCity
        refreshMinutes: settingsStore.weatherRefreshMinutes
    }
    readonly property var weatherService: weatherStore

    IpcHandler {
        target: "canvas"
        function closeSettings(): void { settingsController.close() }
        function applyDefault(): void {
            wallpaperStore.apply("", "", "fill", true, true)
        }
        function openSettings(): void {
            root.openSettings("wallpapers")
        }
    }
    WallpaperManager { id: wallpaperStore }
    // Accent and dark neutrals follow the first screen, probeScreen. Never Niri.focusedOutput.
    // Naomi also samples the primary wallpaper with the default UI palette.
    AccentExtractor {
        id: accentExtractor
        // Naomi always follows the primary wallpaper, including with a manual UI accent.
        source: wallpaperStore.wallpaper(root.probeScreen ? root.probeScreen.name : "").source
    }
    Connections {
        target: wallpaperStore
        function onStateChanged() {
            accentExtractor.reload()
        }
    }
    function accentFilePath(value) {
        let text = String(value === undefined || value === null ? "" : value)
        if (text === "" || text === "undefined" || text.indexOf("file://") !== 0)
            return ""
        const hash = text.indexOf("#")
        if (hash >= 0)
            text = text.slice(0, hash)
        const query = text.indexOf("?")
        if (query >= 0)
            text = text.slice(0, query)
        text = text.slice("file://".length)
        try {
            text = decodeURIComponent(text)
        } catch (failure) {
            return ""
        }
        return text.charAt(0) === "/" ? text : ""
    }
    readonly property bool accentDerived: settingsStore.accentMode === "manual"
        || (settingsStore.accentMode === "automatic" && accentExtractor.ready && !accentExtractor.fallbackUsed)
    readonly property color accentSource: {
        if (settingsStore.accentMode === "manual")
            return settingsStore.manualAccent
        if (root.accentDerived)
            return accentExtractor.accent
        return "#C0AFD1"
    }
    readonly property string accentStatus: {
        const niriError = niriAccent.error
        let wallpaper = ""
        if (settingsStore.accentMode === "automatic" && accentExtractor.ready
                && accentExtractor.sourcePath === root.accentFilePath(accentExtractor.source)) {
            if (accentExtractor.error !== "")
                wallpaper = accentExtractor.error
            else if (accentExtractor.fallbackUsed)
                wallpaper = "На обоях нет выразительного цвета, акцент Nayori остаётся"
        }
        if (niriError === "")
            return wallpaper
        if (wallpaper === "")
            return niriError
        return wallpaper + " " + niriError
    }
    readonly property var accentCandidates: (settingsStore.accentMode === "automatic" || settingsStore.accentMode === "manual")
        ? accentExtractor.candidates : []
    readonly property bool neutralDerived: (settingsStore.accentMode === "automatic" || settingsStore.accentMode === "manual")
        && accentExtractor.ready && !accentExtractor.neutralFallbackUsed
    Tokens {
        id: tokens
        animationsEnabled: settingsStore.animationsEnabled
        colorScheme: settingsStore.colorScheme
        surfaceStyle: settingsStore.surfaceStyle
        accentSource: root.accentSource
        accentDerived: root.accentDerived
        backgroundSource: accentExtractor.background
        surfaceSource: accentExtractor.surface
        surfaceAltSource: accentExtractor.surfaceAlt
        neutralDerived: root.neutralDerived
    }
    // Тот же tokens.color.accent. В niri уходят только уже существующие акцентные цвета.
    NiriAccent {
        id: niriAccent
        enabled: settingsStore.niriColorIntegration
        accent: tokens.color.accent
        settled: settingsStore.ready && (settingsStore.accentMode !== "automatic" || accentExtractor.ready)
    }
    Tokens {
        id: naomiTokens
        colorScheme: settingsStore.colorScheme
        animationsEnabled: settingsStore.animationsEnabled
        accentSource: accentExtractor.accent
        accentDerived: accentExtractor.ready && !accentExtractor.fallbackUsed
    }
    // Те же токены, что у оболочки. Strata получает файл темы, когда цвета уже посчитаны.
    StrataTheme {
        id: strataTheme
        enabled: settingsStore.strataThemeIntegration
        settled: settingsStore.ready && (settingsStore.accentMode !== "automatic" || accentExtractor.ready)
        background: tokens.color.background
        surface: tokens.color.surface
        surfaceAlt: tokens.color.surfaceAlt
        text: tokens.color.text
        textMuted: tokens.color.textMuted
        accent: tokens.color.accent
        accentSoft: tokens.color.accentSoft
        secondary: tokens.color.secondary
    }
    Variants {
        model: wallpaperStore.enabled ? Quickshell.screens : []
        WallpaperWindow {
            required property var modelData
            screen: modelData
            manager: wallpaperStore
            tokens: root.tokenSet
        }
    }
    // Blurred copy of each output's canvas wallpaper. The sharp desktop surface
    // stays on nayori-canvas. This layer is mapped only after niri has loaded
    // the nayori-overview backdrop rule, and it is not a second desktop.
    OverviewBlur {
        id: overviewBlur
        manager: wallpaperStore
        active: wallpaperStore.enabled
    }
    OverviewRule { id: overviewRule }
    Variants {
        model: wallpaperStore.enabled && overviewRule.ruleLive ? Quickshell.screens : []
        OverviewWindow {
            required property var modelData
            screen: modelData
            blur: overviewBlur
            onImageFailed: function (path) {
                overviewBlur.revert(modelData.name, path)
            }
        }
    }

    LazyLoader {
        id: companionHost
        active: settingsStore.ready && settingsStore.companionEnabled && root.probeScreen !== null
        component: CompanionWindow {
            companionStyle: settingsStore.companionStyle
            tokens: naomiTokens
            animationsEnabled: settingsStore.animationsEnabled
            desktopOnly: settingsStore.companionDesktopOnly
            reactToPointer: settingsStore.companionReactToPointer
            systemLines: settingsStore.companionSystemLines
            screen: root.screenNamed(IslandRouting.companionOutput(root.outputNames, settingsStore.companionScreen, root.primaryFullscreen, settingsStore.fullscreenCompanionOutput))
            side: settingsStore.companionSide
            bottomInset: Math.max(88, settingsStore.bottomReserved + 16)
        }
    }

    // Монитор, на котором сейчас открыто меню Пуск, или "". Меню одно на все мониторы:
    // Super и IPC сначала закрывают уже открытое, а не открывают второе на «активном» мониторе.
    property string startMenuOutput: ""
    function startMenuTarget() {
        const names = []
        for (let i = 0; i < Quickshell.screens.length; ++i)
            names.push(Quickshell.screens[i].name)
        return StartRouting.target(root.startMenuOutput, names, Niri.focusedOutput)
    }
    function toggleStartMenu() {
        clipboardStore.cancelPaste()
        root.clipboardOpened = false
        const name = root.startMenuTarget()
        if (name !== "")
            root.startMenuToggleRequested(name)
    }
    SuperTap {
        onTapped: root.toggleStartMenu()
    }
    signal startMenuToggleRequested(string outputName)
    IpcHandler {
        target: "start"
        function toggle(): void {
            root.toggleStartMenu()
        }
    }

    readonly property var tokenSet: tokens
    SessionEntrance {
        tokens: root.tokenSet
        ready: settingsStore.ready
        enabled: !lockService.locked
    }
    LockService {
        id: lockService
        tokens: root.tokenSet
        wallpapers: wallpaperStore
        music: musicStore
        primaryOutput: root.probeScreen ? root.probeScreen.name : ""
    }
    LoginTheme {
        tokens: root.tokenSet
        wallpapers: wallpaperStore
        primaryOutput: root.probeScreen ? root.probeScreen.name : ""
        outputNames: Quickshell.screens.map(screen => screen.name)
        settled: settingsStore.ready && (settingsStore.accentMode !== "automatic" || accentExtractor.ready)
    }
    property bool launcherOpened: false
    readonly property bool settingsOpened: settingsController.opened
    function openSettings(page): bool {
        clipboardStore.cancelPaste()
        root.clipboardOpened = false
        root.launcherOpened = false
        return settingsController.openPage(page || "home")
    }
    readonly property string weatherCity: settingsStore.weatherCity
    readonly property bool hideSecondaryIsland: settingsStore.hideSecondaryIsland
    readonly property string fullscreenIslandOutput: settingsStore.fullscreenIslandOutput
    readonly property var panelReservations: settingsStore.panelReservations
    readonly property var panelModes: settingsStore.panelModes
    readonly property bool autoHideTop: settingsStore.autoHideTop
    readonly property bool autoHideApps: settingsStore.autoHideApps
    readonly property bool autoHideWorkspaces: settingsStore.autoHideWorkspaces
    readonly property bool autoHideStatus: settingsStore.autoHideStatus
    readonly property int topReserved: settingsStore.topReserved
    readonly property int bottomReserved: settingsStore.bottomReserved
    readonly property bool islandRotationEnabled: settingsStore.islandRotationEnabled
    readonly property int islandRotationSeconds: settingsStore.islandRotationSeconds
    readonly property string startIconStyle: settingsStore.startIconStyle
    readonly property string preferredTerminal: settingsStore.preferredTerminal
    readonly property string preferredFileManager: settingsStore.preferredFileManager
    readonly property string userName: Quickshell.env("USER") || ""

    function screenNamed(name) {
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; ++i) {
            const screen = screens[i]
            if (screen && screen.name === name)
                return screen
        }
        return root.probeScreen
    }
    property bool locatingLauncher: false
    function finishLauncherLocation(screen) {
        if (!root.locatingLauncher) return
        root.locatingLauncher = false
        launcherLocationTimeout.stop()
        if (!lockService.locked && screen && Quickshell.screens.indexOf(screen) >= 0) {
            root.overlayScreen = screen
            root.launcherOpened = true
        }
    }
    function toggleLauncher() {
        if (lockService.locked) return
        clipboardStore.cancelPaste()
        root.clipboardOpened = false
        if (root.launcherOpened || root.locatingLauncher) {
            root.launcherOpened = false
            root.locatingLauncher = false
            launcherLocationTimeout.stop()
            return
        }
        root.locatingLauncher = true
        launcherLocationTimeout.restart()
    }
    Timer {
        id: launcherLocationTimeout
        interval: 250
        onTriggered: root.finishLauncherLocation(root.screenNamed(Niri.focusedOutput))
    }
    Variants {
        model: root.locatingLauncher ? Quickshell.screens : []
        LauncherPointerProbe {
            required property var modelData
            screen: modelData
            onLocated: output => root.finishLauncherLocation(output)
        }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggleLauncher() }
        function close(): void {
            root.locatingLauncher = false
            launcherLocationTimeout.stop()
            root.launcherOpened = false
        }
    }

    property bool clipboardOpened: false
    property bool clipboardPresenting: false
    onClipboardOpenedChanged: {
        if (root.clipboardOpened) root.clipboardPresenting = true
        else if (root.clipboardOutput === "") root.clipboardPresenting = false
    }
    property string clipboardOutput: ""
    property point clipboardAnchor: Qt.point(0, 0)
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.clipboardPresenting && root.clipboardOutput !== ""
                    && !Quickshell.screens.some(output => output.name === root.clipboardOutput)) {
                root.clipboardOpened = false
                root.clipboardPresenting = false
            }
        }
    }
    function locateClipboard(output, x, y) {
        if (!root.clipboardOpened || root.clipboardOutput !== "") return
        root.clipboardAnchor = Qt.point(x, y)
        root.clipboardOutput = output
        clipboardAnchorTimeout.stop()
    }
    function toggleClipboard() {
        if (root.clipboardOpened) { root.clipboardOpened = false; return }
        clipboardStore.cancelPaste()
        // Reverse an in-progress exit on the same surface and anchor.
        if (root.clipboardPresenting) { root.clipboardOpened = true; return }
        root.launcherOpened = false
        if (root.startMenuOutput !== "") root.startMenuToggleRequested(root.startMenuOutput)
        root.clipboardOutput = ""
        root.clipboardOpened = true
        clipboardAnchorTimeout.restart()
    }
    Timer {
        id: clipboardAnchorTimeout
        interval: 250
        onTriggered: {
            if (!root.clipboardOpened || root.clipboardOutput !== "") return
            const output = root.screenNamed(Niri.focusedOutput)
            if (output) root.locateClipboard(output.name,
                Math.max(12, (output.width - 580) / 2 - 12), Math.max(12, (output.height - 520) / 2 - 12))
            else root.clipboardOpened = false
        }
    }
    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggleClipboard() }
        function close(): void { root.clipboardOpened = false }
    }
    Variants {
        model: root.clipboardPresenting ? Quickshell.screens : []
        ClipboardWindow {
            required property var modelData
            screen: modelData
            tokens: root.tokenSet
            store: clipboardStore
            host: root
            onCloseRequested: root.clipboardOpened = false
            onCloseFinished: if (!root.clipboardOpened) {
                root.clipboardPresenting = false
                if (root.launcherOpened || root.settingsOpened || root.startMenuOutput !== "") clipboardStore.cancelPaste()
                else clipboardStore.finishClose()
            }
        }
    }

    SettingsController {
        id: settingsController
        bluetoothService: bluetoothStore
        updateService: nayoriUpdate
        companionTokens: naomiTokens
        remindCompanion: kind => companionHost.item ? companionHost.item.remind(kind) : false
        tokens: root.tokenSet
        settingsService: settingsStore
        wallpaperManager: wallpaperStore
        niri: Niri
        accentStatus: root.accentStatus
        accentCandidates: root.accentCandidates
        strataError: strataTheme.error
        strataNotice: strataTheme.notice
    }
    IpcHandler {
        target: "settings"
        function open(): bool {
            root.clipboardOpened = false
            root.launcherOpened = false
            return settingsController.open()
        }
        function openPage(page: string): bool { return root.openSettings(page) }
        function close(): void { settingsController.close() }
    }

    // Each output owns independent panels. The first output is the primary screen; all outputs get their own panels.
    readonly property var probeScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    FullscreenGuard {
        id: primaryFullscreenGuard
        screen: root.probeScreen
        tokens: root.tokenSet
    }
    readonly property bool primaryFullscreen: primaryFullscreenGuard.blocked
    readonly property var outputNames: {
        const names = []
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; ++i) {
            const screen = screens[i]
            names.push(screen && screen.name ? screen.name : "")
        }
        return names
    }
    property var overlayScreen: probeScreen
    readonly property var currentOverlayScreen: Quickshell.screens.indexOf(overlayScreen) >= 0
        ? overlayScreen : probeScreen
    readonly property bool niriLive: Niri.available

    Variants {
        model: Quickshell.screens
        ScreenPanels {
            required property var modelData
            panelScreen: modelData
            shellState: root
        }
    }
}
