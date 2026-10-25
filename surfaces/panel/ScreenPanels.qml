pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../islands/workspaces"
import "../../islands/apps"
import "../../islands/status"
import "../island"
import "../settings"
import "../../services/niri"
import "../../services/ui"
import "../../services/ui/Overlap.js" as Overlap

Scope {
    id: root
    required property var panelScreen
    required property var shellState
    readonly property var tokenSet: shellState.tokenSet
    readonly property var tokens: tokenSet
    readonly property bool topEnabled: panelScreen !== null
        && (panelScreen === shellState.probeScreen || !shellState.hideSecondaryIsland)
    property bool expandedOpened: false
    property bool dashboardHoverBlocked: false
    onTopEnabledChanged: {
        if (!topEnabled) {
            expandedOpened = false
            dashboardOpenDelay.stop()
            dashboardCloseDelay.stop()
        }
    }
    Connections {
        target: root.shellState
        function onLauncherOpenedChanged() {
            if (root.shellState.launcherOpened) root.expandedOpened = false
        }
        function onSettingsOpenedChanged() {
            if (root.shellState.settingsOpened) root.expandedOpened = false
        }
    }
    Timer {
        id: dashboardOpenDelay
        interval: 400
        onTriggered: {
            if (topHover.hovered && !capsule.menuOpened && !root.dashboardHoverBlocked
                    && !root.shellState.launcherOpened)
                root.expandedOpened = true
        }
    }
    Timer {
        id: dashboardCloseDelay
        interval: 600
        onTriggered: {
            if (!topHover.hovered)
                root.expandedOpened = false
        }
    }
    ReservedSpace {
        screen: root.panelScreen
        amount: root.topEnabled ? root.shellState.topReserved : 0
        topEdge: true
    }
    ReservedSpace {
        screen: root.panelScreen
        amount: root.shellState.bottomReserved
        topEdge: false
    }


    EdgeTrigger {
        id: topTrigger
        ns: "nayori-edge-top"
        screen: root.panelScreen
        visible: root.topEnabled && root.shellState.autoHideTop
        topEdge: true
        span: 400
    }
    EdgeTrigger {
        id: workspaceTrigger
        ns: "nayori-edge-workspaces"
        screen: root.panelScreen
        visible: root.panelScreen !== null && root.shellState.autoHideWorkspaces
        side: -1
        span: dockCluster.implicitWidth
    }
    EdgeTrigger {
        id: appsTrigger
        ns: "nayori-edge-apps"
        screen: root.panelScreen
        visible: root.panelScreen !== null && root.shellState.autoHideApps && apps.hasWindows
        span: apps.implicitWidth
    }
    EdgeTrigger {
        id: statusTrigger
        ns: "nayori-edge-status"
        screen: root.panelScreen
        visible: root.panelScreen !== null && root.shellState.autoHideStatus
        side: 1
        span: status.implicitWidth
    }


    function obstruction(panel) {
        if (!root.panelScreen || !Niri.available)
            return false
        const state = Overlap.report(panel, root.panelScreen.name, Niri.workspaces, Niri.windows)
        // User-selected fallback: ordinary auto-hide when IPC geometry is absent.
        return state.overlaps || state.unknown
    }

    // Окно ровно по острову. Второй хром вокруг компонента не рисуется.
    component IslandWindow: PanelWindow {
        id: dock

        required property string ns
        property int side: 0
        property Item island: null
        property bool autoHide: false
        property bool available: true
        property bool edgeHovered: false
        property bool heldOpen: false

        EdgeVisibility {
            id: visibility
            autoHide: dock.autoHide
            obstructed: root.obstruction({
                x: !root.panelScreen ? 0 : dock.side < 0 ? 24 : dock.side > 0
                   ? root.panelScreen.width - 24 - dock.implicitWidth
                   : (root.panelScreen.width - dock.implicitWidth) / 2,
                y: root.panelScreen ? root.panelScreen.height - dock.implicitHeight - dock.pad : 0,
                width: dock.implicitWidth,
                height: dock.implicitHeight
            })
            available: root.panelScreen !== null && dock.island !== null && dock.available
            pointerInside: dockHover.hovered || dock.edgeHovered
            heldOpen: dock.heldOpen
        }
        HoverHandler { id: dockHover }

        readonly property int pad: root.tokens.spacing.small

        screen: root.panelScreen
        property bool animateReady: false
        property real revealOpacity: visibility.shown ? 1 : 0
        Behavior on revealOpacity {
            enabled: dock.animateReady
            NumberAnimation {
                duration: root.tokenSet.motion.off ? 0 : root.tokenSet.motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
            }
        }
        Component.onCompleted: Qt.callLater(function() { dock.animateReady = true })
        visible: visibility.shown || revealOpacity > 0
        color: "transparent"
        anchors.top: false
        anchors.bottom: true
        anchors.left: side < 0
        anchors.right: side > 0
        margins.bottom: pad
        margins.left: side < 0 ? root.tokens.spacing.large : 0
        margins.right: side > 0 ? root.tokens.spacing.large : 0
        implicitWidth: island ? island.implicitWidth : 0
        implicitHeight: island ? island.implicitHeight : 0
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: ns
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            item: dock.island
            radius: dock.island ? Math.round(dock.island.radius) : 0
        }
    }

    PanelWindow {
        id: islandWindow
        EdgeVisibility {
            id: topVisibility
            autoHide: root.shellState.autoHideTop
            obstructed: root.obstruction({
                x: root.panelScreen ? (root.panelScreen.width - capsule.implicitWidth) / 2 : 0,
                y: root.tokens.spacing.small,
                width: capsule.implicitWidth,
                height: capsule.implicitHeight
            })
            available: root.topEnabled
            pointerInside: topHover.hovered || topTrigger.hovered
            heldOpen: root.expandedOpened || capsule.menuOpened
        }
        HoverHandler {
            id: topHover
            onHoveredChanged: {
                if (hovered) {
                    dashboardCloseDelay.stop()
                    if (!root.dashboardHoverBlocked)
                        dashboardOpenDelay.restart()
                } else {
                    root.dashboardHoverBlocked = false
                    dashboardOpenDelay.stop()
                    if (root.expandedOpened)
                        dashboardCloseDelay.restart()
                }
            }
        }
        property bool animateReady: false
        property real revealOpacity: topVisibility.shown ? 1 : 0
        Behavior on revealOpacity {
            enabled: islandWindow.animateReady
            NumberAnimation {
                duration: root.tokenSet.motion.off ? 0 : root.tokenSet.motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
            }
        }
        Component.onCompleted: Qt.callLater(function() { islandWindow.animateReady = true })
        screen: root.panelScreen
        visible: root.topEnabled && (topVisibility.shown || revealOpacity > 0)
        color: "transparent"
        anchors.top: true
        anchors.bottom: false
        anchors.left: false
        anchors.right: false
        margins.top: root.tokens.spacing.small
        implicitWidth: 712
        implicitHeight: 522
        exclusionMode: ExclusionMode.Ignore
        focusable: root.expandedOpened
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nayori-island"
        WlrLayershell.keyboardFocus: root.expandedOpened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        // Маска совпадает с капсулой: тень и пустые поля клики не забирают.
        mask: Region {
            item: capsule
            radius: Math.round(capsule.radius)
        }

        RectangularShadow {
            opacity: islandWindow.revealOpacity
            anchors.fill: capsule
            radius: capsule.radius
            blur: 16
            spread: 0
            offset: Qt.vector2d(0, 6)
            color: root.tokens.color.shadow
            z: -1
        }

        MorphingIsland {
            audioReaction: root.shellState.islandAudio
            notifications: root.shellState.islandNotifications
            id: capsule
            expanded: root.expandedOpened
            weatherCity: root.shellState.weatherCity
            weatherService: root.shellState.weatherService
            islandRotationEnabled: root.shellState.islandRotationEnabled
            islandRotationSeconds: root.shellState.islandRotationSeconds
            onCloseRequested: {
                root.expandedOpened = false
                root.dashboardHoverBlocked = topHover.hovered
            }
            onWeatherSettingsRequested: {
                root.shellState.overlayScreen = root.panelScreen
                root.expandedOpened = false
                root.shellState.openSettings("weather")
            }
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            tokens: root.tokenSet
            active: islandWindow.visible
            opacity: islandWindow.revealOpacity
            onContextOpened: {
                dashboardOpenDelay.stop()
                root.expandedOpened = false
                root.dashboardHoverBlocked = true
            }
            onDashboardRequested: {
                root.shellState.launcherOpened = false
                root.expandedOpened = true
            }
            onLauncherRequested: {
                root.shellState.overlayScreen = root.panelScreen
                root.expandedOpened = false
                root.shellState.launcherOpened = true
            }
            onSettingsRequested: {
                root.shellState.overlayScreen = root.panelScreen
                root.expandedOpened = false
                root.shellState.launcherOpened = false
                root.shellState.openSettings("home")
            }
        }
    }

    IslandWindow {
        id: workspacesWindow
        autoHide: root.shellState.autoHideWorkspaces
        edgeHovered: workspaceTrigger.hovered
        heldOpen: startMenu.opened || startContext.opened
        ns: "nayori-workspaces"
        side: -1
        island: dockCluster

        // Пуск в том же левом окне: второе окно слева легло бы поверх рабочих столов.
        Item {
            id: dockCluster
            readonly property real radius: workspaces.radius
            implicitWidth: dockRow.implicitWidth
            implicitHeight: root.tokens.panel.height
            width: implicitWidth
            height: implicitHeight

            Row {
                id: dockRow
                spacing: root.tokens.spacing.small

                Item {
                    implicitWidth: root.tokens.panel.control
                    implicitHeight: root.tokens.panel.height
                    width: implicitWidth
                    height: implicitHeight

                    StartButton {
                        id: startButton
                        anchors.centerIn: parent
                        tokens: root.tokenSet
                        menusOpen: startMenu.opened || startContext.opened
                        opacity: workspacesWindow.revealOpacity
                        onClicked: startMenu.toggle()
                        onContextRequested: startContext.toggle()
                        onContextReleased: startContext.armGrab()
                    }
                }

                WorkspacesIsland {
                    id: workspaces
                    outputName: root.panelScreen ? root.panelScreen.name : ""
                    opacity: workspacesWindow.revealOpacity
                    tokens: root.tokenSet
                }
            }
        }
    }

    StartMenu {
        id: startMenu
        tokens: root.tokenSet
        shellState: root.shellState
        panelScreen: root.panelScreen
        anchorItem: startButton
        anchorWindow: workspacesWindow
        onOpenedChanged: {
            if (opened)
                startContext.opened = false
        }
    }

    StartContextMenu {
        id: startContext
        tokens: root.tokenSet
        shellState: root.shellState
        panelScreen: root.panelScreen
        anchorItem: startButton
        anchorWindow: workspacesWindow
        onOpenedChanged: {
            if (opened)
                startMenu.opened = false
        }
    }

    IslandWindow {
        id: appsWindow
        available: apps.hasWindows
        autoHide: root.shellState.autoHideApps
        edgeHovered: appsTrigger.hovered
        ns: "nayori-apps"
        side: 0
        island: apps

        AppsIsland {
            id: apps
            outputName: root.panelScreen ? root.panelScreen.name : ""
            opacity: appsWindow.revealOpacity
            tokens: root.tokenSet
        }
    }

    IslandWindow {
        id: statusWindow
        autoHide: root.shellState.autoHideStatus
        edgeHovered: statusTrigger.hovered
        heldOpen: status.opened !== ""
        ns: "nayori-status"
        side: 1
        island: status

        StatusIsland {
            id: status
            opacity: statusWindow.revealOpacity
            tokens: root.tokenSet
            menuWindow: statusWindow
        }
    }
}
