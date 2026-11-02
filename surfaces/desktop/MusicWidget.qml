pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../island"

Item {
    id: root
    required property var tokens
    property var music: null
    property var audioReaction: null
    property bool large: false

    readonly property var player: music ? music.player : null
    readonly property string title: {
        if (!player)
            return ""
        const fromPlayer = String(player.trackTitle || "")
        if (fromPlayer)
            return fromPlayer
        const fromTrack = music && music.track ? String(music.track.title || "") : ""
        return fromTrack || "Без названия"
    }
    readonly property string artist: {
        if (!player)
            return ""
        const fromPlayer = String(player.trackArtist || "")
        if (fromPlayer)
            return fromPlayer
        return music && music.track ? String(music.track.artist || "") : ""
    }
    readonly property string album: large && player ? String(player.trackAlbum || (music && music.track ? music.track.album || "" : "")) : ""
    readonly property real duration: {
        if (!player || player.lengthSupported === false)
            return 0
        const value = Number(player.length)
        return isFinite(value) && value > 0 ? value : 0
    }
    readonly property real position: {
        if (!player || duration <= 0 || player.positionSupported === false)
            return -1
        const fromService = music && typeof music.position === "number" && isFinite(music.position) ? music.position : NaN
        if (isFinite(fromService))
            return Math.max(0, fromService)
        const fromPlayer = Number(player.position)
        return isFinite(fromPlayer) ? Math.max(0, fromPlayer) : -1
    }
    readonly property url artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""

    function formatTime(seconds) {
        const value = Math.max(0, Math.floor(seconds))
        const minutes = Math.floor(value / 60)
        return minutes + ":" + String(value % 60).padStart(2, "0")
    }

    DesktopLabel {
        anchors.fill: parent
        visible: root.player === null
        tokens: root.tokens
        muted: true
        text: "Нет активного плеера"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        verticalAlignment: Text.AlignVCenter
        Accessible.name: text
    }

    Item {
        id: cover
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(root.large ? 120 : 88, parent.height)
        height: width
        visible: root.player !== null
        readonly property bool visualizing: root.player && root.player.isPlaying && !root.tokens.motion.off
            && root.audioReaction && root.audioReaction.available
        readonly property real level: visualizing ? Math.max(0, Math.min(1, Number(root.audioReaction.energy) || 0)) : 0

        Rectangle {
            anchors.fill: parent
            anchors.margins: 11
            radius: root.tokens.radius.small
            color: root.tokens.color.surface
            clip: true
            AlbumArt {
                anchors.fill: parent
                requestedSource: root.artUrl
            }
        }
        Canvas {
            id: waveform
            objectName: "desktop-music-waveform"
            anchors.fill: parent
            visible: cover.visualizing
            antialiasing: true
            readonly property real level: cover.level
            readonly property color ink: root.tokens.color.accent
            onLevelChanged: if (visible) requestPaint()
            onInkChanged: if (visible) requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onWidthChanged: if (visible) requestPaint()
            onHeightChanged: if (visible) requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = ink
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                const inset = 5.5
                const start = 13
                const end = Math.max(start, width - start)
                const far = width - inset
                const amplitude = 0.6 + level * 3.2
                ctx.beginPath()
                ctx.moveTo(start, inset)
                for (let edge = 0; edge < 4; edge++) {
                    for (let i = 1; i <= 36; i++) {
                        const t = i / 36
                        const ripple = Math.sin(t * Math.PI) * Math.sin(t * Math.PI * 6) * amplitude
                        const forward = start + (end - start) * t
                        const reverse = end - (end - start) * t
                        if (edge === 0) ctx.lineTo(forward, inset + ripple)
                        else if (edge === 1) ctx.lineTo(far - ripple, forward)
                        else if (edge === 2) ctx.lineTo(reverse, far - ripple)
                        else ctx.lineTo(inset + ripple, reverse)
                    }
                    if (edge === 0) ctx.quadraticCurveTo(far, inset, far, start)
                    else if (edge === 1) ctx.quadraticCurveTo(far, far, end, far)
                    else if (edge === 2) ctx.quadraticCurveTo(inset, far, inset, end)
                    else ctx.quadraticCurveTo(inset, inset, start, inset)
                }
                ctx.closePath()
                ctx.stroke()
            }
        }
    }
    Item {
        id: details
        anchors.left: cover.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: root.player !== null
        Column {
            anchors.top: parent.top
            width: parent.width
            spacing: 2
            DesktopLabel {
                width: parent.width
                tokens: root.tokens
                text: root.title
                display: true
                font.pixelSize: root.large ? 19 : 16
                Accessible.name: "Музыка, " + text
                Accessible.description: root.artist
            }
            DesktopLabel {
                width: parent.width
                visible: root.artist !== ""
                tokens: root.tokens
                muted: true
                text: root.artist
                font.pixelSize: root.tokens.type.small.size
            }
        }
        Rectangle {
            id: progress
            objectName: "desktop-music-progress"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: controls.top
            anchors.bottomMargin: root.duration > 0 ? 23 : 8
            height: 3
            radius: 1.5
            visible: root.position >= 0
            color: Qt.alpha(root.tokens.color.text, 0.14)
            Accessible.role: Accessible.ProgressBar
            Accessible.name: "Прогресс трека"
            Accessible.description: root.duration > 0 && root.position >= 0 ? Math.round(Math.min(1, root.position / root.duration) * 100) + "%" : "Позиция недоступна"
            Rectangle {
                width: parent.width * (root.duration > 0 && root.position >= 0 ? Math.max(0, Math.min(1, root.position / root.duration)) : 0)
                height: parent.height
                radius: parent.radius
                color: root.tokens.color.accent
            }
        }
        Item {
            anchors.top: progress.bottom
            anchors.topMargin: 3
            width: parent.width
            height: 16
            visible: progress.visible && root.duration > 0
            DesktopLabel {
                anchors.left: parent.left
                tokens: root.tokens
                muted: true
                font.pixelSize: 11
                text: root.formatTime(root.position)
            }
            DesktopLabel {
                anchors.right: parent.right
                tokens: root.tokens
                muted: true
                font.pixelSize: 11
                text: root.formatTime(root.duration)
            }
        }
        Row {
            id: controls
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: root.large ? 12 : 4
            AbstractButton {
                id: previousButton
                objectName: "desktop-music-previous"
                implicitWidth: 40
                implicitHeight: 40
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                enabled: !!root.player && root.player.canGoPrevious !== false
                Accessible.name: "Предыдущий трек"
                onClicked: root.player.previous()
                background: Rectangle {
                    radius: root.tokens.radius.small
                    color: previousButton.down ? root.tokens.color.surface : previousButton.hovered ? root.tokens.color.surfaceAlt : "transparent"
                    border.width: previousButton.visualFocus ? 1 : 0
                    border.color: root.tokens.color.accent
                    opacity: previousButton.enabled ? 1 : 0.4
                }
                contentItem: Item {
                    MusicTransportIcon {
                        name: "prev"
                        ink: root.tokens.color.text
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                    }
                }
            }
            AbstractButton {
                id: playButton
                objectName: "desktop-music-play"
                implicitWidth: 40
                implicitHeight: 40
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                enabled: !!root.player && root.player.canTogglePlaying !== false
                Accessible.name: root.player && root.player.isPlaying ? "Приостановить" : "Воспроизвести"
                onClicked: root.player.togglePlaying()
                background: Rectangle {
                    radius: width / 2
                    color: playButton.down || playButton.hovered ? root.tokens.color.accentHover : root.tokens.color.accent
                    opacity: playButton.enabled ? 1 : 0.4
                    border.width: playButton.visualFocus ? 2 : 0
                    border.color: root.tokens.color.text
                }
                contentItem: Item {
                    MusicTransportIcon {
                        name: root.player && root.player.isPlaying ? "pause" : "play"
                        ink: root.tokens.color.accentText
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                    }
                }
            }
            AbstractButton {
                id: nextButton
                objectName: "desktop-music-next"
                implicitWidth: 40
                implicitHeight: 40
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                enabled: !!root.player && root.player.canGoNext !== false
                Accessible.name: "Следующий трек"
                onClicked: root.player.next()
                background: Rectangle {
                    radius: root.tokens.radius.small
                    color: nextButton.down ? root.tokens.color.surface : nextButton.hovered ? root.tokens.color.surfaceAlt : "transparent"
                    border.width: nextButton.visualFocus ? 1 : 0
                    border.color: root.tokens.color.accent
                    opacity: nextButton.enabled ? 1 : 0.4
                }
                contentItem: Item {
                    MusicTransportIcon {
                        name: "next"
                        ink: root.tokens.color.text
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                    }
                }
            }
        }
    }
}
