pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../services/island/IslandRow.js" as RowPlan
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
        lyrics.status === "synced" && lyrics.lines && lyrics.lines.length > 0
    readonly property bool showingLyrics: compactLyrics && expansionProgress < 0.01
    readonly property string compactLyricText: {
        if (!lyrics) return ""
        const line = lyrics.status === "synced" ? lyrics.currentLine || "♪" : ""
        return line.replace(/\s+/g, " ").trim()
    }
    property real lyricProgress: showingLyrics ? 1 : 0
    Behavior on lyricProgress { NumberAnimation { duration: root.tokens.motion.off ? 0 : 250; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.77, 0, 0.175, 1, 1, 1] } }
    readonly property real lyricEnd: {
        if (!lyrics || !lyrics.lines || typeof lyrics.currentIndex !== "number") return 0
        const next = lyrics.lines[lyrics.currentIndex + 1]
        return next ? next.t : (player && player.length ? player.length : 0)
    }
    readonly property string audioKey: "island-border-" + String(root)
    readonly property bool wantsAudio: active && visible && !!player && !tokens.motion.off
    readonly property real volumeTarget: {
        if (!wantsAudio || !audioReaction || !audioReaction.available) return 0
        const volume = Number(audioReaction.volume) || 0
        const reference = Number(audioReaction.volumeReference) || 0
        return Math.max(0, Math.min(1, volume / Math.max(0.016, reference * 2)))
    }
    property real musicPulse: 0
    property bool volumeRising: false
    onVolumeTargetChanged: {
        volumeRising = volumeTarget > musicPulse
        musicPulse = volumeTarget
    }
    Behavior on musicPulse {
        NumberAnimation {
            duration: !root.wantsAudio ? 0 : root.volumeRising ? 80 : 250
            easing.type: Easing.Linear
        }
    }
    function updateAudioConsumer() {
        if (audioReaction) audioReaction.consumer(audioKey, wantsAudio)
    }
    onWantsAudioChanged: updateAudioConsumer()
    onAudioReactionChanged: updateAudioConsumer()
    Component.onDestruction: { if (audioReaction) audioReaction.consumer(audioKey, false) }
    property bool testMode: false
    property var audioReaction: null
    property var notifications: null
    NotificationCollapsed {
        id: collapsedBanner
        notifications: root.notifications
    }
    // Самое новое подходящее уведомление, 30 с. Срок не делает его прочитанным.
    readonly property var notification: collapsedBanner.current
    readonly property bool showingNotification: notification !== null && expansionProgress < 0.01
    property bool drawChrome: true
    property bool active: true
    property real expansionProgress: 0
    // Set by MorphingIsland while expanded: the fox follows this cursor (own coordinates).
    property bool lookActive: false
    property point lookPoint: Qt.point(0, 0)
    property bool contentYielded: false
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

    property var heldPlayer: null
    readonly property bool heldAlive: !!heldPlayer && (musicService ? musicService.player === heldPlayer : !testMode && Mpris.players.values.indexOf(heldPlayer) >= 0)
    readonly property var controlPlayer: player || (heldAlive && pauseHold.running ? heldPlayer : null)
    onPlayerChanged: {
        if (player) { heldPlayer = player; pauseHold.stop() }
        else if (heldPlayer) pauseHold.restart()
    }
    Timer { id: pauseHold; interval: 10000 }
    readonly property var pending: collapsedBanner.pending
    readonly property var rowPlan: RowPlan.plan({
        yielded: contentYielded || expansionProgress >= 0.01,
        volume: showingVolume, notification: showingNotification,
        lyrics: showingLyrics, title: playingTitle, controls: !!controlPlayer,
        pending: pending.length
    })
    readonly property var rowMetrics: ({ pad: 6, right: 12, plus: 12, icon: 18, iconGap: 3, clock: 64, controls: 84 })
    readonly property var rowTail: RowPlan.tail(rowPlan, rowMetrics)
    readonly property var rowSize: RowPlan.size(notification ? Math.min(mainWidth, 520 - rowTail.width) : mainWidth, rowTail.width, notification ? 240 : 336)
    readonly property real contentWidth: expansionProgress < 0.01 ? Math.max(0, width - rowTail.width) : width
    // Grow modestly for music; long titles still scroll within a bounded slot.
    readonly property real compactWidth: rowSize.total
    readonly property string notificationText: notification ? String(notification.body || "").replace(/\s+/g, " ").trim() : ""
    readonly property real mainWidth: notification
        ? Math.min(520, Math.max(240, notificationMetrics.advanceWidth + 68, notificationSourceMetrics.advanceWidth + 68))
        : playingTitle.length > 0
        ? Math.min(448, Math.max(400, titleMetrics.advanceWidth * 2 + 140)) : 352
    TextMetrics {
        id: titleMetrics
        text: root.playingTitle
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.type.body.size
        font.weight: root.tokens.type.body.weight
    }

    TextMetrics {
        id: notificationMetrics
        text: root.notificationText
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.type.body.size
        font.weight: root.tokens.type.body.weight
    }
    TextMetrics {
        id: notificationSourceMetrics
        text: root.notification ? (root.notification.appName + " · " + root.notification.summary).replace(/\s+/g, " ").trim() : ""
        font.family: root.tokens.type.body.family
        font.pixelSize: 12
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
        || contentYielded
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
        width: root.contentWidth; height: parent.height
        readonly property real sideWidth: Math.max(clockLabel.implicitWidth, dateLabel.implicitWidth)
        readonly property real elementGap: Math.max(0,
            (width - 44 - sideWidth * 2 - fox.width - 2) / 4)
        // Music uses more of the side slots while preserving equal fox gutters.
        readonly property real foxGap: root.playingTitle.length > 0
            ? Math.min(32, elementGap) : elementGap
        opacity: root.contentYielded || root.rowPlan.main === "volume" || root.showingNotification ? 0 : 1 - root.lyricProgress
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
            lookActive: root.lookActive
            lookPosition: Qt.point(root.lookPoint.x - fox.x, root.lookPoint.y - fox.y)
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
            loop: true
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
        loop: false
        animateLines: true
        objectName: "compactMusicLyrics"
        x: 22; width: root.contentWidth - 44; height: parent.height
        tokens: root.tokens
        centered: true
        text: root.compactLyricText
        words: root.lyrics && root.lyrics.status === "synced" ? root.lyrics.currentWords || [] : []
        position: root.lyrics && typeof root.lyrics.position === "number" ? root.lyrics.position : 0
        lineEnd: root.lyricEnd
        opacity: root.contentYielded || root.rowPlan.main === "volume" || root.showingNotification ? 0 : root.lyricProgress
        visible: opacity > 0
        active: root.active && root.showingLyrics && visible
        transform: Translate { x: root.tokens.motion.off ? 0 : 24 * (1 - root.lyricProgress) }
    }

    Item {
        width: root.contentWidth; height: parent.height
        opacity: root.showingVolume && !root.contentYielded ? 1 : 0
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
        width: root.contentWidth; height: parent.height
        opacity: root.showingNotification && !root.showingVolume && !root.contentYielded ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast } }
        NotificationIcon {
            id: pinnedIcon
            objectName: "compactNotificationIcon"
            x: 16; anchors.verticalCenter: parent.verticalCenter
            tokens: root.tokens; record: root.notification || ({}); size: 24
        }
        Column {
            x: 50; width: parent.width - 68; anchors.verticalCenter: parent.verticalCenter
            IslandText {
                objectName: "compactNotificationSource"
                wrapMode: Text.NoWrap
                width: parent.width; elide: Text.ElideRight; font.pixelSize: 12
                color: root.tokens.color.textMuted
                text: root.notification ? (root.notification.appName + " · " + root.notification.summary).replace(/\s+/g, " ").trim() : ""
            }
            MarqueeText {
                objectName: "compactNotificationText"
                visible: text !== ""
                tokens: root.tokens
                ink: root.tokens.color.text
                width: parent.width; height: root.tokens.type.body.size + 4
                text: root.notificationText
                active: root.active && root.showingNotification && !root.showingVolume && !root.contentYielded
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
    Item {
        id: tail
        objectName: "compactTail"
        x: root.contentWidth; width: root.rowTail.width; height: parent.height
        visible: !root.rowPlan.hidden
        z: 2
        Repeater {
            model: root.rowTail.dividers
            Rectangle {
                required property real modelData
                x: modelData; width: 1; height: 14
                anchors.verticalCenter: parent.verticalCenter
                color: root.tokens.color.accentSoft; opacity: 0.6
            }
        }
        Row {
            x: root.rowTail.x.icons || 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.rowMetrics.iconGap
            visible: root.rowPlan.icons > 0
            Item {
                width: root.rowMetrics.plus; height: root.rowMetrics.icon
                Glyph {
                    anchors.centerIn: parent
                    width: 12; height: 12
                    name: "plus"
                    ink: root.tokens.color.textMuted
                }
            }
            Repeater {
                model: root.rowPlan.icons
                NotificationIcon {
                    required property int index
                    tokens: root.tokens; record: root.pending[index] || ({}); size: 18
                }
            }
        }

    }
    IslandBeatBorder {
        anchors.fill: parent
        z: 100
        visible: root.drawChrome && pulse > 0.001
        accent: root.tokens.color.accent
        cornerRadius: root.radius
        pulse: root.musicPulse
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: root.dashboardRequested()
    Accessible.name: "Nayori island, " + Qt.formatTime(clock.date, "HH:mm:ss")
                     + ", " + Qt.formatDate(clock.date, "dddd, d MMMM")
                     + (weatherReady && weather ? ", " + weather.temp_C + "°" : "")
    Accessible.description: "Hover opens the dashboard. Scroll adjusts volume. Middle click mutes."
}
