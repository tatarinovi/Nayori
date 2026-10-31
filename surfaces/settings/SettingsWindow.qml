pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Window

// Ordinary compositor-managed toplevel. No relationship to any panel surface.
FloatingWindow {
    id: root
    property var wallpaperManager: null
    property var companionTokens: tokens
    property var bluetoothService: null
    property var settingsService: null
    property var polkitService: null
    required property var tokens
    property var captureSettings: ({})
    signal captureSettingsChangedRequested(var patch)
    property var mixerSources: []
    signal mixerSourcesChangedRequested(var sources)
    property int topReserved: 0
    property int bottomReserved: 0
    property bool hideSecondaryIsland: false
    signal hideSecondaryIslandChangedRequested(bool hidden)
    property string fullscreenIslandOutput: ""
    signal fullscreenIslandOutputChangedRequested(string output)
    property var panelReservations: ({})
    property var panelModes: ({})
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
    property var updateService: null
    property string preferredTerminal: "kitty"
    property string preferredFileManager: "org.gnome.Nautilus"
    property var niri: null
    property bool settingsReady: true
    property string colorScheme: "dark"
    signal colorSchemeChangedRequested(string scheme)
    property string surfaceStyle: "solid"
    signal surfaceStyleChangedRequested(string style)
    property string accentMode: "default"
    signal accentModeChangedRequested(string mode)
    property string manualAccent: "#C0AFD1"
    signal manualAccentChangedRequested(string color)
    property string accentStatus: ""
    property string niriAccentError: ""
    property color accentPreview: "#C0AFD1"
    property var accentCandidates: []
    signal accentResetRequested()
    property string companionStyle: "current"
    signal companionStyleChangedRequested(string style)
    property bool companionEnabled: false
    signal companionChangedRequested(bool enabled)
    property bool companionDesktopOnly: false
    signal companionDesktopOnlyChangedRequested(bool enabled)
    property bool companionReactToPointer: true
    signal companionReactToPointerChangedRequested(bool enabled)
    property bool companionSystemLines: true
    signal companionSystemLinesChangedRequested(bool enabled)
    property string fullscreenCompanionOutput: ""
    signal fullscreenCompanionOutputChangedRequested(string output)
    property string companionScreen: "primary"
    signal companionScreenChangedRequested(string screen)
    property string companionSide: "right"
    signal companionSideChangedRequested(string side)
    property var remindCompanion: null
    property bool animationsEnabled: true
    signal animationsChangedRequested(bool enabled)
    property bool notificationsEnabled: true
    signal notificationsEnabledChangedRequested(bool enabled)
    property bool receptionEnabled: false
    property bool receptionAvailable: false
    property string receptionError: ""
    signal receptionChangedRequested(bool enabled)
    property var notificationSources: []
    signal sourceModeRequested(string key, string mode)
    property bool dndManual: false
    property double dndUntil: 0
    signal dndUntilRequested(double until)
    signal dndManualRequested()
    signal dndClearRequested()
    signal islandRotationEnabledChangedRequested(bool enabled)
    signal islandRotationSecondsChangedRequested(int seconds)
    signal preferredTerminalChangedRequested(string terminalId)
    signal preferredFileManagerChangedRequested(string fileManagerId)
    property bool niriColorIntegration: true
    signal niriColorIntegrationChangedRequested(bool enabled)
    property bool strataThemeIntegration: true
    signal strataThemeIntegrationChangedRequested(bool enabled)
    property string strataError: ""
    property string strataNotice: ""
    property string settingsMessage: ""
    property bool canRecover: false
    property bool canRetry: false
    signal recoverRequested()
    signal retryRequested()
    property int initialPage: 0
    signal weatherCityChangedRequested(string city)
    signal weatherRefreshMinutesChangedRequested(int minutes)
    signal reservationChanged(int top, int bottom)
    signal panelReservationChangedRequested(string output, int top, int bottom)
    signal panelModeChangedRequested(string output, string part, string mode)
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
        bluetoothService: root.bluetoothService
        settingsService: root.settingsService
        polkitService: root.polkitService
        id: settings
        captureSettings: root.captureSettings
        onCaptureSettingsChangedRequested: patch => root.captureSettingsChangedRequested(patch)
        mixerSources: root.mixerSources
        onMixerSourcesChangedRequested: sources => root.mixerSourcesChangedRequested(sources)
        enabled: root.settingsReady
        companionTokens: root.companionTokens
        tokens: root.tokens
        wallpaperManager: root.wallpaperManager
        topReserved: root.topReserved
        bottomReserved: root.bottomReserved
        hideSecondaryIsland: root.hideSecondaryIsland
        onHideSecondaryIslandChangedRequested: function(hidden) { root.hideSecondaryIslandChangedRequested(hidden) }
        fullscreenIslandOutput: root.fullscreenIslandOutput
        onFullscreenIslandOutputChangedRequested: function(output) { root.fullscreenIslandOutputChangedRequested(output) }
        panelReservations: root.panelReservations
        panelModes: root.panelModes
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
        updateService: root.updateService
        preferredTerminal: root.preferredTerminal
        preferredFileManager: root.preferredFileManager
        niri: root.niri
        currentPage: root.initialPage
        colorScheme: root.colorScheme
        onColorSchemeChangedRequested: scheme => root.colorSchemeChangedRequested(scheme)
        surfaceStyle: root.surfaceStyle
        onSurfaceStyleChangedRequested: style => root.surfaceStyleChangedRequested(style)
        accentMode: root.accentMode
        onAccentModeChangedRequested: mode => root.accentModeChangedRequested(mode)
        manualAccent: root.manualAccent
        onManualAccentChangedRequested: color => root.manualAccentChangedRequested(color)
        accentStatus: root.accentStatus
        niriAccentError: root.niriAccentError
        accentPreview: root.accentPreview
        accentCandidates: root.accentCandidates
        onAccentResetRequested: root.accentResetRequested()
        companionStyle: root.companionStyle
        onCompanionStyleChangedRequested: style => root.companionStyleChangedRequested(style)
        companionEnabled: root.companionEnabled
        onCompanionChangedRequested: enabled => root.companionChangedRequested(enabled)
        companionDesktopOnly: root.companionDesktopOnly
        onCompanionDesktopOnlyChangedRequested: enabled => root.companionDesktopOnlyChangedRequested(enabled)
        companionReactToPointer: root.companionReactToPointer
        onCompanionReactToPointerChangedRequested: enabled => root.companionReactToPointerChangedRequested(enabled)
        companionSystemLines: root.companionSystemLines
        onCompanionSystemLinesChangedRequested: enabled => root.companionSystemLinesChangedRequested(enabled)
        fullscreenCompanionOutput: root.fullscreenCompanionOutput
        onFullscreenCompanionOutputChangedRequested: output => root.fullscreenCompanionOutputChangedRequested(output)
        companionScreen: root.companionScreen
        onCompanionScreenChangedRequested: screen => root.companionScreenChangedRequested(screen)
        companionSide: root.companionSide
        onCompanionSideChangedRequested: side => root.companionSideChangedRequested(side)
        remindCompanion: root.remindCompanion
        animationsEnabled: root.animationsEnabled
        onAnimationsChangedRequested: enabled => root.animationsChangedRequested(enabled)
        notificationsEnabled: root.notificationsEnabled
        onNotificationsEnabledChangedRequested: enabled => root.notificationsEnabledChangedRequested(enabled)
        receptionEnabled: root.receptionEnabled
        receptionAvailable: root.receptionAvailable
        receptionError: root.receptionError
        onReceptionChangedRequested: enabled => root.receptionChangedRequested(enabled)
        notificationSources: root.notificationSources
        onSourceModeRequested: (key, mode) => root.sourceModeRequested(key, mode)
        dndManual: root.dndManual
        dndUntil: root.dndUntil
        onDndUntilRequested: until => root.dndUntilRequested(until)
        onDndManualRequested: root.dndManualRequested()
        onDndClearRequested: root.dndClearRequested()
        onIslandRotationEnabledChangedRequested: enabled => root.islandRotationEnabledChangedRequested(enabled)
        onIslandRotationSecondsChangedRequested: seconds => root.islandRotationSecondsChangedRequested(seconds)
        onPreferredTerminalChangedRequested: terminalId => root.preferredTerminalChangedRequested(terminalId)
        onPreferredFileManagerChangedRequested: fileManagerId => root.preferredFileManagerChangedRequested(fileManagerId)
        niriColorIntegration: root.niriColorIntegration
        onNiriColorIntegrationChangedRequested: enabled => root.niriColorIntegrationChangedRequested(enabled)
        strataThemeIntegration: root.strataThemeIntegration
        onStrataThemeIntegrationChangedRequested: enabled => root.strataThemeIntegrationChangedRequested(enabled)
        strataError: root.strataError
        strataNotice: root.strataNotice
        settingsMessage: root.settingsMessage
        canRecover: root.canRecover
        canRetry: root.canRetry
        onRecoverRequested: root.recoverRequested()
        onRetryRequested: root.retryRequested()
        anchors.fill: parent
        onCloseRequested: root.closeRequested()
        onReservationChanged: function(top, bottom) { root.reservationChanged(top, bottom) }
        onPanelReservationChangedRequested: (output, top, bottom) => root.panelReservationChangedRequested(output, top, bottom)
        onPanelModeChangedRequested: (output, part, mode) => root.panelModeChangedRequested(output, part, mode)
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
