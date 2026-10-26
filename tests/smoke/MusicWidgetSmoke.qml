pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "tokens"
import "services/island"
import "surfaces/island"
ShellRoot {
    id: root
    function findItem(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) { const found = findItem(child,name); if (found) return found }
        return null
    }
    Tokens { id: theme }
    QtObject {
        id: first
        property string identity: "Первый плеер"
        property string trackTitle: "A"
        property string trackArtist: "Test"
        property string trackAlbum: "Fixture"
        property string trackArtUrl: ""
        property real length: 10
        property bool lengthSupported: true
        property bool positionSupported: true
        property real position: 0
        property bool isPlaying: true
        property bool canGoPrevious: false
        property bool canGoNext: false
        property bool canTogglePlaying: false
        property var metadata: ({})
    }
    QtObject {
        id: second
        property string identity: "Второй плеер"
        property string trackTitle: "B"
        property string trackArtist: "Test"
        property string trackAlbum: "Fixture"
        property string trackArtUrl: ""
        property real length: 10
        property bool lengthSupported: true
        property bool positionSupported: true
        property real position: 0
        property bool isPlaying: false
        property bool canGoPrevious: false
        property bool canGoNext: false
        property bool canTogglePlaying: false
        property var metadata: ({})
    }
    MusicService {
        id: music
        testMode: true; testPlayers: [first,second]
        testCommand: ["python3", Quickshell.shellPath("fake-lyrics-worker.py")]
        Component.onCompleted: consumer("widget-test",true)
    }
    FloatingWindow {
        visible: true; implicitWidth: 680; implicitHeight: 450
        color: theme.color.background
        IslandDashboard {
            id: dashboard
            anchors.fill: parent; tokens: theme; testMode: true; musicService: music
            showDate: false; topInset: 0
        }
        TestCase {
            id: test
            when: false
            name: "MusicWidget"
            function run() {
                tryCompare(music,"status","synced")
                const card = root.findItem(dashboard,"musicCard")
                const button = root.findItem(dashboard,"musicSourceButton")
                const menu = findChild(dashboard,"musicSourceMenu")
                verify(card.lyricMode && !card.metadataVisible)
                verify(card.controlsBottom >= card.height-30)
                const toggle = root.findItem(card,"musicLyricsToggle")
                verify(toggle.visible && toggle.checked)
                compare(toggle.text, "")
                verify(root.findItem(card,"musicTrackProgress") !== null)
                const controls = root.findItem(card,"musicControls")
                const controlsPosition = controls.mapToItem(card,0,0)
                const progress = root.findItem(card,"musicTrackProgress")
                const progressPosition = progress.mapToItem(card,0,0)
                verify(root.findItem(card,"previousLyricLine") === null)
                verify(root.findItem(card,"nextLyricLine") !== null)
                mouseClick(toggle,toggle.width/2,toggle.height/2)
                verify(card.metadataVisible && !card.lyricMode && !toggle.checked)
                verify(!music.lyricsEnabled)
                wait(300)
                compare(controls.mapToItem(card,0,0), controlsPosition)
                compare(progress.mapToItem(card,0,0), progressPosition)
                mouseClick(toggle,toggle.width/2,toggle.height/2)
                verify(!card.metadataVisible && card.lyricMode && toggle.checked)
                verify(music.lyricsEnabled)
                mouseClick(button,button.width/2,button.height/2)
                tryCompare(menu,"visible",true)
                verify(dashboard.popupOpen)
                compare(menu.count,2)
                compare(menu.background.color,theme.material.menu)
                verify(menu.itemAt(0).checked)
                verify(menu.itemAt(0).height >= 36)
                keyClick(Qt.Key_Escape)
                tryCompare(menu,"visible",false)
                verify(!dashboard.popupOpen)
                mouseClick(button,button.width/2,button.height/2)
                tryCompare(menu,"visible",true)
                const item = menu.itemAt(1)
                mouseClick(item,item.width/2,item.height/2)
                tryCompare(music,"player",second)
                tryCompare(music,"source","Fixture B")
                compare(button.text,"Второй плеер")
                second.trackTitle = "Plain"
                tryCompare(music,"status","plain")
                wait(300)
                const plain = root.findItem(card,"plainMusicLyrics")
                verify(plain.visible && !card.metadataVisible)
                verify(plain.contentHeight > plain.height)
                mouseMove(plain,plain.width/2,plain.height/2)
                wait(30)
                mouseWheel(plain,plain.width/2,plain.height/2,0,-120)
                wait(100)
                verify(plain.contentY > 0)
                compare(dashboard.currentPage,0)
                second.trackTitle = "Broken"
                tryCompare(music,"status","error")
                verify(card.metadataVisible && !card.lyricMode)
                verify(!toggle.visible)
                verify(progress.visible)
                compare(controls.mapToItem(card,0,0), controlsPosition)
                compare(progress.mapToItem(card,0,0), progressPosition)
                music.testPlayers = [first]
                tryCompare(music,"source","Fixture A")
                verify(card.lyricMode && !card.metadataVisible)
                wait(300)
                dashboard.grabToImage(result => {
                    result.saveToFile("/tmp/nayori-music-widget.png")
                    console.log("MUSIC_WIDGET_PASS"); Qt.quit()
                })
            }
        }
        Timer { interval: 200; running: true; onTriggered: test.run() }
    }
}
