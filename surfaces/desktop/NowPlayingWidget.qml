pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// Adapted from GGcoder11mf/maximal-shell, shell/modules/NowPlaying.qml.
// https://github.com/GGcoder11mf/maximal-shell/blob/main/shell/modules/NowPlaying.qml
// Adaptation authorized by the original author, as confirmed by the user.
Item {
    id: root
    required property var tokens
    property var music: null
    property var audioReaction: null
    property bool visualActive: true
    signal stageRequested()

    readonly property var player: music ? music.player : null
    readonly property bool playing: !!player && player.isPlaying
    readonly property bool animate: visible && visualActive && !tokens.motion.off
    readonly property real level: animate && playing && audioReaction && audioReaction.available
        ? Math.max(0, Math.min(1, Number(audioReaction.energy) || 0)) : 0
    readonly property url art: player && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property real duration: music && music.track ? Math.max(0, Number(music.track.duration) || 0) : 0
    readonly property real position: music && player && player.positionSupported !== false
        ? Math.max(0, Math.min(duration, Number(music.position) || 0)) : 0
    readonly property bool hasLyrics: !!music && music.status === "synced" && music.lines.length > 0

    function timeText(seconds) {
        const value = Math.max(0, Math.floor(seconds))
        const hours = Math.floor(value / 3600)
        const minutes = Math.floor(value / 60) % 60
        const rest = String(value % 60).padStart(2, "0")
        return hours ? hours + ":" + String(minutes).padStart(2, "0") + ":" + rest : minutes + ":" + rest
    }

    // The reference uses a 520 × 300 composition. Scale the complete layout,
    // not individual rows, so lyric changes cannot shift the rest of the card.
    Item {
        id: layout
        width: 520
        height: 300
        anchors.centerIn: parent
        scale: Math.max(0, Math.min(root.width / width, root.height / height))

        Item {
            id: sleeve
            width: 180; height: 180
            anchors.right: parent.right
            anchors.top: parent.top

            Rectangle {
                id: vinyl
                width: 168; height: 168; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: root.playing ? -74 : -8
                Behavior on x { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.base; easing.type: Easing.OutCubic } }
                color: root.tokens.color.background
                border.width: 2
                border.color: Qt.alpha(root.tokens.color.accent, 0.35 + root.level * 0.5)
                RotationAnimation on rotation {
                    from: 0; to: 360; duration: 4000; loops: Animation.Infinite
                    running: root.animate
                    paused: !root.playing
                }
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        anchors.centerIn: parent
                        width: parent.width - 18 - index * 16; height: width; radius: width / 2
                        color: "transparent"; border.width: 1; border.color: root.tokens.color.border
                    }
                }
                Rectangle {
                    id: label
                    anchors.centerIn: parent
                    width: 56; height: 56; radius: width / 2
                    color: root.tokens.color.accentSoft
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: labelMask }
                    Image { anchors.fill: parent; source: root.art; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(112, 112); asynchronous: true }
                }
                Rectangle { id: labelMask; anchors.fill: label; radius: width / 2; color: "white"; visible: false; layer.enabled: true }
                Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: root.tokens.color.background }
            }
            Rectangle {
                id: sleeveArt
                anchors.fill: parent
                radius: root.tokens.radius.medium
                color: root.tokens.color.surface
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: artMask }
                Image {
                    id: image
                    anchors.fill: parent
                    source: root.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(360, 360)
                    asynchronous: true
                }
                Text { anchors.centerIn: parent; visible: image.status !== Image.Ready; text: "♪"; color: root.tokens.color.textMuted; font.pixelSize: 48 }
            }
            Rectangle { id: artMask; anchors.fill: sleeveArt; radius: sleeveArt.radius; color: "white"; visible: false; layer.enabled: true }
            AbstractButton {
                anchors.fill: parent
                enabled: !!root.player
                focusPolicy: Qt.StrongFocus
                Accessible.name: "Открыть музыкальную сцену"
                onClicked: root.stageRequested()
                background: Rectangle { color: "transparent"; radius: root.tokens.radius.medium; border.width: parent.visualFocus ? 2 : 0; border.color: root.tokens.color.accent }
            }
        }
        Item {
            id: information
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: sleeve.x - 96

            Column {
                id: meta
                width: parent.width
                spacing: 2
                Text {
                    width: parent.width
                    text: (root.playing ? "NOW PLAYING" : "PAUSED") + (root.player ? " · " + String(root.player.identity || root.player.desktopEntry || "Плеер").toUpperCase() : "")
                    font.family: root.tokens.type.body.family; font.pixelSize: 10; font.weight: Font.Black; font.letterSpacing: 2
                    color: root.tokens.color.accent; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.player && root.music.track.title ? root.music.track.title : "Нет активного плеера"
                    textFormat: Text.PlainText
                    font.family: root.tokens.type.display.family; font.pixelSize: 26; font.weight: Font.Bold
                    color: root.tokens.color.accent; horizontalAlignment: Text.AlignRight
                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.player && root.music.track.artist ? root.music.track.artist : ""
                    textFormat: Text.PlainText
                    font.family: root.tokens.type.body.family; font.pixelSize: 14
                    color: root.tokens.color.text; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                }
                Item {
                    width: Math.min(220, parent.width); height: 14
                    anchors.right: parent.right
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: root.tokens.color.border }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * (root.duration > 0 ? root.position / root.duration : 0); height: 4; radius: 2
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: root.tokens.color.accent } GradientStop { position: 1; color: root.tokens.color.secondary } }
                        Behavior on width { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.base; easing.type: Easing.Linear } }
                    }
                }
                Text {
                    width: parent.width
                    text: root.timeText(root.position) + " / " + root.timeText(root.duration)
                    font.family: root.tokens.type.body.family; font.pixelSize: 10
                    color: root.tokens.color.textMuted; horizontalAlignment: Text.AlignRight
                }
            }
            // A fixed area keeps the metadata in place even when lines wrap.
            Column {
                id: lyricBox
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: meta.bottom
                anchors.topMargin: 6
                height: 88
                spacing: 2
                visible: root.hasLyrics
                clip: true
                Lyric { width: lyricBox.width; height: 24; verticalAlignment: Text.AlignBottom; text: root.music ? root.music.previousLine : ""; dim: true }
                Lyric { width: lyricBox.width; height: 36; text: root.music ? (root.music.currentLine || "♪") : ""; current: true }
                Lyric { width: lyricBox.width; height: 24; verticalAlignment: Text.AlignTop; text: root.music ? root.music.nextLine : ""; dim: true }
            }
        }
    }
    component Lyric: Text {
        id: lyric
        property bool current: false
        property bool dim: false
        textFormat: Text.PlainText
        font.family: root.tokens.type.display.family
        font.pixelSize: current ? 17 : 12
        font.weight: current ? Font.Bold : Font.Normal
        fontSizeMode: Text.Fit
        minimumPixelSize: 7
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        color: dim ? root.tokens.color.textMuted : root.tokens.color.text
        Accessible.name: text
        HoverHandler { id: hover }
        ToolTip.visible: hover.hovered && lyric.text !== ""
        ToolTip.text: lyric.text
        ToolTip.delay: 500
        onTextChanged: if (current && root.animate && root.playing) fade.restart()
        NumberAnimation { id: fade; target: lyric; property: "opacity"; from: 0.4; to: 1; duration: root.tokens.motion.fast; easing.type: Easing.OutCubic }
        Connections { target: root; function onAnimateChanged() { if (!root.animate) { fade.stop(); lyric.opacity = 1 } } }
    }
}
