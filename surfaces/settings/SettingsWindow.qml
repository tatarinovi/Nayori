pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Window

// Ordinary compositor-managed toplevel. No relationship to any panel surface.
FloatingWindow {
    id: root
    property var wallpaperManager: null
    required property var tokens
    property int topReserved: 0
    property int bottomReserved: 0
    property bool hideSecondaryIsland: false
    signal hideSecondaryIslandChangedRequested(bool hidden)
    property bool autoHideTop: false
    property bool autoHideApps: false
    property bool autoHideWorkspaces: false
    property bool autoHideStatus: false
    property string userName: ""
    property string avatarSource: ""
    property var frequentKeys: []
    property var recentKeys: []
    signal sectionVisited(string key)
    property string weatherCity: ""
    property int weatherRefreshMinutes: 15
    property bool islandRotationEnabled: true
    property int islandRotationSeconds: 15
    property string startIconStyle: "current"
    signal startIconStyleChangedRequested(string style)
    property string preferredTerminal: "kitty"
    property string preferredFileManager: "org.gnome.Nautilus"
    property var niri: null
    property bool settingsReady: true
    property string surfaceStyle: "solid"
    signal surfaceStyleChangedRequested(string style)
    property bool animationsEnabled: true
    signal animationsChangedRequested(bool enabled)
    signal islandRotationEnabledChangedRequested(bool enabled)
    signal islandRotationSecondsChangedRequested(int seconds)
    signal preferredTerminalChangedRequested(string terminalId)
    signal preferredFileManagerChangedRequested(string fileManagerId)
    property string settingsMessage: ""
    property bool canRecover: false
    property bool canRetry: false
    signal recoverRequested()
    signal retryRequested()
    property int initialPage: 0
    signal weatherCityChangedRequested(string city)
    signal weatherRefreshMinutesChangedRequested(int minutes)
    signal reservationChanged(int top, int bottom)
    signal autoHideChangedRequested(bool top, bool apps, bool workspaces, bool status)
    signal closeRequested()

    title: "Nayori Settings"
    visible: false
    implicitWidth: 1100
    implicitHeight: 760
    minimumSize: Qt.size(720, 560)
    color: "transparent"
    surfaceFormat.opaque: false
    Region { id: glassRegion; item: root.contentItem }
    BackgroundEffect.blurRegion: root.tokens.frosted ? glassRegion : null

    function requestActivation() {
        const nativeWindow = contentItem.Window.window
        if (nativeWindow) nativeWindow.requestActivate()
    }
    property bool shownOnce: false
    function setPage(page) {
        settings.currentPage = page
    }
    readonly property int selectedPage: settings.currentPage

    Settings {
        id: settings
        enabled: root.settingsReady
        tokens: root.tokens
        wallpaperManager: root.wallpaperManager
        topReserved: root.topReserved
        bottomReserved: root.bottomReserved
        hideSecondaryIsland: root.hideSecondaryIsland
        onHideSecondaryIslandChangedRequested: function(hidden) { root.hideSecondaryIslandChangedRequested(hidden) }
        autoHideTop: root.autoHideTop
        autoHideApps: root.autoHideApps
        autoHideWorkspaces: root.autoHideWorkspaces
        autoHideStatus: root.autoHideStatus
        userName: root.userName
        avatarSource: root.avatarSource
        frequentKeys: root.frequentKeys
        recentKeys: root.recentKeys
        onSectionVisited: key => root.sectionVisited(key)
        weatherCity: root.weatherCity
        weatherRefreshMinutes: root.weatherRefreshMinutes
        islandRotationEnabled: root.islandRotationEnabled
        islandRotationSeconds: root.islandRotationSeconds
        startIconStyle: root.startIconStyle
        onStartIconStyleChangedRequested: style => root.startIconStyleChangedRequested(style)
        preferredTerminal: root.preferredTerminal
        preferredFileManager: root.preferredFileManager
        niri: root.niri
        currentPage: root.initialPage
        surfaceStyle: root.surfaceStyle
        onSurfaceStyleChangedRequested: style => root.surfaceStyleChangedRequested(style)
        animationsEnabled: root.animationsEnabled
        onAnimationsChangedRequested: enabled => root.animationsChangedRequested(enabled)
        onIslandRotationEnabledChangedRequested: enabled => root.islandRotationEnabledChangedRequested(enabled)
        onIslandRotationSecondsChangedRequested: seconds => root.islandRotationSecondsChangedRequested(seconds)
        onPreferredTerminalChangedRequested: terminalId => root.preferredTerminalChangedRequested(terminalId)
        onPreferredFileManagerChangedRequested: fileManagerId => root.preferredFileManagerChangedRequested(fileManagerId)
        settingsMessage: root.settingsMessage
        canRecover: root.canRecover
        canRetry: root.canRetry
        onRecoverRequested: root.recoverRequested()
        onRetryRequested: root.retryRequested()
        anchors.fill: parent
        onCloseRequested: root.closeRequested()
        onReservationChanged: function(top, bottom) { root.reservationChanged(top, bottom) }
        onAutoHideChangedRequested: function(top, apps, workspaces, status) { root.autoHideChangedRequested(top, apps, workspaces, status) }
        onWeatherCityChangedRequested: function(city) { root.weatherCityChangedRequested(city) }
        onWeatherRefreshMinutesChangedRequested: minutes => root.weatherRefreshMinutesChangedRequested(minutes)
        Component.onCompleted: Qt.callLater(focusInput)
    }

    onClosed: visible = false

    onVisibleChanged: {
        if (visible) {
            shownOnce = true
            Qt.callLater(settings.focusInput)
        }
    }
}
