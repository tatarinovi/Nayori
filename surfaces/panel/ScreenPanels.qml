pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../islands/workspaces"
import "../../islands/apps"
import "../../islands/status"
import "../island"
import "../launcher"
import "../settings"
import "../capture"
import "../../services/niri"
import "../../services/ui"
import "../../services/ui/IslandRouting.js" as IslandRouting
import "../../services/ui/Overlap.js" as Overlap
import "../../services/ui/PanelModes.js" as PanelModes

Scope {
    id: root
    required property var panelScreen
    required property var shellState
    readonly property var tokenSet: shellState.tokenSet
    readonly property var tokens: tokenSet
    readonly property var captureService: shellState.captureService || null
    readonly property bool captureActive: !!captureService && (captureService.editing || captureService.controlsVisible)
    readonly property bool captureBlocksDashboard: !!captureService && captureService.editing
    FullscreenGuard { id: fullscreenGuard; screen: root.panelScreen; tokens: root.tokens }
    Region { id: emptyInputMask }
    readonly property bool fullscreen: fullscreenGuard.blocked
    readonly property real fullscreenReveal: fullscreenGuard.reveal
    property bool panelsReady: false
    Component.onCompleted: {
        panelsReady = true
        dismissForFullscreen()
        Qt.callLater(function() { arrivalReady = true })
    }
    onFullscreenRevealChanged: if (panelsReady && fullscreen && fullscreenReveal === 0) expandedOpened = false
    readonly property int topReserved: PanelModes.reservation(shellState.panelReservations, screenName, "top", shellState.topReserved)
    readonly property int bottomReserved: PanelModes.reservation(shellState.panelReservations, screenName, "bottom", shellState.bottomReserved)
    readonly property string topMode: PanelModes.mode(shellState.panelModes, screenName, "top", shellState.autoHideTop, false)
    readonly property string appsMode: PanelModes.mode(shellState.panelModes, screenName, "apps", shellState.autoHideApps, false)
    readonly property string workspacesMode: PanelModes.mode(shellState.panelModes, screenName, "workspaces", shellState.autoHideWorkspaces, false)
    readonly property string statusMode: PanelModes.mode(shellState.panelModes, screenName, "status", shellState.autoHideStatus, false)
    readonly property bool explicitTop: PanelModes.explicitMode(shellState.panelModes, screenName, "top") !== ""
    readonly property bool topEnabled: panelScreen !== null && (explicitTop ? topMode !== "hidden"
        : IslandRouting.topEnabled(screenName, shellState.outputNames,
            shellState.hideSecondaryIsland, shellState.primaryFullscreen, shellState.fullscreenIslandOutput))
    readonly property string screenName: panelScreen ? panelScreen.name : ""
    // Монитор, на котором острова нет, пока полный экран на первом не перенесёт его сюда.
    readonly property bool relocationHost: !explicitTop && shellState.hideSecondaryIsland
        && shellState.fullscreenIslandOutput !== ""
        && panelScreen !== null
        && panelScreen !== shellState.probeScreen
        && screenName === shellState.fullscreenIslandOutput
    readonly property bool relocated: relocationHost && shellState.primaryFullscreen && !fullscreen
    // 8 px над капсулой, 48 px капсула, 8 px под ней.
    readonly property int islandBand: tokens.spacing.small * 2 + tokens.panel.height
    property real arrival: relocated ? 1 : 0
    property bool arrivalReady: false
    Behavior on arrival {
        enabled: root.arrivalReady
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        }
    }
    property bool expandedOpened: false
    property bool dashboardHoverBlocked: false
    onCaptureBlocksDashboardChanged: {
        if (root.captureBlocksDashboard) {
            dashboardOpenDelay.stop()
            dashboardCloseDelay.stop()
            root.expandedOpened = false
            capsule.closePopups()
        } else if (!root.fullscreen && root.dashboardPointerInside && !root.dashboardHoverBlocked) {
            dashboardOpenDelay.restart()
        }
    }
    onFullscreenChanged: if (panelsReady) dismissForFullscreen()
    function dismissForFullscreen() {
        if (!fullscreen) return
        // Collapse only after the entire surface has been hidden.
        if (fullscreenReveal === 0) expandedOpened = false
        dashboardOpenDelay.stop()
        dashboardCloseDelay.stop()
        capsule.closePopups()
        startMenu.opened = false
        startMenu.visible = false
        startContext.opened = false
        startContext.visible = false
        status.opened = ""
        if (shellState.launcherOpened && shellState.currentOverlayScreen === panelScreen)
            shellState.launcherOpened = false
    }
    readonly property bool dashboardPointerInside: topHover.hovered || capsule.popupOpen
    onDashboardPointerInsideChanged: {
        if (fullscreen || root.captureBlocksDashboard) return
        if (dashboardPointerInside) {
            dashboardCloseDelay.stop()
            if (!dashboardHoverBlocked && !expandedOpened)
                dashboardOpenDelay.restart()
        } else {
            dashboardHoverBlocked = false
            dashboardOpenDelay.stop()
            if (expandedOpened)
                dashboardCloseDelay.restart()
        }
    }
    readonly property bool launcherHere: shellState.launcherOpened
        && panelScreen !== null
        && panelScreen === shellState.currentOverlayScreen
    function panelHoleX(win) {
        if (!root.launcherHere || !win || !win.visible || !root.panelScreen)
            return 0
        const screenW = root.panelScreen.width
        const w = win.width
        if (win.side < 0)
            return root.tokens.spacing.large
        if (win.side > 0)
            return Math.max(0, screenW - root.tokens.spacing.large - w)
        return Math.max(0, Math.round((screenW - w) / 2))
    }
    function panelHoleY(win) {
        if (!root.launcherHere || !win || !win.visible || !root.panelScreen)
            return 0
        return Math.max(0, root.panelScreen.height - root.tokens.spacing.small - win.height)
    }
    function panelHoleW(win) {
        if (!root.launcherHere || !win || !win.visible)
            return 0
        return Math.max(0, Math.round(win.width))
    }
    function panelHoleH(win) {
        if (!root.launcherHere || !win || !win.visible)
            return 0
        return Math.max(0, Math.round(win.height))
    }
    function capsuleScreenX() {
        if (!root.panelScreen)
            return 0
        return Math.round((root.panelScreen.width - capsule.width) / 2)
    }
    function capsuleScreenY() {
        return root.tokens.spacing.small + Math.round(capsule.y)
    }
    onLauncherHereChanged: {
        if (!launcherHere)
            return
        expandedOpened = false
        Qt.callLater(function() { islandWindow.focusLauncherField() })
    }
    onTopEnabledChanged: {
        if (!topEnabled) {
            expandedOpened = false
            dashboardOpenDelay.stop()
            dashboardCloseDelay.stop()
            capsule.closePopups()
        }
    }
    Connections {
        target: root.shellState
        function onStartMenuToggleRequested(outputName) {
            if (root.fullscreen || !root.panelScreen || root.panelScreen.name !== outputName) return
            root.shellState.launcherOpened = false
            startMenu.toggle()
        }
        // Меню Пуск одно на все мониторы: открытие на другом закрывает это.
        function onStartMenuOutputChanged() {
            if (root.shellState.startMenuOutput !== root.screenName)
                startMenu.opened = false
        }
        function onLauncherOpenedChanged() {
            if (root.shellState.launcherOpened) {
                root.expandedOpened = false
            }
        }
        function onSettingsOpenedChanged() {
            if (root.shellState.settingsOpened) root.expandedOpened = false
        }
    }
    Timer {
        id: dashboardOpenDelay
        interval: 400
        onTriggered: {
            if (!root.fullscreen && root.dashboardPointerInside && !root.dashboardHoverBlocked
                    && !root.shellState.launcherOpened && !root.captureBlocksDashboard)
                root.expandedOpened = true
        }
    }
    Timer {
        id: dashboardCloseDelay
        interval: 600
        onTriggered: {
            if (!root.dashboardPointerInside)
                root.expandedOpened = false
        }
    }
    ReservedSpace {
        screen: root.panelScreen
        amount: root.relocationHost
            ? IslandRouting.relocationReserve(root.relocated, root.topReserved, root.islandBand)
            : (root.topEnabled && !root.fullscreen ? root.topReserved : 0)
        topEdge: true
    }
    ReservedSpace {
        screen: root.panelScreen
        amount: root.fullscreen || (root.appsMode === "hidden" && root.workspacesMode === "hidden" && root.statusMode === "hidden") ? 0 : root.bottomReserved
        topEdge: false
    }


    EdgeTrigger {
        id: topTrigger
        ns: "nayori-edge-top"
        screen: root.panelScreen
        visible: !root.fullscreen && root.topEnabled && (root.topMode === "auto")
        topEdge: true
        span: 400
    }
    EdgeTrigger {
        id: workspaceTrigger
        ns: "nayori-edge-workspaces"
        screen: root.panelScreen
        visible: !root.fullscreen && root.panelScreen !== null && (root.workspacesMode === "auto")
        side: -1
        span: dockCluster.implicitWidth
    }
    EdgeTrigger {
        id: appsTrigger
        ns: "nayori-edge-apps"
        screen: root.panelScreen
        visible: !root.fullscreen && root.panelScreen !== null && (root.appsMode === "auto") && apps.hasWindows
        span: apps.implicitWidth
    }
    EdgeTrigger {
        id: statusTrigger
        ns: "nayori-edge-status"
        screen: root.panelScreen
        visible: !root.fullscreen && root.panelScreen !== null && (root.statusMode === "auto")
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
        EdgeMotion {
            id: dockMotion
            tokens: root.tokens
            shown: visibility.shown
            appearDuration: 520
            disappearDuration: 580
        }
        readonly property real revealOpacity: dockMotion.progress
        readonly property real contentOpacity: revealOpacity * root.fullscreenReveal
        visible: !root.fullscreen && root.fullscreenReveal > 0 && (visibility.shown || revealOpacity > 0)
        color: "transparent"
        anchors.top: false
        anchors.bottom: true
        anchors.left: side < 0
        anchors.right: side > 0
        // Keep the layer surface fixed: moving it through compositor margins
        // remaps native blur independently from the QML frame.
        margins.bottom: 0
        margins.left: side < 0 ? root.tokens.spacing.large : 0
        margins.right: side > 0 ? root.tokens.spacing.large : 0
        implicitWidth: island ? island.implicitWidth : 0
        implicitHeight: island ? island.implicitHeight + pad : 0
        readonly property real revealShift: (1 - revealOpacity) * implicitHeight
        Binding {
            target: dock.island
            property: "y"
            value: dock.revealShift
            when: dock.island !== null
        }
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: ns
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        property var materialRegion: dockGlass
        Region {
            id: dockGlass
            x: dock.island ? Math.round(dock.island.x) : 0
            y: Math.round(dock.revealShift)
            width: dock.island ? Math.round(dock.island.width) : 0
            height: dock.island ? Math.round(dock.island.height) : 0
            radius: dock.island ? Math.round(dock.island.radius) : 0
        }
        BackgroundEffect.blurRegion: root.tokens.frosted && !root.fullscreen && root.fullscreenReveal === 1 ? dock.materialRegion : null
        mask: root.fullscreen || !visibility.shown ? emptyInputMask : dockMask
        Region {
            id: dockMask
            item: dock.island
            radius: dock.island ? Math.round(dock.island.radius) : 0
        }
    }

    PanelWindow {
        id: islandWindow
        EdgeVisibility {
            id: topVisibility
            autoHide: (root.topMode === "auto")
            obstructed: root.obstruction({
                x: root.panelScreen ? (root.panelScreen.width - capsule.implicitWidth) / 2 : 0,
                y: root.tokens.spacing.small,
                width: capsule.implicitWidth,
                height: capsule.implicitHeight
            })
            available: root.topEnabled || root.launcherHere
            pointerInside: root.dashboardPointerInside || mediaHover.hovered || topTrigger.hovered
            heldOpen: root.expandedOpened || root.launcherHere || root.captureActive
        }
        HoverHandler {
            id: topHover
            parent: capsule
        }
        EdgeMotion {
            id: topMotion
            tokens: root.tokens
            shown: topVisibility.shown
            enabled: !root.relocationHost || root.arrival === 1
        }
        readonly property real revealOpacity: topMotion.progress
        readonly property real contentOpacity: root.launcherHere ? 1 : (root.relocationHost && root.arrival < 1 ? root.arrival : revealOpacity) * root.fullscreenReveal
        readonly property real arrivalShift: root.launcherHere ? 0
            : -(root.tokens.spacing.small + capsule.closedHeight) * (1 - (root.relocationHost && root.arrival < 1 ? root.arrival : revealOpacity))
        function focusLauncherField() {
            if (!root.launcherHere || !islandWindow.visible)
                return
            capsule.focusSearch()
        }
        screen: root.panelScreen
        visible: root.launcherHere || (!root.fullscreen && root.fullscreenReveal > 0
            && (root.relocationHost ? root.arrival > 0 : root.topEnabled)
            && (topVisibility.shown || revealOpacity > 0 || (root.relocationHost && root.arrival > 0)))
        color: "transparent"
        // Size stays the dashboard window. Opening does not restretch the
        // surface, and the result list is not part of this rectangle.
        anchors.top: true
        anchors.bottom: false
        anchors.left: false
        anchors.right: false
        margins.top: root.tokens.spacing.small
        implicitWidth: Math.min(root.panelScreen ? root.panelScreen.width : 1200,
            Math.max(712, capsule.closedWidth + 2 * (Math.max((lyricClock.visible ? lyricClock.width + root.tokens.spacing.small : 0) + (captureControls.visible ? captureControls.width + root.tokens.spacing.small : 0), mediaControls.width) + root.tokens.spacing.small)))
        implicitHeight: 522
        onVisibleChanged: {
            if (visible && root.launcherHere)
                Qt.callLater(islandWindow.focusLauncherField)
        }
        Connections {
            target: capsule.Window.window
            function onActiveChanged() {
                if (capsule.Window.window && capsule.Window.window.active)
                    islandWindow.focusLauncherField()
            }
        }
        exclusionMode: ExclusionMode.Ignore
        // Постоянно true: смена `focusable` вместе с keyboardFocus заставляет Quickshell
        // отправить OnDemand поверх Exclusive, и niri отдаёт фокус только по наведению.
        // Режим клавиатуры задаёт один keyboardFocus ниже.
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nayori-island"
        WlrLayershell.keyboardFocus: root.launcherHere
            ? WlrKeyboardFocus.Exclusive
            : (root.expandedOpened && !root.fullscreen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
        // У PanelWindow нет Keys: Escape ловит только Shortcut.
        Shortcut {
            enabled: root.launcherHere
            sequences: [StandardKey.Cancel]
            context: Qt.WindowShortcut
            onActivated: root.shellState.launcherOpened = false
        }

        Region {
            id: islandGlass
            Region { x: Math.round(captureControls.x); y: Math.round(captureControls.y); width: captureControls.visible ? Math.round(captureControls.width) : 0; height: captureControls.visible ? 48 : 0; radius: 24 }
            Region { item: capsule; radius: Math.round(capsule.radius) }
            // Explicit bounds: Region.item keeps the item's geometry even while it is hidden.
            Region {
                x: Math.round(lyricClock.x)
                y: Math.round(lyricClock.y)
                width: lyricClock.visible ? Math.round(lyricClock.width) : 0
                height: lyricClock.visible ? Math.round(lyricClock.height) : 0
                radius: 24
            }
            // Explicit bounds: Region.item keeps the item's geometry even while it is hidden.
            Region {
                x: Math.round(mediaControls.x)
                y: Math.round(mediaControls.y)
                width: mediaControls.visible ? Math.round(mediaControls.width) : 0
                height: mediaControls.visible ? Math.round(mediaControls.height) : 0
                radius: 24
            }
        }
        BackgroundEffect.blurRegion: root.tokens.frosted && (root.launcherHere || (!root.fullscreen && root.fullscreenReveal === 1)) ? islandGlass : null
        mask: (root.fullscreen || !topVisibility.shown) && !root.launcherHere ? emptyInputMask : islandMask
        Region {
            id: islandMask
            Region { x: Math.round(captureControls.x); y: Math.round(captureControls.y); width: captureControls.visible ? Math.round(captureControls.width) : 0; height: captureControls.visible ? 48 : 0; radius: 24 }
            Region { item: capsule; radius: Math.round(capsule.radius) }
            // Explicit bounds: Region.item keeps the item's geometry even while it is hidden.
            Region {
                x: Math.round(mediaControls.x)
                y: Math.round(mediaControls.y)
                width: mediaControls.visible ? Math.round(mediaControls.width) : 0
                height: mediaControls.visible ? Math.round(mediaControls.height) : 0
                radius: 24
            }
        }

        RectangularShadow {
            opacity: islandWindow.contentOpacity
            anchors.fill: capsule
            radius: capsule.radius
            blur: 16
            spread: 0
            offset: Qt.vector2d(0, 6)
            color: root.tokens.color.shadow
            z: -1
        }

        MorphingIsland {
            musicService: root.shellState.islandMusic
            audioReaction: root.shellState.islandAudio
            notifications: root.shellState.islandNotifications
            id: capsule
            z: 1
            expanded: root.expandedOpened
            launcherOpen: root.launcherHere
            onLauncherDismissed: root.shellState.launcherOpened = false
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
            anchors.topMargin: islandWindow.arrivalShift
            anchors.horizontalCenter: parent.horizontalCenter
            tokens: root.tokenSet
            active: islandWindow.visible
            opacity: islandWindow.contentOpacity
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

        CompactMediaControls {
            id: mediaControls
            z: 2
            tokens: root.tokens
            player: capsule.compactPlayer
            position: root.shellState.islandMusic ? root.shellState.islandMusic.position : 0
            showing: capsule.compactControls
            anchors.verticalCenter: capsule.verticalCenter
            anchors.left: capsule.right
            anchors.leftMargin: root.tokens.spacing.small
            opacity: reveal * islandWindow.contentOpacity
            HoverHandler { id: mediaHover }
        }

        CompactClock {
            id: lyricClock
            z: 2
            tokens: root.tokens
            showing: capsule.lyricsClock
            active: islandWindow.visible
            anchors.verticalCenter: capsule.verticalCenter
            anchors.right: capsule.left
            anchors.rightMargin: root.tokens.spacing.small
            opacity: reveal * islandWindow.contentOpacity
        }
        CaptureCapsule {
            id: captureControls
            z: 2
            tokens: root.tokens
            service: root.captureService
            anchors.verticalCenter: capsule.verticalCenter
            anchors.right: lyricClock.visible ? lyricClock.left : capsule.left
            anchors.rightMargin: root.tokens.spacing.small
            opacity: islandWindow.contentOpacity
        }
    }

    IslandWindow {
        id: workspacesWindow
        available: root.workspacesMode !== "hidden"
        autoHide: (root.workspacesMode === "auto")
        edgeHovered: workspaceTrigger.hovered
        onAvailableChanged: if (!available) {
            startMenu.opened = false
            startContext.opened = false
        }
        heldOpen: startMenu.presenting || startContext.opened
        ns: "nayori-workspaces"
        side: -1
        island: dockCluster
        materialRegion: Region {
            Region {
                x: Math.round(workspaces.x)
                y: Math.round(workspacesWindow.revealShift)
                width: Math.round(workspaces.width)
                height: Math.round(workspaces.height)
                radius: Math.round(workspaces.radius)
            }
        }

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
                    implicitWidth: startButton.slotWidth
                    implicitHeight: root.tokens.panel.height
                    width: implicitWidth
                    height: implicitHeight

                    StartButton {
                        id: startButton
                        iconStyle: root.shellState.startIconStyle
                        anchors.centerIn: parent
                        tokens: root.tokenSet
                        menusOpen: startMenu.opened || startContext.opened
                        opacity: workspacesWindow.contentOpacity
                        onClicked: startMenu.toggle()
                        onContextRequested: startContext.toggle()
                        onContextReleased: startContext.armGrab()
                    }
                }

                WorkspacesIsland {
                    id: workspaces
                    outputName: root.panelScreen ? root.panelScreen.name : ""
                    opacity: workspacesWindow.contentOpacity
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
            if (opened && root.fullscreen) {
                opened = false
                visible = false
                return
            }
            if (!opened) {
                if (root.shellState.startMenuOutput === root.screenName)
                    root.shellState.startMenuOutput = ""
                return
            }
            startContext.opened = false
            root.shellState.launcherOpened = false
            root.shellState.startMenuOutput = root.screenName
        }
        Component.onDestruction: {
            if (root.shellState && root.shellState.startMenuOutput === root.screenName)
                root.shellState.startMenuOutput = ""
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
            if (opened && root.fullscreen) {
                opened = false
                visible = false
                return
            }
            if (!opened)
                return
            startMenu.opened = false
            root.shellState.launcherOpened = false
        }
    }

    IslandWindow {
        id: appsWindow
        available: apps.hasWindows && root.appsMode !== "hidden"
        autoHide: (root.appsMode === "auto")
        edgeHovered: appsTrigger.hovered
        ns: "nayori-apps"
        side: 0
        island: apps

        AppsIsland {
            id: apps
            outputName: root.panelScreen ? root.panelScreen.name : ""
            opacity: appsWindow.contentOpacity
            tokens: root.tokenSet
        }
    }

    IslandWindow {
        id: statusWindow
        available: root.statusMode !== "hidden"
        onAvailableChanged: if (!available) status.opened = ""
        autoHide: (root.statusMode === "auto")
        edgeHovered: statusTrigger.hovered
        heldOpen: status.opened !== ""
        ns: "nayori-status"
        side: 1
        island: status

        StatusIsland {
            bluetoothService: root.shellState.bluetoothService || null
            settingsService: root.shellState.settingsService || null
            onBluetoothSettingsRequested: root.shellState.openSettings("bluetooth")
            id: status
            opacity: statusWindow.contentOpacity
            tokens: root.tokenSet
            menuWindow: statusWindow
            mixerSources: root.shellState.mixerSources
            onMixerSourcesSeen: sources => root.shellState.noteMixerSources(sources)
        }
    }

    PanelWindow {
        id: launcherDismiss
        screen: root.panelScreen
        visible: root.launcherHere
        color: "transparent"
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nayori-launcher-dismiss"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            width: root.launcherHere ? Math.max(0, Math.round(launcherDismiss.width)) : 0
            height: root.launcherHere ? Math.max(0, Math.round(launcherDismiss.height)) : 0
            Region {
                intersection: Intersection.Subtract
                x: root.capsuleScreenX()
                y: root.capsuleScreenY()
                width: Math.max(0, Math.round(capsule.width))
                height: Math.max(0, Math.round(capsule.height))
            }
            Region {
                intersection: Intersection.Subtract
                x: root.panelHoleX(workspacesWindow)
                y: root.panelHoleY(workspacesWindow)
                width: root.panelHoleW(workspacesWindow)
                height: root.panelHoleH(workspacesWindow)
            }
            Region {
                intersection: Intersection.Subtract
                x: root.panelHoleX(appsWindow)
                y: root.panelHoleY(appsWindow)
                width: root.panelHoleW(appsWindow)
                height: root.panelHoleH(appsWindow)
            }
            Region {
                intersection: Intersection.Subtract
                x: root.panelHoleX(statusWindow)
                y: root.panelHoleY(statusWindow)
                width: root.panelHoleW(statusWindow)
                height: root.panelHoleH(statusWindow)
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.launcherHere
            acceptedButtons: Qt.AllButtons
            onPressed: root.shellState.launcherOpened = false
        }
    }

    PanelWindow {
        id: launcherList
        screen: root.panelScreen
        color: "transparent"
        anchors.top: true
        margins.top: root.capsuleScreenY() + Math.round(capsule.height) + root.tokens.spacing.small
        // Карточка уже строки поиска на отступ с каждой стороны. Радиус концентричен
        // подложке выбранной строки: наружный = внутренний (medium) + поля карточки.
        readonly property int cardRadius: root.tokens.radius.medium + root.tokens.spacing.small
        implicitWidth: Math.max(1, Math.round(capsule.width) - root.tokens.spacing.large * 2)
        implicitHeight: Math.max(1, Math.round(listBody.implicitHeight + root.tokens.spacing.small * 2))
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nayori-launcher-list"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        property real reveal: root.launcherHere && capsule.listOpen ? 1 : 0
        Behavior on reveal {
            NumberAnimation {
                duration: root.tokens.motion.off ? 0 : root.tokens.motion.base
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
            }
        }
        visible: (root.launcherHere || !root.fullscreen) && reveal > 0.01
        mask: Region {
            width: root.launcherHere && capsule.listOpen ? Math.max(0, Math.round(launcherList.width)) : 0
            height: root.launcherHere && capsule.listOpen ? Math.max(0, Math.round(launcherList.height)) : 0
            radius: launcherList.cardRadius
        }
        Rectangle {
            anchors.fill: parent
            // PanelWindow has no opacity; fade the content instead.
            opacity: launcherList.reveal
            radius: launcherList.cardRadius
            color: root.tokens.frosted ? root.tokens.material.island : root.tokens.material.dense
            border.width: 1
            border.color: root.tokens.color.accentSoft
            clip: true
            antialiasing: true
            LauncherDropdown {
                id: listBody
                x: root.tokens.spacing.small
                y: root.tokens.spacing.small
                width: parent.width - root.tokens.spacing.small * 2
                tokens: root.tokenSet
                host: capsule.listSource
            }
        }
    }
}
