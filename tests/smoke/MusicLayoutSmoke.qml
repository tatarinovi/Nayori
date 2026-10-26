pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "tokens"
import "surfaces/island"

ShellRoot {
    id: root
    Tokens { id: theme; animationsEnabled: false }
    QtObject {
        id: player
        property string identity: "Spotify"
        property string trackTitle: "После дождя"
        property string trackArtist: "Aoi"
        property string trackAlbum: "Evening sketches"
        property url trackArtUrl: Qt.resolvedUrl("assets/wallpapers/nayori.png")
        property real length: 216
        property real position: 84
        property bool positionSupported: true
        property bool lengthSupported: true
        property bool isPlaying: true
        property bool canGoPrevious: true
        property bool canGoNext: true
        property bool canTogglePlaying: true
        function togglePlaying() { isPlaying = !isPlaying }
        function previous() {}
        function next() {}
    }
    QtObject {
        id: text
        property string status: "synced"
        property bool lyricsEnabled: true
        property var lines: [{t:0, text:"Город уснул"}]
        property string currentLine: "Город уснул, а мы ещё здесь"
        property string nextLine: "Свет растворяется в окнах"
        property var currentWords: []
        property real position: 84
    }
    QtObject {
        id: longText
        property string status: "synced"
        property bool lyricsEnabled: true
        property var lines: [{t:0, text:"Город уснул"}]
        property string currentLine: "Город уснул, а мы всё ещё ждём рассвета"
        property string nextLine: "Свет растворяется в окнах"
        property var currentWords: []
        property real position: 84
    }
    FloatingWindow {
        id: window
        visible: true; implicitWidth: 369; implicitHeight: 620
        color: theme.color.background
        Item {
            id: canvas
            anchors.fill: parent
            AlbumArt { id: retainedArt; requestedSource: player.trackArtUrl; visible: false }
            MusicCard { id: metadata; x:16; y:16; width:337; height:180; tokens:theme; player:player; players:[player]; lyrics:text; lyricsEnabled:false }
            MusicCard { id: shortCard; x:16; y:220; width:337; height:180; tokens:theme; player:player; players:[player]; lyrics:text }
            MusicCard { id: longCard; x:16; y:424; width:337; height:180; tokens:theme; player:player; players:[player]; lyrics:longText }
        }
        TestCase {
            id: test
            when: false
            name: "MusicLayout"
            function checkLyrics(card, count) {
                const lyrics = findChild(card,"musicLyrics")
                compare(lyrics.rows.length, count)
                const current = findChild(card,"currentLyricViewport")
                const next = findChild(card,"nextLyricLine")
                const currentBottom = current.mapToItem(lyrics,0,current.height).y
                const nextTop = next.mapToItem(lyrics,0,0).y
                compare(nextTop - currentBottom, 4)
                verify(current.height >= Math.min(2,count) * lyrics.rowHeight, "All current rows must fit")
                verify(current.mapToItem(lyrics,0,0).y >= 0)
                verify(nextTop + next.height <= lyrics.height)
            }
            function run() {
                try { checkLayout() }
                catch (error) { console.error("MUSIC_LAYOUT_FAILED", error, error.stack); Qt.exit(1) }
            }
            function checkLayout() {
                tryCompare(retainedArt,"ready",true)
                retainedArt.requestedSource = ""
                wait(100)
                verify(retainedArt.ready)
                retainedArt.requestedSource = player.trackArtUrl
                wait(350)
                verify(retainedArt.ready)
                retainedArt.requestedSource = ""
                wait(350)
                verify(!retainedArt.ready)
                retainedArt.requestedSource = player.trackArtUrl
                tryCompare(retainedArt,"ready",true)
                checkLyrics(shortCard,1)
                checkLyrics(longCard,2)
                const album = findChild(metadata,"musicAlbum")
                const cover = findChild(metadata,"musicCover")
                verify(album.mapToItem(metadata,0,album.height).y <= cover.mapToItem(metadata,0,cover.height).y)
                const title = findChild(metadata,"musicTrackTitle")
                verify(!title.overflowing)
                const originalTitle = player.trackTitle
                player.trackTitle = "Очень длинное название трека, которое не помещается рядом с обложкой"
                theme.animationsEnabled = true
                wait(1300)
                verify(title.scrolling && title.offset > 0)
                const controlsBefore = findChild(metadata,"musicControls").mapToItem(metadata,0,0)
                verify(!findChild(shortCard,"musicTrackTitle").scrolling)
                player.trackTitle = originalTitle
                wait(30)
                verify(!title.scrolling && title.offset === 0)
                compare(findChild(metadata,"musicControls").mapToItem(metadata,0,0),controlsBefore)
                theme.animationsEnabled = false
                // Loading a new lookup keeps the lyric layout and controls stable.
                text.status = "idle"
                text.lines = []
                text.currentLine = ""
                verify(shortCard.lyricMode && !shortCard.metadataVisible)
                text.status = "loading"
                verify(shortCard.lyricMode && !shortCard.metadataVisible)
                text.lines = [{t:0,text:"Город уснул"}]
                text.currentLine = "Город уснул, а мы ещё здесь"
                text.status = "synced"
                verify(shortCard.lyricMode)
                for (const card of [metadata,shortCard,longCard]) {
                    const controls = findChild(card,"musicControls")
                    const progress = findChild(card,"musicTrackProgress")
                    compare(controls.mapToItem(card,0,0).y, 136)
                    verify(progress.visible)
                    verify(progress.mapToItem(card,0,0).y < controls.mapToItem(card,0,0).y)
                    compare(card.trackProgress, 84/216)
                }
                // Both explicit and automatic line wrapping use the same geometry.
                const original = longText.currentLine
                longText.currentLine = "Город уснул, а мы\nвсё ещё ждём рассвета"
                wait(30)
                checkLyrics(longCard,2)
                longText.currentLine = "Длинная строка ".repeat(15)
                longText.currentWords = longText.currentLine.match(/\s*\S+\s*/g).map((word,index)=>({text:word,at:index}))
                longText.position = 20
                wait(30)
                const viewport = findChild(longCard,"currentLyricViewport")
                verify(viewport.firstRow > 0)
                verify(viewport.height <= 2 * findChild(longCard,"musicLyrics").rowHeight)
                const movingRows = findChild(longCard,"currentLyricLines")
                verify(movingRows.y < 0)
                longText.position = 0
                compare(viewport.firstRow, 0)
                longText.currentWords = []
                longText.currentLine = "Неразрывноеслово".repeat(20)
                wait(30)
                verify(findChild(longCard,"musicLyrics").rows.length > 2)
                verify(movingRows.width <= viewport.width)
                // Highlight advances within a word, including seeking backwards.
                longText.currentLine = "Город уснул"
                longText.currentWords = [{text:"Город ",at:0},{text:"уснул",at:2}]
                longText.position = 0.5
                wait(30)
                const fill = findChild(longCard,"lyricWordFill")
                verify(fill.width > 0 && fill.width < fill.parent.width)
                const initialWidth = fill.width
                longText.position = 1
                verify(fill.width > initialWidth && fill.width < fill.parent.width)
                longText.position = 0
                compare(fill.width,0)
                longText.currentWords = []
                // Unsupported timing and missing lyrics keep the track in place.
                text.status = "notfound"
                verify(shortCard.metadataVisible)
                verify(findChild(shortCard,"musicTrackProgress").visible)
                player.lengthSupported = false
                player.positionSupported = false
                compare(shortCard.trackProgress,0)
                verify(!shortCard.positionKnown)
                verify(findChild(shortCard,"musicTrackProgress").visible)
                player.lengthSupported = true
                player.positionSupported = true
                text.status = "synced"
                longText.currentLine = original
                longText.position = 84
                wait(100)
                canvas.grabToImage(result => {
                    result.saveToFile("/tmp/nayori-music-layout.png")
                    console.log("MUSIC_LAYOUT_PASS")
                    Qt.quit()
                })
            }
        }
        Timer { interval:600; running:true; onTriggered:test.run() }
    }
}
