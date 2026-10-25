import QtQuick
import QtTest
import Quickshell
import "services/island"
ShellRoot {
    id: root
    QtObject {
        id: first
        property string trackTitle: "A"
        property string trackArtist: "Test"
        property string trackAlbum: "Fixture"
        property real length: 10
        property bool lengthSupported: true
        property bool positionSupported: true
        property real position: 0
        property bool isPlaying: true
        property var metadata: ({})
    }
    QtObject {
        id: second
        property string trackTitle: "B"
        property string trackArtist: "Test"
        property string trackAlbum: "Fixture"
        property real length: 10
        property bool lengthSupported: true
        property bool positionSupported: true
        property real position: 1
        property bool isPlaying: false
        property var metadata: ({})
    }
    MusicService {
        id: music
        testMode: true
        testPlayers: [first, second]
        testCommand: ["python3", Quickshell.shellPath("tests/fake-lyrics-worker.py")]
    }
    TestCase {
        id: test
        when: false
        name: "MusicService"
        function run() {
            compare(music.player, first)
            compare(music.status, "idle")
            music.consumer("screen-a", true)
            tryCompare(music, "status", "synced")
            compare(music.currentLine, "Начало A")
            first.position = 5.5
            compare(music.currentLine, "")
            first.position = 6.5
            compare(music.currentLine, "Продолжение A")
            first.position = 1
            compare(music.currentLine, "Начало A")
            first.isPlaying = false
            verify(!music.positionClock.running)
            music.selectPlayer(second)
            tryCompare(music, "source", "Fixture B")
            compare(music.currentLine, "Начало B")
            first.isPlaying = true
            compare(music.player, second)
            music.testPlayers = [first]
            tryCompare(music, "source", "Fixture A")
            compare(music.player, first)
            first.trackTitle = "Slow"
            wait(500)
            compare(music.status, "loading")
            first.trackTitle = "A"
            tryCompare(music, "source", "Fixture A")
            wait(1800)
            compare(music.source, "Fixture A")
            first.trackTitle = "Broken"
            tryCompare(music, "status", "error")
            compare(music.retryClock.interval, 15000)
            first.trackTitle = "A"
            tryCompare(music, "source", "Fixture A")
            music.consumer("screen-b", true)
            music.consumer("screen-a", false)
            verify(music.wanted)
            music.consumer("screen-b", false)
            verify(!music.wanted && !music.worker.running && !music.positionClock.running)
            // Neighbours skip silence; word timing still stops at the immediate blank.
            music.apply({status:"synced", lines:[
                {t:0,text:""}, {t:1,text:" Мы   пели "}, {t:4,text:""},
                {t:6,text:"Следующая строка"}, {t:8,text:""}
            ]})
            first.position = 2
            compare(music.currentLine, " Мы   пели ")
            compare(music.previousLine, "")
            compare(music.nextLine, "Следующая строка")
            compare(music.currentWords.length, 2)
            compare(music.currentWords.map(w => w.text).join(""), music.currentLine)
            compare(music.currentWords[0].at, 1)
            compare(music.currentWords[1].at, 2)
            first.position = 4.5
            compare(music.currentLine, "")
            compare(music.currentWords.length, 0)
            compare(music.previousLine, " Мы   пели ")
            compare(music.nextLine, "Следующая строка")
            first.position = 6.5
            compare(music.previousLine, " Мы   пели ")
            compare(music.nextLine, "")

            // Valid source timings win; malformed data falls back as a whole.
            music.apply({status:"synced", lines:[{t:1,text:"One two three",w:[1.2,2.7,4.1]},{t:5,text:""}]})
            first.position = 3
            compare(music.currentWords[0].at, 1.2)
            compare(music.currentWords[1].at, 2.7)
            compare(music.currentWords[2].at, 4.1)
            music.apply({status:"synced", lines:[{t:1,text:"One two",w:[{text:"One",at:1.4},{text:"two",t:2.8}]},{t:5,text:""}]})
            compare(music.currentWords[1].at, 2.8)
            for (const bad of [[2,1.5], [1,5], [1,NaN], [1], [{text:"Wrong",at:1},{text:"two",at:2}]]) {
                music.apply({status:"synced", lines:[{t:1,text:"One two",w:bad},{t:5,text:""}]})
                compare(music.currentWords[0].at, 1)
                compare(music.currentWords[1].at, 1 + 8/3)
            }

            // Last-line estimates use duration and update when seeking backwards.
            music.apply({status:"synced", lines:[{t:2,text:"We create"}]})
            first.position = 9
            compare(music.currentWords[0].at, 2)
            compare(music.currentWords[1].at, 4)
            first.position = 0
            compare(music.currentLine, "")
            compare(music.currentWords.length, 0)
            compare(music.nextLine, "We create")
            music.apply({status:"plain", plainText:"Untimed fixture"})
            compare(music.currentWords.length, 0)
            compare(music.previousLine, "")
            compare(music.nextLine, "")
            console.log("MUSIC_SERVICE_PASS")
            Qt.quit()
        }
    }
    Timer { interval: 100; running: true; onTriggered: test.run() }
}
