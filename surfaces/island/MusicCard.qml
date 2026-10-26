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
    readonly property bool popupOpen: sourceMenu.visible
    onVisibleChanged: if (!visible) sourceMenu.close()
    signal playerSelected(var selected)
    onPlayersChanged: { if (!players.length) sourceMenu.close() }
    property bool lyricsEnabled: !lyrics || typeof lyrics.lyricsEnabled !== "boolean" ? true : lyrics.lyricsEnabled
    readonly property bool hasLyrics: !!lyrics && ((lyrics.status === "synced" && lyrics.lines && lyrics.lines.length > 0) || (lyrics.status === "plain" && !!lyrics.plainText))
    readonly property bool lyricPending: !!player && !!lyrics && (lyrics.status === "idle" || lyrics.status === "loading")
    property bool lyricMode: false
    // Lookup resets its data before fetching the next track. Keep the current
    // layout during that interval instead of sliding out and immediately back.
    function updateLyricMode() {
        if (!player || !lyrics || !lyricsEnabled) lyricMode = false
        else if (lyrics.status !== "idle" && lyrics.status !== "loading")
            lyricMode = (lyrics.status === "synced" && !!lyrics.lines && lyrics.lines.length > 0) ||
                (lyrics.status === "plain" && !!lyrics.plainText)
    }
    onHasLyricsChanged: updateLyricMode()
    onLyricPendingChanged: updateLyricMode()
    onLyricsEnabledChanged: updateLyricMode()
    onPlayerChanged: updateLyricMode()
    onLyricsChanged: updateLyricMode()
    Component.onCompleted: updateLyricMode()
    readonly property bool metadataVisible: !lyricMode
    property real lyricProgress: lyricMode ? 1 : 0
    Behavior on lyricProgress { NumberAnimation { duration: root.tokens.motion.off ? 0 : 250; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.77, 0, 0.175, 1, 1, 1] } }
    readonly property real trackDuration: player && player.lengthSupported !== false && isFinite(Number(player.length)) ? Math.max(0, Number(player.length) || 0) : 0
    readonly property bool positionKnown: !!player && player.positionSupported !== false &&
        ((!!lyrics && typeof lyrics.position === "number" && isFinite(lyrics.position)) ||
         (typeof player.position === "number" && isFinite(player.position)))
    readonly property real trackPosition: !positionKnown ? 0 : Math.max(0,
        lyrics && typeof lyrics.position === "number" && isFinite(lyrics.position) ? lyrics.position : player.position)
    readonly property real trackProgress: trackDuration > 0 && positionKnown ? Math.min(1, trackPosition / trackDuration) : 0
    readonly property real controlsBottom: controls.y + controls.height
    function timeLabel(seconds) {
        const value = Math.floor(Math.max(0, seconds))
        return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0")
    }
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
    Item {
        anchors.fill: parent
        RowLayout {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            height: 18
            spacing: 8
            IslandLabel {
                objectName: "musicHeading"
                tokens: root.tokens
                text: root.lyricMode && root.player ? (root.player.trackTitle || "Без названия") + (root.player.trackArtist ? " · " + root.player.trackArtist : "") : "Музыка"
                font.pixelSize: 12
                color: root.tokens.color.textMuted
                Layout.fillWidth: true
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            AbstractButton {
                id: sourceButton
                objectName: "musicSourceButton"
                enabled: root.players.length > 0
                visible: root.player !== null
                text: root.player ? root.player.identity : ""
                Layout.maximumWidth: root.width * 0.38
                implicitWidth: Math.min(120, contentItem.implicitWidth)
                implicitHeight: 18
                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                Accessible.name: "Источник музыки: " + text
                Accessible.description: "Выбрать активный плеер"
                onClicked: sourceMenu.open()
                background: Rectangle {
                    radius: root.tokens.radius.small
                    color: sourceMenu.opened ? Qt.alpha(root.tokens.color.accent, 0.16)
                        : sourceButton.hovered ? Qt.alpha(root.tokens.color.surfaceAlt, 0.6) : Qt.alpha(root.tokens.color.background, 0.2)
                    border.width: 1
                    border.color: sourceMenu.opened || sourceButton.visualFocus ? root.tokens.color.accent : Qt.alpha(root.tokens.color.border, 0.4)
                }
                contentItem: Item {
                    implicitWidth: sourceLabel.implicitWidth + 30
                    IslandLabel {
                        id: sourceLabel
                        tokens: root.tokens
                        anchors { left: parent.left; right: sourceChevron.left; top: parent.top; bottom: parent.bottom; leftMargin: 6; rightMargin: 4 }
                        text: sourceButton.text
                        font.pixelSize: 12
                        color: sourceMenu.opened ? root.tokens.color.accent : root.tokens.color.textMuted
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                    MusicTransportIcon {
                        id: sourceChevron
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 }
                        width: 12; height: 12; stroke: 1.7
                        name: sourceMenu.opened ? "chevronUp" : "chevronDown"
                        ink: sourceLabel.color
                    }
                }
                Menu {
                    id: sourceMenu
                    objectName: "musicSourceMenu"
                    x: sourceButton.width - width
                    y: sourceButton.height + 8
                    width: Math.min(248, root.width - 24)
                    padding: 6
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    onOpened: currentIndex = root.players.indexOf(root.player)
                    background: Rectangle {
                        radius: root.tokens.radius.medium
                        color: root.tokens.material.menu
                        border.width: 1
                        border.color: Qt.alpha(root.tokens.color.border, 0.65)
                    }
                    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast } }
                    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast } }
                    Instantiator {
                        model: root.players
                        delegate: MenuItem {
                            id: sourceItem
                            required property var modelData
                            text: modelData.identity || "Плеер"
                            checkable: true
                            checked: root.player === modelData
                            implicitHeight: modelData.trackTitle ? 54 : 36
                            leftPadding: 10; rightPadding: 10
                            topPadding: 8; bottomPadding: 8
                            hoverEnabled: true
                            indicator: null
                            onTriggered: { root.playerSelected(modelData); sourceMenu.close() }
                            background: Rectangle {
                                radius: root.tokens.radius.small
                                color: sourceItem.checked ? Qt.alpha(root.tokens.color.accent, sourceItem.highlighted ? 0.24 : 0.14)
                                    : sourceItem.highlighted ? Qt.alpha(root.tokens.color.text, 0.08) : "transparent"
                                border.width: sourceItem.visualFocus ? 1 : 0
                                border.color: root.tokens.color.accent
                            }
                            contentItem: RowLayout {
                                spacing: 10
                                MusicTransportIcon {
                                    implicitWidth: 16; implicitHeight: 16
                                    name: "music"; stroke: 1.7
                                    ink: sourceItem.checked ? root.tokens.color.accent : root.tokens.color.textMuted
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    IslandLabel {
                                        tokens: root.tokens; Layout.fillWidth: true
                                        text: sourceItem.text
                                        font.pixelSize: 13; lineHeight: 1
                                        color: sourceItem.checked ? root.tokens.color.accent : root.tokens.color.text
                                        wrapMode: Text.NoWrap; elide: Text.ElideRight
                                    }
                                    IslandLabel {
                                        tokens: root.tokens; Layout.fillWidth: true
                                        visible: !!sourceItem.modelData.trackTitle
                                        text: sourceItem.modelData.trackTitle || ""
                                        font.pixelSize: 11; lineHeight: 1
                                        color: root.tokens.color.textMuted
                                        wrapMode: Text.NoWrap; elide: Text.ElideRight
                                    }
                                }
                                MusicTransportIcon {
                                    implicitWidth: 16; implicitHeight: 16
                                    name: "check"; ink: root.tokens.color.accent
                                    opacity: sourceItem.checked ? 1 : 0
                                }
                            }
                        }
                        onObjectAdded: (index, object) => sourceMenu.insertItem(index, object)
                        onObjectRemoved: (index, object) => sourceMenu.removeItem(object)
                    }
                }
            }
        }
        Item {
            id: content
            anchors { top: header.bottom; bottom: timeline.top; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; topMargin: 8; bottomMargin: 8 }
            clip: true
            Item {
                id: metadata
                anchors.fill: parent
                visible: opacity > 0
                opacity: 1 - root.lyricProgress
                transform: Translate { x: root.tokens.motion.off ? 0 : -32 * root.lyricProgress }
                RowLayout {
                    anchors.fill: parent
                    spacing: 12
                    Rectangle {
                        objectName: "musicCover"
                        implicitWidth: Math.min(68, content.height); implicitHeight: implicitWidth
                        radius: root.tokens.radius.small
                        color: root.tokens.color.surfaceAlt
                        clip: true
                        AlbumArt { id: cover; anchors.fill: parent; requestedSource: root.player ? root.player.trackArtUrl : ""; visible: ready }
                        IslandLabel { tokens: root.tokens; anchors.centerIn: parent; text: "♪"; color: root.tokens.color.accent; font.pixelSize: 30; visible: !cover.ready }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        MarqueeText {
                            objectName: "musicTrackTitle"
                            tokens: root.tokens
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            text: root.player ? root.player.trackTitle || "Без названия" : "Тихая пауза"
                            ink: root.tokens.color.text
                            font.family: root.tokens.type.display.family
                            font.weight: Font.Medium
                            font.pixelSize: 20
                            font.letterSpacing: -0.35
                            active: root.visible && root.metadataVisible
                        }
                        IslandLabel { tokens: root.tokens; Layout.fillWidth: true; text: root.player ? root.player.trackArtist || "" : "Откройте музыку в любимом плеере"; color: root.tokens.color.textMuted; font.pixelSize: 12; lineHeight: 1; wrapMode: Text.NoWrap; maximumLineCount: 1; elide: Text.ElideRight }
                        IslandLabel { objectName: "musicAlbum"; tokens: root.tokens; Layout.fillWidth: true; visible: !!root.player && !!root.player.trackAlbum; text: root.player ? root.player.trackAlbum || "" : ""; color: root.tokens.color.textMuted; font.pixelSize: 11; lineHeight: 1; wrapMode: Text.NoWrap; maximumLineCount: 1; elide: Text.ElideRight }
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
                IslandLabel {
                    tokens: root.tokens
                    anchors.centerIn: parent
                    text: "Загружаем текст…"
                    font.pixelSize: 12
                    color: root.tokens.color.textMuted
                    visible: root.lyricPending
                }
                SyncedLyrics {
                    objectName: "musicLyrics"
                    anchors.fill: parent
                    tokens: root.tokens
                    lyrics: root.lyrics
                    lineEnd: {
                        const next = root.lyrics && root.lyrics.lines && typeof root.lyrics.currentIndex === "number"
                            ? root.lyrics.lines[root.lyrics.currentIndex + 1] : null
                        return next ? next.t : root.trackDuration
                    }
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
            id: timeline
            anchors { left: parent.left; right: parent.right; bottom: controls.top; leftMargin: 12; rightMargin: 12; bottomMargin: 8 }
            height: 14
            spacing: 8
            IslandLabel { tokens: root.tokens; text: root.positionKnown ? root.timeLabel(root.trackPosition) : "—:—"; font.pixelSize: 11; color: root.tokens.color.textMuted; font.features: { "tnum": 1 }; wrapMode: Text.NoWrap }
            Rectangle {
                objectName: "musicTrackProgress"
                Layout.fillWidth: true
                implicitHeight: 3
                radius: 1.5
                color: Qt.alpha(root.tokens.color.text, 0.14)
                Accessible.role: Accessible.ProgressBar
                Accessible.name: "Прогресс трека"
                Accessible.description: root.positionKnown && root.trackDuration > 0 ? Math.round(root.trackProgress * 100) + "%" : "Позиция недоступна"
                Rectangle {
                    height: parent.height
                    width: parent.width * root.trackProgress
                    radius: parent.radius
                    color: root.tokens.color.accent
                    Behavior on width { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast; easing.type: Easing.Linear } }
                }
            }
            IslandLabel { tokens: root.tokens; text: root.trackDuration > 0 ? root.timeLabel(root.trackDuration) : "—:—"; font.pixelSize: 11; color: root.tokens.color.textMuted; font.features: { "tnum": 1 }; wrapMode: Text.NoWrap }
        }
        RowLayout {
            id: controls
            objectName: "musicControls"
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 12 }
            height: 32
            spacing: 8
            IslandAction {
                tokens: root.tokens; implicitWidth: 32; implicitHeight: 32
                Accessible.name: "Предыдущий трек"
                enabled: !!root.player && root.player.canGoPrevious
                onClicked: root.player.previous()
                contentItem: Item { MusicTransportIcon { anchors.centerIn: parent; width: 16; height: 16; name: "prev"; ink: root.tokens.color.text; opacity: parent.enabled ? 1 : 0.35 } }
            }
            IslandAction {
                id: playButton
                tokens: root.tokens; implicitWidth: 32; implicitHeight: 32
                Accessible.name: root.player && root.player.isPlaying ? "Приостановить" : "Воспроизвести"
                enabled: !!root.player && root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
                contentItem: Item { MusicTransportIcon { anchors.centerIn: parent; width: 16; height: 16; name: root.player && root.player.isPlaying ? "pause" : "play"; ink: root.tokens.color.accentText; opacity: playButton.enabled ? 1 : 0.35 } }
                background: Rectangle {
                    radius: root.tokens.radius.small
                    color: playButton.down || playButton.hovered ? root.tokens.color.accentHover : root.tokens.color.accent
                    opacity: playButton.enabled ? 1 : 0.35
                    border.width: playButton.visualFocus ? 2 : 0
                    border.color: root.tokens.color.text
                }
            }
            IslandAction {
                tokens: root.tokens; implicitWidth: 32; implicitHeight: 32
                Accessible.name: "Следующий трек"
                enabled: !!root.player && root.player.canGoNext
                onClicked: root.player.next()
                contentItem: Item { MusicTransportIcon { anchors.centerIn: parent; width: 16; height: 16; name: "next"; ink: root.tokens.color.text; opacity: parent.enabled ? 1 : 0.35 } }
            }
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
        visible: root.hasLyrics || root.lyricMode
        enabled: root.hasLyrics
        checkable: true
        checked: root.lyricsEnabled
        implicitWidth: 32
        text: ""
        contentItem: Item {
            // A lyric sheet with a musical note; independent of installed icon fonts.
            Canvas {
                anchors.centerIn: parent
                width: 18; height: 18
                property color ink: lyricsToggle.checked ? root.tokens.color.accentSoftText : root.tokens.color.text
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
