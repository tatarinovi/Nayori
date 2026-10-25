pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// The shell creates this overlay only while settings are open.
PanelWindow {
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
    property string weatherCity: ""
    property bool animationsEnabled: true
    signal animationsChangedRequested(bool enabled)
    property string settingsMessage: ""
    property bool canRecover: false
    property bool canRetry: false
    signal recoverRequested()
    signal retryRequested()
    property int initialPage: 0
    signal weatherCityChangedRequested(string city)
    signal reservationChanged(int top, int bottom)
    signal autoHideChangedRequested(bool top, bool apps, bool workspaces, bool status)
    signal closeRequested()

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nayori-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: function(mouse) {
            if (mouse.x < settings.x || mouse.x > settings.x + settings.width
                    || mouse.y < settings.y || mouse.y > settings.y + settings.height)
                root.closeRequested()
        }
        onWheel: function(wheel) { wheel.accepted = true }
    }

    Settings {
        id: settings
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
        weatherCity: root.weatherCity
        currentPage: root.initialPage
        animationsEnabled: root.animationsEnabled
        onAnimationsChangedRequested: enabled => root.animationsChangedRequested(enabled)
        settingsMessage: root.settingsMessage
        canRecover: root.canRecover
        canRetry: root.canRetry
        onRecoverRequested: root.recoverRequested()
        onRetryRequested: root.retryRequested()
        width: Math.min(700, Math.max(1, parent.width - root.tokens.spacing.large * 2))
        height: Math.min(implicitHeight, Math.max(1, parent.height - y - root.tokens.spacing.large))
        anchors.horizontalCenter: parent.horizontalCenter
        y: 64 + root.tokens.spacing.small
        onCloseRequested: root.closeRequested()
        onReservationChanged: function(top, bottom) { root.reservationChanged(top, bottom) }
        onAutoHideChangedRequested: function(top, apps, workspaces, status) { root.autoHideChangedRequested(top, apps, workspaces, status) }
        onWeatherCityChangedRequested: function(city) { root.weatherCityChangedRequested(city) }
        Component.onCompleted: Qt.callLater(focusInput)
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(settings.focusInput)
    }
}
