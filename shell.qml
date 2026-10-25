pragma ComponentBehavior: Bound

//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "tokens"
import "services/niri"
import "services/settings"
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

    SettingsService { id: settingsService }
    Tokens {
        id: tokens
        motion.off: !settingsService.animationsEnabled
    }

    IpcHandler {
        target: "canvas"
        function closeSettings(): void { root.settingsOpened = false }
        function applyDefault(): void {
            wallpaperManager.apply("", "", "fill", true, true)
        }
        function openSettings(): void {
            root.launcherOpened = false
            root.settingsPage = 4
            root.settingsOpened = true
        }
    }
    WallpaperManager { id: wallpaperManager }
    Variants {
        model: wallpaperManager.enabled ? Quickshell.screens : []
        WallpaperWindow {
            required property var modelData
            screen: modelData
            manager: wallpaperManager
            tokens: root.tokenSet
        }
    }

    readonly property var tokenSet: tokens
    property bool launcherOpened: false
    property bool settingsOpened: false
    property int settingsPage: 0
    readonly property string weatherCity: settingsService.weatherCity
    readonly property bool hideSecondaryIsland: settingsService.hideSecondaryIsland
    readonly property bool autoHideTop: settingsService.autoHideTop
    readonly property bool autoHideApps: settingsService.autoHideApps
    readonly property bool autoHideWorkspaces: settingsService.autoHideWorkspaces
    readonly property bool autoHideStatus: settingsService.autoHideStatus
    readonly property int topReserved: settingsService.topReserved
    readonly property int bottomReserved: settingsService.bottomReserved
    readonly property string userName: Quickshell.env("USER") || ""

    LazyLoader {
        active: root.launcherOpened && root.currentOverlayScreen !== null
        LauncherWindow {
            screen: root.currentOverlayScreen
            tokens: root.tokenSet
            onCloseRequested: root.launcherOpened = false
        }
    }

    LazyLoader {
        active: root.settingsOpened && root.currentOverlayScreen !== null
        SettingsWindow {
            screen: root.currentOverlayScreen
            tokens: root.tokenSet
            initialPage: root.settingsPage
            animationsEnabled: settingsService.animationsEnabled
            onAnimationsChangedRequested: enabled => settingsService.update({ animationsEnabled: enabled })
            settingsMessage: settingsService.message
            canRecover: settingsService.canRecover
            canRetry: settingsService.canRetry
            onRecoverRequested: settingsService.recover()
            onRetryRequested: settingsService.flush(false)
            wallpaperManager: wallpaperManager
            hideSecondaryIsland: root.hideSecondaryIsland
            onHideSecondaryIslandChangedRequested: function(hidden) { settingsService.update({ hideSecondaryIsland: hidden }) }
            autoHideTop: root.autoHideTop
            autoHideApps: root.autoHideApps
            autoHideWorkspaces: root.autoHideWorkspaces
            autoHideStatus: root.autoHideStatus
            onAutoHideChangedRequested: function(top, apps, workspaces, status) {
                settingsService.update({ autoHideTop: top, autoHideApps: apps,
                    autoHideWorkspaces: workspaces, autoHideStatus: status })
            }
            weatherCity: root.weatherCity
            onWeatherCityChangedRequested: function(city) { settingsService.update({ weatherCity: city }) }
            userName: root.userName
            avatarSource: root.userName !== ""
                ? "file:///var/lib/AccountsService/icons/" + encodeURIComponent(root.userName) : ""
            topReserved: root.topReserved
            bottomReserved: root.bottomReserved
            onReservationChanged: function(top, bottom) {
                settingsService.update({ topReserved: top, bottomReserved: bottom })
            }
            onCloseRequested: root.settingsOpened = false
        }
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
