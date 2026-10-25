pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../services/status"

Rectangle {
    id: root
    required property var tokens
    property var musicService: null
    readonly property var player: {
        if (root.musicService) return root.musicService.player && root.musicService.player.isPlaying ? root.musicService.player : null
        if (root.testMode) return null
        const players = Mpris.players.values
        for (let i = 0; i < players.length; ++i)
            if (players[i].isPlaying) return players[i]
        return null
    }
    readonly property string playingTitle: player ? (player.trackTitle || "Без названия") : ""
    readonly property var lyrics: musicService ? musicService.lyrics : null
    readonly property bool compactLyrics: !!player && !!lyrics &&
        ((lyrics.status === "synced" && lyrics.lines && lyrics.lines.length > 0) ||
         (lyrics.status === "plain" && !!lyrics.plainText))
    readonly property bool showingLyrics: compactLyrics && expansionProgress < 0.01
    readonly property string compactLyricText: {
        if (!lyrics) return ""
        const line = lyrics.status === "synced" ? lyrics.currentLine || "♪"
            : (lyrics.plainText || "").split("\n").find(value => value.trim()) || ""
        return line.replace(/\s+/g, " ").trim()
    }
    property real lyricProgress: showingLyrics ? 1 : 0
    Behavior on lyricProgress { NumberAnimation { duration: root.tokens.motion.off ? 0 : 250; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.77, 0, 0.175, 1, 1, 1] } }
    property bool testMode: false
    property var audioReaction: null
    property var notifications: null
    readonly property var notification: notifications ? notifications.current : null
    readonly property bool showingNotification: notification !== null && expansionProgress < 0.01
    property bool drawChrome: true
    property bool active: true
    property real expansionProgress: 0
    property bool islandRotationEnabled: true
    property int islandRotationSeconds: 15
    property string weatherCity: ""
    property var weather: null
    property string weatherError: ""
    signal dashboardRequested()
    signal launcherRequested()
    signal settingsRequested()
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
    color: drawChrome ? tokens.material.island : "transparent"
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

    readonly property bool weatherReady: {
        if (weatherCity.trim() === "") return false
        if (weatherError !== "") return false
        if (!weather) return false
        const temp = weather.temp_C
        if (temp === undefined || temp === null) return false
        const text = String(temp).trim()
        return text !== "" && isFinite(Number(temp))
    }
    readonly property bool rotationBlocked: expansionProgress >= 0.01
        || playingTitle.length > 0
        || showingVolume
        || showingNotification
    readonly property int rotationIntervalMs: {
        const seconds = Number(islandRotationSeconds)
        if (!isFinite(seconds)) return 15000
        return Math.max(5, Math.min(120, Math.round(seconds))) * 1000
    }
    readonly property bool weatherFace: islandRotationEnabled && weatherReady && cycle.showWeather
    onIslandRotationEnabledChanged: if (!islandRotationEnabled) cycle.showWeather = false
    onWeatherReadyChanged: if (!weatherReady) cycle.showWeather = false
    QtObject {
        id: cycle
        property bool showWeather: false
    }
    Timer {
        id: rotationTimer
        interval: root.rotationIntervalMs
        repeat: true
        running: root.active && root.islandRotationEnabled && root.weatherReady && !root.rotationBlocked
        onTriggered: {
            if (!root.islandRotationEnabled || !root.weatherReady || root.rotationBlocked) return
            cycle.showWeather = !cycle.showWeather
        }
        onIntervalChanged: if (rotationTimer.running) rotationTimer.restart()
    }

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
        opacity: root.showingVolume || root.showingNotification ? 0 : 1 - root.lyricProgress
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
            active: root.active && restingContent.visible && !root.showingVolume && !root.showingNotification
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
        // Measured from the date string so weather cannot change foxGap or compactWidth.
        Item {
            id: rightSlot
            visible: root.playingTitle.length === 0 || root.expansionProgress >= 0.01
            height: parent.height
            width: dateLabel.implicitWidth
            x: fox.x + fox.width + restingContent.foxGap + 1
               + (parent.width - fox.x - fox.width - restingContent.foxGap - 1 - width) / 2
            IslandText {
                id: dateLabel
                height: parent.height
                width: implicitWidth
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: Qt.formatDate(clock.date, "dd MMM")
                color: root.tokens.color.textMuted
                opacity: root.weatherFace ? 0 : 1
                Behavior on opacity {
                    NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast }
                }
            }
            Item {
                anchors.fill: parent
                clip: true
                opacity: root.weatherFace ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast }
                }
                WeatherGlyph {
                    id: weatherIcon
                    tokens: root.tokens
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 12.25
                    weatherCode: root.weather ? root.weather.weatherCode : null
                }
                IslandText {
                    id: tempLabel
                    x: weatherIcon.width + 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.weatherReady && root.weather ? root.weather.temp_C + "°" : ""
                    color: root.tokens.color.textMuted
                }
            }
        }
        MarqueeText {
            x: fox.x + fox.width + restingContent.foxGap + 16
            width: Math.max(0, parent.width - x - 16)
            height: parent.height
            centered: true
            tokens: root.tokens
            text: root.playingTitle
            visible: text.length > 0 && root.expansionProgress < 0.01
            active: root.active && restingContent.visible && !root.showingLyrics
        }
    }

    MarqueeText {
        id: compactLyricsText
        objectName: "compactMusicLyrics"
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        tokens: root.tokens
        centered: true
        text: root.compactLyricText
        opacity: root.showingVolume || root.showingNotification ? 0 : root.lyricProgress
        visible: opacity > 0
        active: root.active && root.showingLyrics && visible
        transform: Translate { x: root.tokens.motion.off ? 0 : 24 * (1 - root.lyricProgress) }
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
        acceptedButtons: Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton)
                root.audio.toggleMuted()
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
    Accessible.role: Accessible.Button
    Accessible.onPressAction: root.dashboardRequested()
    Accessible.name: "Nayori island, " + Qt.formatTime(clock.date, "HH:mm:ss")
                     + ", " + Qt.formatDate(clock.date, "dddd, d MMMM")
                     + (weatherReady && weather ? ", " + weather.temp_C + "°" : "")
    Accessible.description: "Hover opens the dashboard. Scroll adjusts volume. Middle click mutes."
}
