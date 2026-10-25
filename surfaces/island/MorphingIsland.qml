pragma ComponentBehavior: Bound
import QtQuick

// One body in a fixed layer surface. Only its scene geometry changes; compact
// and dashboard content share the same border, colour, and top-center origin.
Rectangle {
    id: root
    required property var tokens
    property bool testMode: false
    property var audioReaction: null
    property var notifications: null
    property bool notificationPage: false
    readonly property string viewKey: "island-" + String(root)
    function updateNotificationView() {
        if (notifications) notifications.view(viewKey, expanded, expanded && notificationPage)
        if (dashboard.item && dashboard.item.currentPage !== (notificationPage ? 1 : 0))
            dashboard.item.currentPage = notificationPage ? 1 : 0
    }
    onExpandedChanged: {
        if (expanded) notificationPage = false
        updateNotificationView()
    }
    onNotificationPageChanged: updateNotificationView()
    onNotificationsChanged: updateNotificationView()
    Component.onDestruction: { if (notifications) notifications.view(viewKey, false, false) }
    property bool active: true
    property bool expanded: false
    property string weatherCity: ""
    readonly property bool menuOpened: compact.menuOpened
    property real closedWidth: compact.compactWidth
    readonly property real closedHeight: 48
    readonly property real expandedWidth: 680
    readonly property real expandedHeight: 490
    property bool ready: false
    property real progress: expanded ? 1 : 0
    signal dashboardRequested()
    signal contextOpened()
    signal launcherRequested()
    signal settingsRequested()
    signal weatherSettingsRequested()
    signal closeRequested()

    implicitWidth: closedWidth
    implicitHeight: closedHeight
    width: closedWidth + (expandedWidth - closedWidth) * progress
    height: closedHeight + (expandedHeight - closedHeight) * progress
    radius: 24 + 4 * progress
    color: Qt.tint(root.tokens.color.surfaceAlt, Qt.alpha(root.tokens.color.background, progress))
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
        notifications: root.notifications
        drawChrome: false
        expansionProgress: root.progress
        width: parent.width
        active: root.active
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        onDashboardRequested: root.dashboardRequested()
        onContextOpened: root.contextOpened()
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
            testMode: root.testMode
            tokens: root.tokens
            weatherCity: root.weatherCity
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
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: compact.toggleContextMenu()
    }
}
