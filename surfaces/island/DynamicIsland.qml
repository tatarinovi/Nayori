pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../services/status"
import "../../islands/status"

Rectangle {
    id: root
    required property var tokens
    readonly property var player: {
        if (root.testMode) return null
        const players = Mpris.players.values
        for (let i = 0; i < players.length; ++i)
            if (players[i].isPlaying) return players[i]
        return null
    }
    readonly property string playingTitle: player ? (player.trackTitle || "Без названия") : ""
    property bool testMode: false
    property var audioReaction: null
    property var notifications: null
    readonly property var notification: notifications ? notifications.current : null
    readonly property bool showingNotification: notification !== null && expansionProgress < 0.01
    property bool drawChrome: true
    property bool active: true
    property real expansionProgress: 0
    signal contextOpened()
    signal dashboardRequested()
    signal launcherRequested()
    signal settingsRequested()
    property bool menuOpened: false
    readonly property bool showingVolume: volumeTimeout.running
    property bool audioInitialized: false

    // Grow modestly for music; long titles still scroll within a bounded slot.
    readonly property real compactWidth: playingTitle.length > 0
        ? Math.min(448, Math.max(400, titleMetrics.advanceWidth * 2 + 140)) : 352
    TextMetrics {
        id: titleMetrics
        text: root.playingTitle
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.type.body.size
        font.weight: root.tokens.type.body.weight
    }

    implicitWidth: compactWidth
    implicitHeight: 48
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: drawChrome ? tokens.color.surfaceAlt : "transparent"
    border.width: drawChrome ? 1 : 0
    border.color: hover.containsMouse ? tokens.color.accentSoft : tokens.color.border
    antialiasing: true

    readonly property var audio: audioLoader.item || silentAudio
    QtObject {
        id: silentAudio
        readonly property bool available: false
        readonly property bool muted: false
        readonly property real level: 0
        function toggleMuted() {}
        function setVolume(value) {}
    }
    Loader { id: audioLoader; active: !root.testMode; sourceComponent: Audio {} }
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: root.active
    }

    function toggleContextMenu() {
        root.contextOpened()
        root.menuOpened = !root.menuOpened
    }
    function flashVolume() {
        if (audioInitialized && root.active && root.audio.available)
            volumeTimeout.restart()
    }
    Connections {
        target: root.audio
        function onLevelChanged() { root.flashVolume() }
        function onMutedChanged() { root.flashVolume() }
        function onAvailableChanged() {
            root.audioInitialized = false
            initializeAudio.restart()
        }
    }
    // Initial PipeWire synchronization is not a user event.
    Timer {
        id: initializeAudio
        interval: 800
        running: true
        onTriggered: root.audioInitialized = true
    }
    Timer { id: volumeTimeout; interval: 1800 }

    component IslandText: Text {
        color: root.tokens.color.text
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.type.body.size
        font.weight: root.tokens.type.body.weight
        font.features: ({ "tnum": 1, "lnum": 1 })
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }

    Item {
        id: restingContent
        anchors.fill: parent
        readonly property real sideWidth: Math.max(clockLabel.implicitWidth, dateLabel.implicitWidth)
        readonly property real elementGap: Math.max(0,
            (width - 44 - sideWidth * 2 - fox.width - 2) / 4)
        // Music uses more of the side slots while preserving equal fox gutters.
        readonly property real foxGap: root.playingTitle.length > 0
            ? Math.min(32, elementGap) : elementGap
        opacity: root.showingVolume || root.showingNotification ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast }
        }
        IslandText {
            id: clockLabel
            x: (fox.x - restingContent.foxGap - 1 - width) / 2
            height: parent.height
            width: implicitWidth
            verticalAlignment: Text.AlignVCenter
            text: Qt.formatTime(clock.date, "HH:mm:ss")
            font.pixelSize: 16
            font.letterSpacing: 0.4
        }
        Rectangle {
            x: fox.x - restingContent.foxGap - width
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14
            color: root.tokens.color.accentSoft
            opacity: 0.6
        }
        Fox {
            id: fox
            testMode: root.testMode
            hovered: hover.containsMouse && hover.mouseX >= fox.x && hover.mouseX <= fox.x + fox.width
                     && hover.mouseY >= fox.y && hover.mouseY <= fox.y + fox.height
            hoverPosition: Qt.point(hover.mouseX - fox.x, hover.mouseY - fox.y)
            anchors.centerIn: parent
            tokens: root.tokens
            audioReaction: root.audioReaction
            unread: root.notifications ? root.notifications.unreadCount > 0 : false
            active: root.active && !root.showingVolume && !root.showingNotification
            reducedMotion: root.tokens.motion.off
        }
        Rectangle {
            x: fox.x + fox.width + restingContent.foxGap
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14
            color: root.tokens.color.accentSoft
            opacity: 0.6
        }
        IslandText {
            id: dateLabel
            visible: root.playingTitle.length === 0
            x: fox.x + fox.width + restingContent.foxGap + 1
               + (parent.width - fox.x - fox.width - restingContent.foxGap - 1 - width) / 2
            height: parent.height
            width: implicitWidth
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignRight
            text: Qt.formatDate(clock.date, "dd MMM")
            color: root.tokens.color.textMuted
        }
        MarqueeText {
            x: fox.x + fox.width + restingContent.foxGap + 16
            width: Math.max(0, parent.width - x - 16)
            centered: root.expansionProgress > 0.5
            height: parent.height
            tokens: root.tokens
            text: root.playingTitle
            visible: text.length > 0
            active: root.active && restingContent.visible && !root.showingVolume && !root.showingNotification
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.showingVolume && !root.showingNotification ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast }
        }
        IslandText {
            x: 22
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: root.audio.muted ? "Без звука" : "Громкость"
            color: root.audio.muted ? root.tokens.color.secondary : root.tokens.color.text
        }
        Rectangle {
            x: 104
            width: 164
            height: 4
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.tokens.color.background
            Rectangle {
                width: Math.min(1, root.audio.level) * parent.width
                height: parent.height
                radius: 2
                color: root.audio.muted ? root.tokens.color.secondary : root.tokens.color.accent
            }
        }
        IslandText {
            anchors.right: parent.right
            anchors.rightMargin: 22
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: Math.round(root.audio.level * 100) + "%"
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.showingNotification ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast } }
        Image {
            id: notificationIcon
            x: 16; anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24
            source: root.notification && root.notification.appIcon ? Quickshell.iconPath(root.notification.appIcon) : ""
            fillMode: Image.PreserveAspectFit
        }
        Column {
            x: 50; width: parent.width - 68; anchors.verticalCenter: parent.verticalCenter
            IslandText {
                width: parent.width; elide: Text.ElideRight; font.pixelSize: 12
                color: root.tokens.color.textMuted
                text: root.notification ? root.notification.appName + " · " + root.notification.summary : ""
            }
            IslandText {
                width: parent.width; elide: Text.ElideRight
                text: root.notification ? root.notification.body : ""
            }
        }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton)
                root.audio.toggleMuted()
            else if (mouse.button === Qt.RightButton) {
                root.toggleContextMenu()
            }
        }
        onWheel: function(wheel) {
            if (wheel.angleDelta.y !== 0 && root.audio.available) {
                root.audio.setVolume(root.audio.level + wheel.angleDelta.y / 120 * 0.05)
                root.flashVolume()
                wheel.accepted = true
            } else {
                wheel.accepted = false
            }
        }
    }
    PopupWindow {
        id: islandMenu
        visible: root.menuOpened
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 8
        implicitWidth: 224
        implicitHeight: 100
        color: "transparent"
        grabFocus: true
        onVisibleChanged: {
            if (!visible)
                root.menuOpened = false
            else
                Qt.callLater(function() { launcherAction.forceActiveFocus(Qt.TabFocusReason) })
        }
        Rectangle {
            anchors.fill: parent
            radius: root.tokens.radius.small + 8
            color: root.tokens.color.surfaceAlt
            border.width: 1
            border.color: root.tokens.color.border
            Column {
                x: 8
                y: 8
                width: parent.width - 16
                spacing: 4
                Keys.onEscapePressed: root.menuOpened = false
                Keys.onUpPressed: {
                    if (launcherAction.activeFocus)
                        settingsAction.forceActiveFocus(Qt.TabFocusReason)
                    else
                        launcherAction.forceActiveFocus(Qt.TabFocusReason)
                }
                Keys.onDownPressed: {
                    if (launcherAction.activeFocus)
                        settingsAction.forceActiveFocus(Qt.TabFocusReason)
                    else
                        launcherAction.forceActiveFocus(Qt.TabFocusReason)
                }
                StatusButton {
                    id: launcherAction
                    tokens: root.tokens
                    width: parent.width
                    height: 40
                    text: "Лаунчер"
                    Accessible.name: text
                    onClicked: {
                        root.menuOpened = false
                        Qt.callLater(root.launcherRequested)
                    }
                }
                StatusButton {
                    id: settingsAction
                    tokens: root.tokens
                    width: parent.width
                    height: 40
                    text: "Настройки"
                    Accessible.name: text
                    onClicked: {
                        root.menuOpened = false
                        Qt.callLater(root.settingsRequested)
                    }
                }
            }
        }
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: root.dashboardRequested()
    Accessible.name: "Nayori island, " + Qt.formatTime(clock.date, "HH:mm:ss")
                     + ", " + Qt.formatDate(clock.date, "dddd, d MMMM")
    Accessible.description: "Hover opens the dashboard. Right click opens the menu. Scroll adjusts volume. Middle click mutes."
}
