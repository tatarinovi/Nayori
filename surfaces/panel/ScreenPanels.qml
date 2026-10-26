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
import "../../services/niri"
import "../../services/ui"
import "../../services/ui/Overlap.js" as Overlap

Scope {
    id: root
    required property var panelScreen
    required property var shellState
    readonly property var tokenSet: shellState.tokenSet
    readonly property var tokens: tokenSet
    FullscreenGuard { id: fullscreenGuard; screen: root.panelScreen; tokens: root.tokens }
    Region { id: emptyInputMask }
    readonly property bool fullscreen: fullscreenGuard.blocked
    readonly property real fullscreenReveal: fullscreenGuard.reveal
    property bool panelsReady: false
    Component.onCompleted: { panelsReady = true; dismissForFullscreen() }
    onFullscreenRevealChanged: if (panelsReady && fullscreen && fullscreenReveal === 0) expandedOpened = false
    readonly property bool topEnabled: panelScreen !== null
        && (panelScreen === shellState.probeScreen || !shellState.hideSecondaryIsland)
    readonly property string screenName: panelScreen ? panelScreen.name : ""
    property bool expandedOpened: false
    property bool dashboardHoverBlocked: false
    onFullscreenChanged: if (panelsReady) dismissForFullscreen()
    function dismissForFullscreen() {
        if (!fullscreen) return
        // Finish the fade before collapsing the dashboard under the surface.
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
        if (fullscreen) return
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
    readonly property bool launcherHere: !fullscreen && shellState.launcherOpened
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
                if (root.fullscreen && root.shellState.currentOverlayScreen === root.panelScreen)
                    root.shellState.launcherOpened = false
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
                    && !root.shellState.launcherOpened)
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
        amount: root.topEnabled && !root.fullscreen ? root.shellState.topReserved : 0
        topEdge: true
    }
    ReservedSpace {
        screen: root.panelScreen
        amount: root.fullscreen ? 0 : root.shellState.bottomReserved
        topEdge: false
    }


    EdgeTrigger {
        id: topTrigger
        ns: "nayori-edge-top"
        screen: root.panelScreen
        visible: !root.fullscreen && root.topEnabled && root.shellState.autoHideTop
        topEdge: true
        span: 400
    }
    EdgeTrigger {
        id: workspaceTrigger
        ns: "nayori-edge-workspaces"
        screen: root.panelScreen
        visible: !root.fullscreen && root.panelScreen !== null && root.shellState.autoHideWorkspaces
        side: -1
        span: dockCluster.implicitWidth
    }
    EdgeTrigger {
        id: appsTrigger
        ns: "nayori-edge-apps"
        screen: root.panelScreen
        visible: !root.fullscreen && root.panelScreen !== null && root.shellState.autoHideApps && apps.hasWindows
        span: apps.implicitWidth
    }
    EdgeTrigger {
        id: statusTrigger
        ns: "nayori-edge-status"
        screen: root.panelScreen
        visible: !root.fullscreen && root.panelScreen !== null && root.shellState.autoHideStatus
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
        readonly property real contentOpacity: revealOpacity * root.fullscreenReveal
        Behavior on revealOpacity {
            enabled: dock.animateReady
            NumberAnimation {
                duration: root.tokenSet.motion.off ? 0 : root.tokenSet.motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
            }
        }
        Component.onCompleted: Qt.callLater(function() { dock.animateReady = true })
        visible: root.fullscreenReveal > 0 && (visibility.shown || revealOpacity > 0)
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

        property var materialRegion: dockGlass
        Region { id: dockGlass; item: dock.island; radius: dock.island ? Math.round(dock.island.radius) : 0 }
        BackgroundEffect.blurRegion: root.tokens.frosted ? dock.materialRegion : null
        mask: root.fullscreen ? emptyInputMask : dockMask
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
            autoHide: root.shellState.autoHideTop
            obstructed: root.obstruction({
                x: root.panelScreen ? (root.panelScreen.width - capsule.implicitWidth) / 2 : 0,
                y: root.tokens.spacing.small,
                width: capsule.implicitWidth,
                height: capsule.implicitHeight
            })
            available: root.topEnabled
            pointerInside: root.dashboardPointerInside || mediaHover.hovered || topTrigger.hovered
            heldOpen: root.expandedOpened || root.launcherHere
        }
        HoverHandler {
            id: topHover
            parent: capsule
        }
        property bool animateReady: false
        property real revealOpacity: topVisibility.shown ? 1 : 0
        readonly property real contentOpacity: revealOpacity * root.fullscreenReveal
        Behavior on revealOpacity {
            enabled: islandWindow.animateReady
            NumberAnimation {
                duration: root.tokenSet.motion.off ? 0 : root.tokenSet.motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
            }
        }
        Component.onCompleted: Qt.callLater(function() { islandWindow.animateReady = true })
        function focusLauncherField() {
            if (!root.launcherHere || !islandWindow.visible)
                return
            capsule.focusSearch()
        }
        screen: root.panelScreen
        visible: root.topEnabled && root.fullscreenReveal > 0 && (topVisibility.shown || revealOpacity > 0)
        color: "transparent"
        // Size stays the dashboard window. Opening does not restretch the
        // surface, and the result list is not part of this rectangle.
        anchors.top: true
        anchors.bottom: false
        anchors.left: false
        anchors.right: false
        margins.top: root.tokens.spacing.small
        implicitWidth: Math.max(712, capsule.closedWidth + 2 * (Math.max(lyricClock.width, mediaControls.width) + root.tokens.spacing.small))
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
        BackgroundEffect.blurRegion: root.tokens.frosted ? islandGlass : null
        mask: root.fullscreen ? emptyInputMask : islandMask
        Region {
            id: islandMask
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
            anchors.topMargin: 0
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
    }

    IslandWindow {
        id: workspacesWindow
        autoHide: root.shellState.autoHideWorkspaces
        edgeHovered: workspaceTrigger.hovered
        heldOpen: startMenu.presenting || startContext.opened
        ns: "nayori-workspaces"
        side: -1
        island: dockCluster
        materialRegion: Region {
            Region { item: workspaces; radius: Math.round(workspaces.radius) }
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
        available: apps.hasWindows
        autoHide: root.shellState.autoHideApps
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
        autoHide: root.shellState.autoHideStatus
        edgeHovered: statusTrigger.hovered
        heldOpen: status.opened !== ""
        ns: "nayori-status"
        side: 1
        island: status

        StatusIsland {
            id: status
            opacity: statusWindow.contentOpacity
            tokens: root.tokenSet
            menuWindow: statusWindow
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
        visible: !root.fullscreen && reveal > 0.01
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
