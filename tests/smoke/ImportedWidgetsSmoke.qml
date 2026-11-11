import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "tokens"
import "services/settings"
import "surfaces/desktop"
import "surfaces/desktop/ImportedWidgets.js" as ImportedWidgets
import "surfaces/desktop/vendor/widgets/python" as PythonVendor

ShellRoot {
    id: root
    property int current: -1
    property int failures: 0
    property bool initialized: false
    property bool finishing: false
    property int plays: 0
    function check(ok, message) { if (!ok) { console.error("IMPORTED_WIDGETS_FAIL", message); Qt.exit(1) } }
    function find(node, predicate) {
        if (predicate(node)) return node
        for (const child of node.children || []) { const match = find(child, predicate); if (match) return match }
        return null
    }
    Tokens { id: theme }
    SettingsService { id: store }
    QtObject {
        id: fixturePlayer
        property int playbackState: MprisPlaybackState.Playing
        property bool isPlaying: true
        property string trackTitle: "Fixture track"
        property string trackArtist: "Fixture artist"
        property string trackArtUrl: ""
        property real length: 120
        property real position: 20
        property bool canTogglePlaying: true
        property bool canGoPrevious: true
        property bool canGoNext: true
        property bool canSeek: true
        function togglePlaying() { root.plays++; isPlaying = !isPlaying }
        function previous() {}
        function next() {}
    }
    QtObject {
        id: fixtureMusic
        property var player: fixturePlayer
        property real position: 20
        property string status: "synced"
        property var lines: [{t:0, text:"Fixture lyric"}, {t:30, text:"Next lyric"}]
        property string plainText: ""
        property int currentIndex: 0
        property var consumers: ({})
        function consumer(key, wanted) {
            const next = Object.assign({}, consumers)
            if (wanted) next[key] = true
            else delete next[key]
            consumers = next
        }
        function syncPosition(notify) { position = fixturePlayer.position }
    }
    QtObject {
        id: monitor
        property var data: ({uptime: 123456, disks: [{mount: "/", used: 50000000000, total: 100000000000}]})
    }
    QtObject {
        id: reader
        property var monitorService: monitor
        property var cpu: 0.42
        property var memory: 0.5
        property var memoryUsedKb: 2097152
        property var memoryTotalKb: 4194304
        property var cpuTemp: 52
        property var gpuTemp: 48
        property var gpu: 0.3
        property var cpuHistory: [0.2, 0.3, 0.42]
        property var gpuHistory: [0.1, 0.2, 0.3]
    }
    QtObject {
        id: weather
        property bool enabled: true
        property bool loading: false
        property string city: "Fixture city"
        property string error: ""
        property real updatedAt: Date.now()
        property var data: ({current_condition: [{temp_C: "8", FeelsLikeC: "6", weatherCode: "113", weatherDesc: [{value: "Clear"}]}], weather: [{date: "2026-11-11", maxtempC: "12", mintempC: "4", hourly: [{time: "1200", tempC: "10", weatherCode: "113"}]}]})
    }
    QtObject {
        id: calendar
        property var events: [{title: "Calendar fixture", start: new Date(Date.now() + 3600000).toISOString(), end: new Date(Date.now() + 7200000).toISOString(), allDay: false}]
    }
    QtObject {
        id: audio
        property var spectrum: Array(64).fill(0.35)
        property var consumers: ({})
        property var systemConsumers: ({})
        function consumer(key, wanted) { if (wanted) consumers[key] = true; else delete consumers[key] }
        function systemConsumer(key, wanted) { if (wanted) systemConsumers[key] = true; else delete systemConsumers[key] }
    }
    FloatingWindow {
        visible: true; implicitWidth: 900; implicitHeight: 700
        ImportedWidgetFace {
            id: face
            width: 600; height: 480
            tokens: theme
            screenWidth: 1920; screenHeight: 1080
            music: fixtureMusic
            systemReader: reader
            weatherService: weather
            calendarStore: calendar
            audioReaction: audio
            spec: root.current >= 0 && root.current < ImportedWidgets.entries.length ? ({type: ImportedWidgets.entries[root.current].type}) : null
        }
    }
    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: {
            if (!store.ready) return
            if (Quickshell.env("NAYORI_IMPORTED_RESTORE") === "1") {
                const outputs = store.desktopWidgets
                root.check(outputs["DP-1"].items[0].options.future.value === 7, "unknown instance setting survives restart")
                root.check(outputs["DP-1"].items[1].options.dynamicColors === false, "second instance remains independent")
                root.check(outputs["HDMI-1"].items[0].x === 144, "second monitor position survives restart")
                console.log("IMPORTED_WIDGETS_RESTORE_PASS")
                Qt.quit()
                return
            }
            if (!root.initialized) {
                root.initialized = true
                store.update({desktopWidgets: {
                    "DP-1": {snap: true, items: [
                        {id: "one", type: "python_ClockFaceDigital", x: 24, y: 48, options: {dynamicColors: true, future: {value: 7}}},
                        {id: "two", type: "python_ClockFaceDigital", x: 400, y: 48, options: {dynamicColors: false}}]},
                    "HDMI-1": {snap: false, items: [{id: "other", type: "ii_quote", x: 144, y: 96, options: {quoteText: "Independent"}}]}
                }})
            }
            if (root.finishing) {
                root.check(Object.keys(audio.consumers).length === 0 && Object.keys(audio.systemConsumers).length === 0, "audio subscriptions released")
                root.check(PythonVendor.WaveTick.clients.length === 0, "wave clients released")
                root.check(Object.keys(fixtureMusic.consumers).length === 0, "lyrics consumers released")
                root.check(root.failures === 0, "every catalog component loads")
                console.log("IMPORTED_WIDGETS_PASS", ImportedWidgets.entries.length)
                Qt.quit()
                return
            }
            if (root.current >= 0) {
                const row = ImportedWidgets.entries[root.current]
                console.log("IMPORTED_WIDGET_RESULT", row.type, face.loadStatus, !!face.loadedItem, face.loadedItem ? face.loadedItem.implicitWidth : 0, face.loadedItem ? face.loadedItem.implicitHeight : 0)
                if (!face.loadedItem) root.failures++
                if (row.type === "python_CpuFace") root.check(face.loadedItem.rawCpu === 0.42, "CPU reads existing monitor")
                if (row.type === "python_WeatherFaceFull") root.check(face.loadedItem.weatherData.current_temp === "8", "weather reads existing response")
                if (row.type === "shima_calendarUpcoming") root.check(face.loadedItem.events[0].title === "Calendar fixture", "agenda reads existing calendar")
                if (row.type === "ii_calendar_next_event") {
                    root.check(face.loadedItem.nextEvent.content === "Calendar fixture", "ii next event uses Nayori title and dates")
                    const oldEvents = calendar.events
                    const start = new Date(); start.setDate(start.getDate() - 1)
                    const end = new Date(); end.setDate(end.getDate() + 2)
                    calendar.events = [{title:"Multi-day", start:Qt.formatDate(start,"yyyy-MM-dd"), end:Qt.formatDate(end,"yyyy-MM-dd"), allDay:true}]
                    root.check(face.loadedItem.nextEvent.content === "Multi-day" && face.loadedItem.effectiveEnd(face.loadedItem.nextEvent) === new Date(Qt.formatDate(end,"yyyy-MM-dd") + "T00:00:00").getTime(), "multi-day event keeps exclusive end")
                    calendar.events = []
                    root.check(face.loadedItem.nextEvent === null, "empty calendar clears next event")
                    calendar.events = oldEvents
                }
                if (row.type === "ii_resource_fill_cards") {
                    const cpu = root.find(face.loadedItem, node => node.cardValueText === "42%")
                    root.check(!!cpu, "fill cards read shared CPU")
                    reader.cpu = null
                    root.check(cpu.cardValueText === "—" && cpu.fillLevel === 0, "missing resource never shows invented percentage")
                    reader.cpu = 0.42
                }
                if (row.type === "shima_dayProgress") root.check(face.loadedItem.fraction >= 0 && face.loadedItem.fraction < 1, "day progress follows shared clock")
                if ((row.type === "ii_pc_battery_bars" || row.type === "ii_pc_battery_cable") && !face.widgetBridge.battery.available) {
                    root.check(!face.loadedItem.isCharging, "missing PC battery never reports charging")
                    root.check(!!root.find(face.loadedItem, node => node.text === "—"), "missing PC battery displays unavailable percentage")
                }
                if (row.type === "python_MusicFaceLyricsSimple") {
                    root.check(face.widgetBridge.lyrics.lyrics[0].text === "Fixture lyric" && Object.keys(fixtureMusic.consumers).length === 1, "original lyrics uses one shared subscription")
                    const lyricsView = root.find(face.loadedItem, node => typeof node.seekToTimestamp === "function")
                    lyricsView.seekToTimestamp(30)
                    root.check(fixturePlayer.position === 30 && fixtureMusic.position === 30, "lyrics seek uses existing player and position")
                    fixtureMusic.status = "notfound"
                    root.check(!face.widgetBridge.lyrics.hasLyrics, "missing lyrics remain unavailable")
                    fixtureMusic.status = "synced"
                }
                if (row.type === "python_MusicFace") {
                    const play = root.find(face.loadedItem, node => node.buttonIcon === "󰏤" || node.buttonIcon === "󰐊")
                    root.check(!!play, "original play button exists")
                    play.clicked()
                    root.check(root.plays === 1, "original play action reaches MPRIS player")
                    const seek = root.find(face.loadedItem, node => node.seekPending !== undefined)
                    root.check(!!seek, "original seek control exists")
                    seek.moved(42)
                    root.check(fixturePlayer.position === 42, "original seek action reaches MPRIS player")
                }
            }
            root.current++
            if (root.current >= ImportedWidgets.entries.length) {
                face.active = false
                root.finishing = true
            }
        }
    }
}
