pragma ComponentBehavior: Bound

//@ pragma UseQApplication
//@ pragma AppId nayori

import QtQuick
import Quickshell
import Quickshell.Io
import "tokens"
import "services/niri"
import "services/settings"
import "services/weather"
import "surfaces/launcher"
import "surfaces/settings"
import "surfaces/panel"
import "services/canvas"
import "services/island"
import "surfaces/canvas"

ShellRoot {
    id: root

    readonly property var islandAudio: audioReaction
    readonly property var islandNotifications: notificationModel
    AudioReaction { id: audioReaction }
    NotificationModel { id: notificationModel }
    Notifications { model: notificationModel }

    SettingsService { id: settingsStore }
    WeatherService {
        id: weatherStore
        enabled: settingsStore.ready
        city: settingsStore.weatherCity
        refreshMinutes: settingsStore.weatherRefreshMinutes
    }
    readonly property var weatherService: weatherStore
    Tokens {
        id: tokens
        animationsEnabled: settingsStore.animationsEnabled
    }

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
    Variants {
        model: wallpaperStore.enabled ? Quickshell.screens : []
        WallpaperWindow {
            required property var modelData
            screen: modelData
            manager: wallpaperStore
            tokens: root.tokenSet
        }
    }

    readonly property var tokenSet: tokens
    property bool launcherOpened: false
    readonly property bool settingsOpened: settingsController.opened
    function openSettings(page): bool {
        root.launcherOpened = false
        return settingsController.openPage(page || "home")
    }
    readonly property string weatherCity: settingsStore.weatherCity
    readonly property bool hideSecondaryIsland: settingsStore.hideSecondaryIsland
    readonly property bool autoHideTop: settingsStore.autoHideTop
    readonly property bool autoHideApps: settingsStore.autoHideApps
    readonly property bool autoHideWorkspaces: settingsStore.autoHideWorkspaces
    readonly property bool autoHideStatus: settingsStore.autoHideStatus
    readonly property int topReserved: settingsStore.topReserved
    readonly property int bottomReserved: settingsStore.bottomReserved
    readonly property bool islandRotationEnabled: settingsStore.islandRotationEnabled
    readonly property int islandRotationSeconds: settingsStore.islandRotationSeconds
    readonly property string preferredTerminal: settingsStore.preferredTerminal
    readonly property string preferredFileManager: settingsStore.preferredFileManager
    readonly property string userName: Quickshell.env("USER") || ""

    LazyLoader {
        active: root.launcherOpened && root.currentOverlayScreen !== null
        LauncherWindow {
            screen: root.currentOverlayScreen
            tokens: root.tokenSet
            onCloseRequested: root.launcherOpened = false
        }
    }

    SettingsController {
        id: settingsController
        tokens: root.tokenSet
        settingsService: settingsStore
        wallpaperManager: wallpaperStore
        niri: Niri
    }
    IpcHandler {
        target: "settings"
        function open(): bool {
            root.launcherOpened = false
            return settingsController.open()
        }
        function openPage(page: string): bool { return root.openSettings(page) }
        function close(): void { settingsController.close() }
    }

    // Each output owns independent panels. The first output is the primary screen; all outputs get their own panels.
    readonly property var probeScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
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
