pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "tokens"
import "surfaces/island"
ShellRoot {
    Tokens { id: theme }
    QtObject {
        id: player
        property bool isPlaying: true
        property string trackTitle: "Fixture track"
    }
    QtObject {
        id: text
        property string status: "loading"
        property var lines: []
        property string currentLine: ""
        property var currentWords: []
        property real position: 0
        property string plainText: ""
    }
    QtObject { id: service; property var player: null; property var lyrics: text }
    FloatingWindow {
        visible: true; implicitWidth: 448; implicitHeight: 48
        DynamicIsland { id: island; anchors.fill: parent; tokens: theme; testMode: true; musicService: service }
        TestCase {
            id: test
            when: false
            function run() {
                service.player = player
                compare(island.playingTitle, "Fixture track")
                verify(!island.compactLyrics)
                text.lines = [{t:0,text:"First fixture line"},{t:3,text:"Second fixture line"}]
                text.currentLine = "First fixture line"
                text.currentWords = [{text:"First ",at:0},{text:"fixture ",at:1},{text:"line",at:2}]
                text.status = "synced"
                verify(island.compactLyrics)
                wait(300)
                compare(island.lyricProgress,1)
                const ticker = findChild(island,"compactMusicLyrics")
                verify(ticker.width > island.width - 50)
                text.currentLine = "A long fixture lyric line ".repeat(10) + "\nmore words"
                verify(island.compactLyricText.indexOf("\n") === -1)
                wait(30)
                verify(ticker.overflowing && ticker.scrolling)
                island.expansionProgress = 1
                wait(300)
                compare(island.lyricProgress,0)
                verify(!ticker.visible)
                island.expansionProgress = 0
                wait(300)
                compare(island.lyricProgress,1)
                text.position = 3
                text.currentLine = "Second fixture line"
                compare(island.lyrics.currentLine,"Second fixture line")
                text.status = "plain"; text.plainText = "Plain fixture line\nAnother line"
                verify(island.compactLyrics)
                player.isPlaying = false
                verify(!island.compactLyrics)
                wait(300)
                compare(island.lyricProgress,0)
                theme.animationsEnabled = false
                player.isPlaying = true
                compare(island.lyricProgress,1)
                console.log("COMPACT_MUSIC_PASS")
                island.grabToImage(result => { result.saveToFile("/tmp/nayori-compact-music.png"); Qt.quit() })
            }
        }
        Timer { interval: 200; running: true; onTriggered: test.run() }
    }
}
