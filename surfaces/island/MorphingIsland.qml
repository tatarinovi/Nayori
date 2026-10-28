pragma ComponentBehavior: Bound
import QtQuick
import "../launcher"
import "ShelfDrop.js" as ShelfDrop

// One body in a fixed layer surface. Only its scene geometry changes; compact
// and dashboard content share the same border, colour, and top-center origin.
Rectangle {
    id: root
    required property var tokens
    property bool testMode: false
    property var audioReaction: null
    property var musicService: null
    property var notifications: null
    property var shelfService: null
    property int currentPage: 0
    readonly property bool dropHover: compactDrop.containsDrag
    readonly property bool shelfInteracting: dropHover || (!!dashboard.item && dashboard.item.shelfInteracting)
    onCurrentPageChanged: {
        notificationPage = currentPage === 1
        updateNotificationView()
        updateMusicConsumer()
    }
    property bool notificationPage: false
    readonly property string viewKey: "island-" + String(root)
    function updateNotificationView() {
        if (notifications) notifications.view(viewKey, expanded, expanded && notificationPage)
        if (dashboard.item && dashboard.item.currentPage !== currentPage)
            dashboard.item.currentPage = currentPage
    }
    readonly property bool wantsMusic: active && visible && !testMode &&
        ((expanded && currentPage === 0) || (!!musicService && !!musicService.player && musicService.player.isPlaying))
    onWantsMusicChanged: updateMusicConsumer()
    function updateMusicConsumer() {
        if (musicService) musicService.consumer(viewKey, wantsMusic)
    }
    onMusicServiceChanged: updateMusicConsumer()
    onActiveChanged: updateMusicConsumer()
    onVisibleChanged: updateMusicConsumer()
    onExpandedChanged: {
        if (expanded) currentPage = !!notifications && notifications.unreadCount > 0 ? 1 : 0
        updateNotificationView()
        updateMusicConsumer()
    }
    onNotificationPageChanged: {
        if (notificationPage) currentPage = 1
        else if (currentPage === 1) currentPage = 0
        updateNotificationView(); updateMusicConsumer()
    }
    onNotificationsChanged: updateNotificationView()
    Component.onDestruction: {
        if (notifications) notifications.view(viewKey, false, false)
        if (musicService) musicService.consumer(viewKey, false)
    }
    property bool active: true
    property bool expanded: false
    readonly property bool popupOpen: !!dashboard.item && dashboard.item.popupOpen
    function closePopups() { if (dashboard.item) dashboard.item.closePopups() }
    property bool launcherOpen: false
    readonly property int launcherWidth: 640
    // One blend, retargeted. Rapid Alt+Space does not queue a second morph.
    // Height always returns to the row. Results live in a separate dropdown.
    property real launcherBlend: launcherOpen ? 1 : 0
    // Frozen at the size on screen when the row opens, so the dashboard's own
    // curve cannot add a second resize underneath this one.
    property real originW: closedWidth
    property real originH: closedHeight
    property string weatherCity: ""
    property var weatherService: null
    property bool islandRotationEnabled: true
    property int islandRotationSeconds: 15
    property real closedWidth: compact.compactWidth
    readonly property real closedHeight: 48
    readonly property real expandedWidth: 680
    readonly property real expandedHeight: 490
    property bool ready: false
    property real progress: expanded ? 1 : 0
    signal dashboardRequested()
    signal launcherRequested()
    signal settingsRequested()
    signal weatherSettingsRequested()
    signal closeRequested()
    signal launcherDismissed()

    implicitWidth: closedWidth
    implicitHeight: closedHeight
    readonly property real restWidth: closedWidth + (expandedWidth - closedWidth) * progress
    readonly property real restHeight: closedHeight + (expandedHeight - closedHeight) * progress
    readonly property bool morphing: launcherOpen || launcherBlend > 0
    width: root.morphing
        ? root.originW + (root.launcherWidth - root.originW) * root.launcherBlend
        : root.restWidth
    height: root.morphing
        ? root.originH + (root.closedHeight - root.originH) * root.launcherBlend
        : root.restHeight
    radius: root.morphing ? Math.min(height / 2, 24) : (24 + 4 * progress)
    color: root.tokens.frosted ? root.tokens.material.island : Qt.tint(root.tokens.material.island, Qt.alpha(root.tokens.material.islandExpanded, progress))
    border.width: 1
    border.color: root.tokens.color.border
    clip: true
    antialiasing: true

    IslandBeatBorder {
        anchors.fill: parent
        z: 100
        accent: root.tokens.color.accent
        cornerRadius: root.radius
        pulse: compact.musicPulse
    }

    Behavior on closedWidth {
        enabled: root.ready
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        }
    }
    Behavior on progress {
        enabled: root.ready
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.77, 0, 0.175, 1, 1, 1]
        }
    }
    Behavior on launcherBlend {
        enabled: root.ready
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.base
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        }
    }
    readonly property bool searchFocused: launcherLoader.item ? launcherLoader.item.inputFocused : false
    readonly property var listSource: launcherLoader.item
    readonly property bool listOpen: root.launcherOpen && root.listSource && root.listSource.listWanted
    readonly property var compactPlayer: compact.controlPlayer
    readonly property bool compactControls: !!compact.controlPlayer && !expanded && progress === 0 && !launcherOpen && launcherBlend === 0
    readonly property bool lyricsClock: !expanded && progress === 0
        && (compact.showingLyrics || compact.showingNotification)
        && !compact.showingVolume
        && !root.launcherOpen
        && root.launcherBlend === 0
    function focusSearch() {
        if (!root.launcherOpen || !launcherLoader.item)
            return
        launcherLoader.item.focusInput()
    }
    function outsidePress(x, y) {
        if (!root.launcherOpen)
            return false
        if (x >= 0 && y >= 0 && x < root.width && y < root.height)
            return false
        root.launcherDismissed()
        return true
    }
    Component.onCompleted: Qt.callLater(function() { root.ready = true })
    onRestWidthChanged: {
        if (!root.launcherOpen && root.launcherBlend === 0)
            root.originW = root.restWidth
    }
    onRestHeightChanged: {
        if (!root.launcherOpen && root.launcherBlend === 0)
            root.originH = root.restHeight
    }
    onLauncherOpenChanged: {
        if (root.launcherOpen) {
            const w = root.originW
            const h = root.originH
            root.originW = w
            root.originH = h
        } else {
            root.originW = root.closedWidth
            root.originH = root.closedHeight
        }
        if (!launcherLoader.item)
            return
        if (root.launcherOpen)
            launcherLoader.item.open()
        else
            launcherLoader.item.close()
    }

    DynamicIsland {
        id: compact
        testMode: root.testMode
        tokens: root.tokens
        audioReaction: root.audioReaction
        musicService: root.musicService
        notifications: root.notifications
        drawChrome: false
        expansionProgress: root.progress
        lookActive: root.expanded && cursor.hovered
        lookPoint: Qt.point(cursor.point.position.x - compact.x, cursor.point.position.y - compact.y)
        contentYielded: root.launcherOpen || root.launcherBlend > 0.01
        islandRotationEnabled: root.islandRotationEnabled
        islandRotationSeconds: root.islandRotationSeconds
        weatherCity: root.weatherCity
        weather: root.weatherService ? root.weatherService.data : null
        weatherError: root.weatherService ? root.weatherService.error : ""
        // Stay at the size it had. Stretching this with the capsule is the slide.
        width: root.morphing ? root.originW : parent.width
        active: root.active
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        onDashboardRequested: root.dashboardRequested()
        onLauncherRequested: root.launcherRequested()
        onSettingsRequested: root.settingsRequested()
    }
    // Incoming native Wayland drags open the shelf from the compact capsule.
    DropArea {
        id: compactDrop
        anchors.fill: parent
        enabled: !root.launcherOpen && !root.expanded && !!root.shelfService
        onEntered: event => {
            if (event.source || !ShelfDrop.supports(event)) { event.accepted = false; return }
            ShelfDrop.prefetch(event)
            root.dashboardRequested()
            root.currentPage = 2
        }
        onDropped: event => {
            if (root.shelfService.add(ShelfDrop.read(event))) event.accept(Qt.CopyAction)
        }
    }
    // Passive cursor tracking for the fox across the expanded island.
    HoverHandler { id: cursor }
    Loader {
        id: dashboard
        objectName: "islandDashboardLoader"
        width: root.expandedWidth
        height: root.expandedHeight - 40
        y: 40
        anchors.horizontalCenter: parent.horizontalCenter
        active: root.expanded || root.progress > 0.001
        opacity: Math.max(0, (root.progress - 0.85) / 0.15)
        enabled: root.expanded && root.progress > 0.9
        onLoaded: Qt.callLater(function() {
            if (item && root.expanded && !root.launcherOpen)
                item.forceActiveFocus(Qt.TabFocusReason)
        })
        sourceComponent: IslandDashboard {
            musicService: root.musicService
            testMode: root.testMode
            tokens: root.tokens
            weatherCity: root.weatherCity
            weather: root.weatherService ? root.weatherService.data : null
            weatherError: root.weatherService ? root.weatherService.error : ""
            weatherLoading: root.weatherService ? root.weatherService.loading : false
            onWeatherRefreshRequested: if (root.weatherService) root.weatherService.refresh()
            notifications: root.notifications
            shelfService: root.shelfService
            currentPage: root.currentPage
            onCurrentPageChanged: root.currentPage = currentPage
            drawChrome: false
            showDate: false
            topInset: 0
            onCloseRequested: root.closeRequested()
            onSettingsRequested: root.weatherSettingsRequested()
        }
    }
    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: root.launcherOpen
        acceptedButtons: Qt.AllButtons
        onWheel: function(wheel) { wheel.accepted = true }
        onClicked: function(mouse) { mouse.accepted = true }
    }
    Loader {
        id: launcherLoader
        objectName: "islandLauncherLoader"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: item ? item.implicitHeight : 0
        z: 2
        active: root.launcherOpen || root.launcherBlend > 0.001
        enabled: root.launcherOpen
        onLoaded: {
            if (root.launcherOpen && item)
                item.open()
        }
        sourceComponent: Launcher {
            tokens: root.tokens
            embedded: true
            panelWidth: root.launcherWidth
            onCloseRequested: root.launcherDismissed()
        }
    }
}
