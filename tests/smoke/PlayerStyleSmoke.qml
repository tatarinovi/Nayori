import QtQuick
import Quickshell
import "tokens"
import "surfaces/island"
ShellRoot {
    function findItem(item, name) {
        if (item.objectName === name) return item
        const children = item.children || []
        for (let i = 0; i < children.length; i++) {
            const found = findItem(children[i], name)
            if (found) return found
        }
        return null
    }
    Tokens { id: theme }
    FloatingWindow {
        visible: true; implicitWidth: 680; implicitHeight: 450
        color: theme.color.background
        IslandDashboard {
            id: dashboard
            anchors.fill: parent
            tokens: theme
            testMode: true
            weatherCity: "Москва"
            weather: ({weatherCode:113,temp_C:"18",FeelsLikeC:"17"})
            testPlayers: [{isPlaying:true,identity:"Тестовый плеер",trackTitle:"Название трека",trackArtist:"Исполнитель",trackArtUrl:Qt.resolvedUrl("assets/weather/clear.png"),canGoPrevious:false,canGoNext:false,canTogglePlaying:false}]
        }
    }
    Timer {
        interval: 600; running: true
        onTriggered: {
            const first = dashboard.testPlayers[0]
            const second = {isPlaying:false,identity:"Второй плеер",trackTitle:"Другой трек",trackArtist:"Исполнитель",trackArtUrl:"",canGoPrevious:false,canGoNext:false,canTogglePlaying:false}
            dashboard.testPlayers = [first, second]
            dashboard.selectedPlayer = second
            if (dashboard.player !== second) throw new Error("Paused source selection lost")
            dashboard.selectedPlayer = first
            dashboard.musicService = {players: [first, second], player: first, lyrics: {status:"synced",currentLine:"Тестовая строка с таймкодом и продолжением, которое занимает несколько строк в маленьком музыкальном виджете",nextLine:"Следующая строка песни",lines:[{t:0,text:"Тестовая строка с таймкодом"}]}}
            Qt.callLater(() => {
                const card = findItem(dashboard, "musicCard")
                if (!card || !card.lyricMode || card.metadataVisible) throw new Error("Lyrics must replace metadata")
                if (card.controlsBottom < card.height - 30) throw new Error("Controls must remain at bottom")
                console.log("PLAYER_SOURCE_AND_LYRICS_PASS")
            })
        }
    }
    Timer {
        interval: 1200; running: true
        onTriggered: dashboard.grabToImage(result => {
            result.saveToFile("/tmp/nayori-player-style.png")
            console.log("PLAYER_STYLE_PASS"); Qt.quit()
        })
    }
}
