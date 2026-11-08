pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../island"

// Adapted from GGcoder11mf/maximal-shell, shell/modules/Stage.qml.
// https://github.com/GGcoder11mf/maximal-shell/blob/main/shell/modules/Stage.qml
// Author's permission confirmed by the user. Uses Nayori's shared services.
PanelWindow {
    id: root
    required property var tokens
    required property var music
    property var audioReaction: null
    signal closeRequested()
    readonly property var player: music ? music.player : null
    readonly property bool playing: !!player && player.isPlaying
    readonly property bool audioActive: visible && !tokens.motion.off
    readonly property real energy: audioActive && playing && audioReaction && audioReaction.available
        ? Math.max(0, Math.min(1, Number(audioReaction.energy) || 0)) : 0
    readonly property var spectrum: audioActive && playing && audioReaction && audioReaction.available
        ? audioReaction.spectrum || [] : []
    readonly property url art: player && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property real duration: music && music.track ? Math.max(0, Number(music.track.duration) || 0) : 0
    readonly property real position: player && player.positionSupported !== false ? Math.max(0, Math.min(duration, Number(music.position) || 0)) : 0
    readonly property bool hasLyrics: music && music.status === "synced" && music.lines.length > 0
    function updateConsumers(active) {
        if (music) music.consumer("music-stage", active)
        if (audioReaction) audioReaction.consumer("music-stage", active && audioActive)
    }
    function timeText(seconds) {
        const n = Math.max(0, Math.floor(seconds))
        return Math.floor(n / 60) + ":" + String(n % 60).padStart(2, "0")
    }
    Component.onCompleted: { updateConsumers(true); Qt.callLater(function() { stage.forceActiveFocus() }) }
    Component.onDestruction: updateConsumers(false)
    onAudioActiveChanged: updateConsumers(visible)
    color: tokens.color.background
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nayori-music-stage"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Image {
        id: bgArt
        anchors.centerIn: parent
        width: parent.width * 1.25; height: parent.height * 1.25
        source: root.art; fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(320, 320); asynchronous: true; visible: false
    }
    MultiEffect {
        anchors.fill: bgArt; source: bgArt; visible: bgArt.status === Image.Ready
        blurEnabled: true; blur: 1; blurMax: 64
        saturation: 0.35; brightness: -0.22; opacity: 0.85
        scale: 1 + root.energy * 0.04
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.tokens.color.background, 0.35) }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1; color: Qt.alpha(root.tokens.color.background, 0.75) }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
    FocusScope {
        id: stage
        anchors.fill: parent; focus: true
        Keys.onEscapePressed: event => { event.accepted = true; root.closeRequested() }
        Keys.onSpacePressed: event => {
            if (root.player && root.player.canTogglePlaying !== false) root.player.togglePlaying()
            event.accepted = true
        }
        Column {
            x: Math.min(70, parent.width * 0.04); y: Math.min(56, parent.height * 0.05)
            Text { text: Qt.formatDateTime(clock.date, "HH:mm"); font.family: root.tokens.type.display.family; font.pixelSize: 54; font.bold: true; color: root.tokens.color.accent }
            Text { text: Qt.formatDateTime(clock.date, "dddd · d MMMM").toUpperCase(); font.family: root.tokens.type.body.family; font.pixelSize: 12; font.letterSpacing: 3; color: root.tokens.color.textMuted }
        }
        IslandAction { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 40; tokens: root.tokens; text: "Закрыть · Esc"; onClicked: root.closeRequested() }
        Item {
            id: scene
            width: 1290; height: 720
            anchors.centerIn: parent
            scale: 0.5 * Math.max(0, Math.min((parent.width - 80) / width, (parent.height - 220) / height))
            MouseArea { anchors.fill: parent } // Content clicks must not close the scene.
            Item {
                id: disc
                width: 560; height: 560
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: 96
                    Rectangle {
                        id: ray
                        required property int index
                        // Mirror 48 actual frequency bands around the cover.
                        readonly property int band: index < 48 ? index : 95 - index
                        readonly property real value: Number(root.spectrum[band]) || 0
                        width: 4; height: 6 + value * 80; radius: 2
                        x: disc.width / 2 - width / 2
                        y: disc.height / 2 - 190 - 18 - height
                        color: root.tokens.color.accent
                        opacity: 0.55 + value * 0.45
                        transform: Rotation { origin.x: ray.width / 2; origin.y: ray.height + 208; angle: ray.index * 360 / 96 }
                    }
                }
                Rectangle {
                    id: cover
                    anchors.centerIn: parent; width: 380; height: width
                    radius: width / 2; color: root.tokens.color.surface
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: coverMask }
                    Image { id: coverImage; anchors.fill: parent; source: root.art; asynchronous: true; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(760, 760) }
                    Text { anchors.centerIn: parent; visible: coverImage.status !== Image.Ready; text: "♪"; font.pixelSize: 100; color: root.tokens.color.textMuted }
                }
                Rectangle { id: coverMask; anchors.fill: cover; radius: cover.radius; color: "white"; layer.enabled: true; visible: false }
            }
            Item {
                id: information
                x: 650; width: 640; height: parent.height
                Column {
                    id: metadata
                    width: parent.width; spacing: 6
                    Text { width: parent.width; text: root.player ? String(root.player.identity || root.player.desktopEntry || "").toUpperCase() : ""; font.family: root.tokens.type.body.family; font.pixelSize: 12; font.bold: true; font.letterSpacing: 3; color: root.tokens.color.accent; elide: Text.ElideRight }
                    Text { width: parent.width; text: root.player ? root.music.track.title : "Нет активного плеера"; textFormat: Text.PlainText; font.family: root.tokens.type.display.family; font.pixelSize: 58; font.bold: true; color: root.tokens.color.accent; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                    Text { width: parent.width; text: root.player ? root.music.track.artist : ""; textFormat: Text.PlainText; font.family: root.tokens.type.body.family; font.pixelSize: 24; color: root.tokens.color.text; elide: Text.ElideRight }
                }
                Item {
                    anchors.top: metadata.bottom; anchors.topMargin: 18
                    anchors.bottom: progress.top; anchors.bottomMargin: 18
                    width: parent.width; clip: true
                    ListView {
                        id: lyrics
                        anchors.fill: parent
                        visible: root.hasLyrics
                        model: root.hasLyrics ? root.music.lines : []
                        interactive: false
                        currentIndex: root.music.currentIndex
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        preferredHighlightBegin: height / 2 - 24
                        preferredHighlightEnd: height / 2 + 24
                        highlightMoveDuration: root.tokens.motion.off ? 0 : root.tokens.motion.base
                        spacing: 8
                        delegate: Text {
                            required property var modelData
                            required property int index
                            readonly property int distance: Math.abs(index - root.music.currentIndex)
                            width: lyrics.width
                            text: modelData.text || "♪"; textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            font.family: root.tokens.type.display.family
                            font.pixelSize: distance === 0 ? 30 : 22
                            font.weight: distance === 0 ? Font.Bold : Font.Medium
                            color: distance === 0 ? root.tokens.color.accent : Qt.alpha(root.tokens.color.text, Math.max(0.15, 0.55 - distance * 0.12))
                            Behavior on font.pixelSize { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast } }
                        }
                    }
                    Flickable {
                        anchors.fill: parent; visible: !root.hasLyrics
                        contentHeight: fallback.implicitHeight; clip: true
                        Text { id: fallback; width: parent.width; text: root.music.plainText || (root.music.status === "loading" ? "Ищем текст песни…" : "Синхронный текст недоступен"); wrapMode: Text.Wrap; font.family: root.tokens.type.body.family; font.pixelSize: 22; color: root.tokens.color.textMuted }
                    }
                }
                Slider {
                    id: progress
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.bottom: controls.top; anchors.bottomMargin: 18
                    from: 0; to: Math.max(1, root.duration); value: root.position
                    enabled: !!root.player && root.player.canSeek && root.duration > 0
                    Accessible.name: "Позиция воспроизведения"
                    onMoved: { root.player.position = value; root.music.syncPosition(false) }
                }
                Row {
                    id: controls
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                    height: 70; spacing: 14
                    Text { anchors.verticalCenter: parent.verticalCenter; text: root.timeText(root.position); font.family: root.tokens.type.body.family; font.pixelSize: 12; color: root.tokens.color.textMuted }
                    Transport { name: "prev"; caption: "Предыдущий трек"; enabled: !!root.player && root.player.canGoPrevious; onClicked: root.player.previous() }
                    Transport { name: root.playing ? "pause" : "play"; caption: root.playing ? "Приостановить" : "Воспроизвести"; enabled: !!root.player && root.player.canTogglePlaying; onClicked: root.player.togglePlaying() }
                    Transport { name: "next"; caption: "Следующий трек"; enabled: !!root.player && root.player.canGoNext; onClicked: root.player.next() }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: root.timeText(root.duration); font.family: root.tokens.type.body.family; font.pixelSize: 12; color: root.tokens.color.textMuted }
                }
            }
        }
    }
    component Transport: AbstractButton {
        id: button
        property string name: "play"
        property string caption: ""
        width: 64; height: 64
        focusPolicy: Qt.StrongFocus; hoverEnabled: true
        Accessible.name: caption
        background: Rectangle { radius: width / 2; color: button.hovered || button.down ? root.tokens.color.surfaceAlt : "transparent"; border.width: button.visualFocus ? 2 : 0; border.color: root.tokens.color.accent }
        contentItem: Item { MusicTransportIcon { anchors.centerIn: parent; width: 30; height: 30; name: button.name; ink: root.tokens.color.text; opacity: button.enabled ? 1 : 0.4 } }
    }
}
