pragma ComponentBehavior: Bound
import QtQuick

// One body in a fixed layer surface. Only its scene geometry changes; compact
// and dashboard content share the same border, colour, and top-center origin.
Rectangle {
    id: root
    required property var tokens
    property bool testMode: false
    property var audioReaction: null
    property var musicService: null
    property var notifications: null
    property bool notificationPage: false
    readonly property string viewKey: "island-" + String(root)
    function updateNotificationView() {
        if (notifications) notifications.view(viewKey, expanded, expanded && notificationPage)
        if (dashboard.item && dashboard.item.currentPage !== (notificationPage ? 1 : 0))
            dashboard.item.currentPage = notificationPage ? 1 : 0
    }
    readonly property bool wantsMusic: active && visible && !testMode &&
        ((expanded && !notificationPage) || (!!musicService && !!musicService.player && musicService.player.isPlaying))
    onWantsMusicChanged: updateMusicConsumer()
    function updateMusicConsumer() {
        if (musicService) musicService.consumer(viewKey, wantsMusic)
    }
    onMusicServiceChanged: updateMusicConsumer()
    onActiveChanged: updateMusicConsumer()
    onVisibleChanged: updateMusicConsumer()
    onExpandedChanged: {
        if (expanded) notificationPage = false
        updateNotificationView()
        updateMusicConsumer()
    }
    onNotificationPageChanged: { updateNotificationView(); updateMusicConsumer() }
    onNotificationsChanged: updateNotificationView()
    Component.onDestruction: {
        if (notifications) notifications.view(viewKey, false, false)
        if (musicService) musicService.consumer(viewKey, false)
    }
    property bool active: true
    property bool expanded: false
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

    implicitWidth: closedWidth
    implicitHeight: closedHeight
    width: closedWidth + (expandedWidth - closedWidth) * progress
    height: closedHeight + (expandedHeight - closedHeight) * progress
    radius: 24 + 4 * progress
    color: root.tokens.frosted ? root.tokens.material.island : Qt.tint(root.tokens.material.island, Qt.alpha(root.tokens.material.islandExpanded, progress))
    border.width: 1
    border.color: root.tokens.color.border
    clip: true
    antialiasing: true

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
    Component.onCompleted: Qt.callLater(function() { root.ready = true })

    DynamicIsland {
        id: compact
        testMode: root.testMode
        tokens: root.tokens
        audioReaction: root.audioReaction
        musicService: root.musicService
        notifications: root.notifications
        drawChrome: false
        expansionProgress: root.progress
        islandRotationEnabled: root.islandRotationEnabled
        islandRotationSeconds: root.islandRotationSeconds
        weatherCity: root.weatherCity
        weather: root.weatherService ? root.weatherService.data : null
        weatherError: root.weatherService ? root.weatherService.error : ""
        width: parent.width
        active: root.active
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        onDashboardRequested: root.dashboardRequested()
        onLauncherRequested: root.launcherRequested()
        onSettingsRequested: root.settingsRequested()
    }
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
        onLoaded: Qt.callLater(function() { if (item) item.forceActiveFocus(Qt.TabFocusReason) })
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
            currentPage: root.notificationPage ? 1 : 0
            onCurrentPageChanged: root.notificationPage = currentPage === 1
            drawChrome: false
            showDate: false
            topInset: 0
            onCloseRequested: root.closeRequested()
            onSettingsRequested: root.weatherSettingsRequested()
        }
    }
}
