pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../island"

Item {
    id: root
    required property var tokens
    property var music: null
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

    Column {
        anchors.fill: parent
        visible: root.player !== null
        spacing: 8
        Row {
            width: parent.width
            spacing: 10
            Rectangle {
                id: cover
                width: root.large ? 72 : 52
                height: width
                radius: root.tokens.radius.small
                color: root.tokens.color.surface
                clip: true
                AlbumArt {
                    anchors.fill: parent
                    requestedSource: root.artUrl
                }
            }
            Column {
                width: Math.max(0, parent.width - cover.width - parent.spacing)
                spacing: 2
                DesktopLabel {
                    width: parent.width
                    tokens: root.tokens
                    text: root.title
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
                DesktopLabel {
                    width: parent.width
                    visible: root.album !== ""
                    tokens: root.tokens
                    muted: true
                    text: root.album
                    font.pixelSize: root.tokens.type.small.size
                }
            }
        }
        Rectangle {
            width: parent.width
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
        Row {
            spacing: 8
            AbstractButton {
                id: previousButton
                implicitWidth: 32
                implicitHeight: 32
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
                contentItem: MusicTransportIcon {
                    name: "prev"
                    ink: root.tokens.color.text
                    width: 16
                    height: 16
                    anchors.centerIn: parent
                }
            }
            AbstractButton {
                id: playButton
                implicitWidth: 32
                implicitHeight: 32
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                enabled: !!root.player && root.player.canTogglePlaying !== false
                Accessible.name: root.player && root.player.isPlaying ? "Приостановить" : "Воспроизвести"
                onClicked: root.player.togglePlaying()
                background: Rectangle {
                    radius: root.tokens.radius.small
                    color: playButton.down || playButton.hovered ? root.tokens.color.accentHover : root.tokens.color.accent
                    opacity: playButton.enabled ? 1 : 0.4
                    border.width: playButton.visualFocus ? 1 : 0
                    border.color: root.tokens.color.text
                }
                contentItem: MusicTransportIcon {
                    name: root.player && root.player.isPlaying ? "pause" : "play"
                    ink: root.tokens.color.accentText
                    width: 16
                    height: 16
                    anchors.centerIn: parent
                }
            }
            AbstractButton {
                id: nextButton
                implicitWidth: 32
                implicitHeight: 32
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
                contentItem: MusicTransportIcon {
                    name: "next"
                    ink: root.tokens.color.text
                    width: 16
                    height: 16
                    anchors.centerIn: parent
                }
            }
        }
    }
}
