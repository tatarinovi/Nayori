pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

IslandCard {
    id: root
    objectName: "musicCard"
    property var player: null
    property var players: []
    property var lyrics: null
    signal playerSelected(var selected)
    onPlayersChanged: { if (!players.length) sourceMenu.close() }
    property bool lyricsEnabled: !lyrics || typeof lyrics.lyricsEnabled !== "boolean" ? true : lyrics.lyricsEnabled
    readonly property bool hasLyrics: !!lyrics && ((lyrics.status === "synced" && lyrics.lines && lyrics.lines.length > 0) || (lyrics.status === "plain" && !!lyrics.plainText))
    readonly property bool lyricMode: hasLyrics && lyricsEnabled
    readonly property bool metadataVisible: !lyricMode
    property real lyricProgress: lyricMode ? 1 : 0
    Behavior on lyricProgress { NumberAnimation { duration: root.tokens.motion.off ? 0 : 250; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.77, 0, 0.175, 1, 1, 1] } }
    readonly property real controlsBottom: controls.y + controls.height
    function canScrollLyrics(delta) {
        return lyricMode && lyrics.status === "plain" && lyricHover.hovered &&
                ((delta < 0 && plainLyrics.contentY < plainLyrics.contentHeight - plainLyrics.height - 1) || (delta > 0 && plainLyrics.contentY > 1))
    }
    readonly property string lyricText: {
        if (!player || !lyrics) return ""
        if (lyrics.status === "loading") return ""
        if (lyrics.status === "instrumental") return ""
        if (lyrics.status === "synced") return lyrics.currentLine || "♪"
        if (lyrics.status === "plain") return lyrics.plainText || ""
        return ""
    }
    AlbumBackdrop { anchors.fill: parent; tokens: root.tokens; radius: root.radius; source: root.player ? root.player.trackArtUrl : "" }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 16
            IslandLabel { tokens: root.tokens; text: "Музыка"; font.pixelSize: 12; color: root.tokens.color.textMuted; Layout.fillWidth: true }
            AbstractButton {
                id: sourceButton
                objectName: "musicSourceButton"
                enabled: root.players.length > 0
                visible: root.player !== null
                text: root.player ? root.player.identity : ""
                implicitWidth: Math.min(160, contentItem.implicitWidth + 12)
                implicitHeight: 22
                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                Accessible.name: "Источник музыки: " + text
                Accessible.description: "Выбрать активный плеер"
                onClicked: sourceMenu.open()
                background: Rectangle { radius: root.tokens.radius.small; color: sourceButton.hovered ? Qt.alpha(root.tokens.color.surfaceAlt, 0.6) : "transparent"; border.width: sourceButton.visualFocus ? 1 : 0; border.color: root.tokens.color.accent }
                contentItem: IslandLabel { tokens: root.tokens; text: sourceButton.text + " ▾"; font.pixelSize: 12; color: root.tokens.color.textMuted; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter; maximumLineCount: 1 }
                Menu {
                    id: sourceMenu
                    objectName: "musicSourceMenu"
                    x: sourceButton.width - width
                    y: sourceButton.height + 4
                    width: 220
                    padding: 6
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    background: Rectangle { radius: root.tokens.radius.medium; color: root.tokens.color.surface; border.width: 1; border.color: root.tokens.color.border }
                    Instantiator {
                        model: root.players
                        delegate: MenuItem {
                            id: sourceItem
                            required property var modelData
                            text: modelData.identity || "Плеер"
                            checkable: true
                            checked: root.player === modelData
                            onTriggered: { root.playerSelected(modelData); sourceMenu.close() }
                            background: Rectangle { radius: root.tokens.radius.small; color: sourceItem.highlighted ? root.tokens.color.surfaceAlt : "transparent" }
                            contentItem: IslandLabel { tokens: root.tokens; text: (sourceItem.checked ? "●  " : "    ") + sourceItem.text; font.pixelSize: 13; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                        }
                        onObjectAdded: (index, object) => sourceMenu.insertItem(index, object)
                        onObjectRemoved: (index, object) => sourceMenu.removeItem(object)
                    }
                }
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 50
            clip: true
            Item {
                id: metadata
                anchors.fill: parent
                visible: opacity > 0
                opacity: 1 - root.lyricProgress
                transform: Translate { x: root.tokens.motion.off ? 0 : -32 * root.lyricProgress }
                RowLayout {
                    anchors.fill: parent
                    spacing: 10
                    Rectangle {
                        implicitWidth: 50; implicitHeight: 50; radius: 6
                        color: root.tokens.color.surfaceAlt
                        clip: true
                        Image { id: cover; anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
                        IslandLabel { tokens: root.tokens; anchors.centerIn: parent; text: "♪"; color: root.tokens.color.accent; font.pixelSize: 30; visible: cover.status !== Image.Ready }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        IslandLabel { tokens: root.tokens; Layout.fillWidth: true; text: root.player ? root.player.trackTitle || "Без названия" : "Тихая пауза"; font.family: root.tokens.type.display.family; font.weight: Font.Medium; font.pixelSize: 19; font.letterSpacing: -0.35; wrapMode: Text.NoWrap; maximumLineCount: 1; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; Accessible.name: text }
                        IslandLabel { tokens: root.tokens; Layout.fillWidth: true; text: root.player ? root.player.trackArtist : "Откройте музыку в любимом плеере"; color: root.tokens.color.textMuted; font.pixelSize: 12; wrapMode: Text.NoWrap; maximumLineCount: 1; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                    }
                }
            }
            Item {
                anchors.fill: parent
                visible: opacity > 0
                enabled: root.lyricMode
                opacity: root.lyricProgress
                transform: Translate { x: root.tokens.motion.off ? 0 : 32 * (1 - root.lyricProgress) }
                clip: true
                SyncedLyrics {
                    objectName: "musicLyrics"
                    anchors.fill: parent
                    tokens: root.tokens
                    lyrics: root.lyrics
                    visible: !!root.lyrics && root.lyrics.status === "synced"
                }
                Flickable {
                    id: plainLyrics
                    objectName: "plainMusicLyrics"
                    anchors.fill: parent
                    visible: !!root.lyrics && root.lyrics.status === "plain"
                    contentWidth: width
                    contentHeight: plainText.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    onVisibleChanged: contentY = 0
                    HoverHandler { id: lyricHover }
                    IslandLabel {
                        id: plainText
                        tokens: root.tokens
                        width: plainLyrics.width
                        text: root.lyrics ? root.lyrics.plainText || "" : ""
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                    }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
            }
        }
        RowLayout {
            id: controls
            visible: root.player !== null
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            IslandAction { tokens: root.tokens; implicitHeight: 32; text: "⏮"; Accessible.name: "Предыдущий трек"; enabled: !!root.player && root.player.canGoPrevious; onClicked: root.player.previous() }
            IslandAction { tokens: root.tokens; implicitHeight: 32; text: root.player && root.player.isPlaying ? "Ⅱ" : "▶"; Accessible.name: root.player && root.player.isPlaying ? "Приостановить" : "Воспроизвести"; enabled: !!root.player && root.player.canTogglePlaying; onClicked: root.player.togglePlaying() }
            IslandAction { tokens: root.tokens; implicitHeight: 32; text: "⏭"; Accessible.name: "Следующий трек"; enabled: !!root.player && root.player.canGoNext; onClicked: root.player.next() }
        }
    }
    IslandAction {
        id: lyricsToggle
        objectName: "musicLyricsToggle"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        tokens: root.tokens
        implicitHeight: 32
        visible: root.hasLyrics
        checkable: true
        checked: root.lyricsEnabled
        implicitWidth: 32
        text: ""
        contentItem: Item {
            // A lyric sheet with a musical note; independent of installed icon fonts.
            Canvas {
                anchors.centerIn: parent
                width: 18; height: 18
                property color ink: root.tokens.color.text
                onInkChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d")
                    c.clearRect(0, 0, width, height)
                    c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = 1.4
                    c.lineCap = "round"
                    c.beginPath()
                    c.moveTo(2, 4); c.lineTo(10, 4)
                    c.moveTo(2, 8); c.lineTo(8, 8)
                    c.moveTo(2, 12); c.lineTo(6, 12)
                    c.moveTo(13, 12); c.lineTo(13, 4); c.lineTo(17, 6)
                    c.stroke()
                    c.beginPath(); c.ellipse(8, 11, 5, 4); c.fill()
                }
            }
        }
        Accessible.name: checked ? "Скрыть текст песни" : "Показать текст песни"
        Accessible.checked: checked
        onClicked: {
            if (root.lyrics && typeof root.lyrics.lyricsEnabled === "boolean") root.lyrics.lyricsEnabled = checked
            else root.lyricsEnabled = checked
        }
        background: Rectangle {
            radius: root.tokens.radius.small
            color: lyricsToggle.checked ? root.tokens.color.accentSoft
                : lyricsToggle.hovered ? root.tokens.color.surfaceAlt : Qt.alpha(root.tokens.color.background, 0.28)
            border.width: lyricsToggle.visualFocus ? 2 : 1
            border.color: lyricsToggle.checked || lyricsToggle.visualFocus ? root.tokens.color.accent : Qt.alpha(root.tokens.color.border, 0.45)
        }
    }

}
