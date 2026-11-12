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
    property int converterStage: 0
    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(node, predicate) {
        if (predicate(node)) return node
        for (const child of node.children || []) { const match = find(child, predicate); if (match) return match }
        return null
    }
    function fixtureOptions(type) {
        if (type === "python_GithubFace") return {hostUser:"fixture"}
        if (type === "shima_newsTicker") return {feedUrl:"https://example.org/rss"}
        if (type === "shima_worldClock") return {timezones:["UTC"]}
        if (type === "shima_screenTime") return {enabled:true}
        if (type === "python_NotesFace") return {notes:[{id:"fixture",title:"Fixture note",content:"Body",updatedAt:Date.now()}]}
        return {}
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
    QtObject {
        id: runtime
        property var requests: ({})
        property var results: ({})
        property var capabilities: ({brightness:false,nightlight:false,easyeffects:false,ffmpeg:true,magick:true})
        property var profile: ({username:"fixture",hostname:"test-host",avatar:"",uptime:"1h"})
        property var audio: ({sink:null,level:0,setVolume:function(value){},toggleMuted:function(){}})
        property var source: null
        property var bluetooth: null
        property var notifications: ({active:false})
        property var networkStatus: ({wifiConnected:false,ethernetConnected:false,watching:false,linked:true,wifiLabel:""})
        property var network: ({wifiEnabled:false,setWifiEnabled:function(value){}})
        property bool nightlightActive: false
        property bool keepAwake: false
        property bool gameMode: false
        property var inhibitWindow: null
        property int usageRevision: 0
        property string currentAppName: "fixture"
        property var profiles: ({})
        property var usage: ({})
        property var networks: ({})
        property bool conversionFailure: false
        signal response(string key, var data)
        function request(op, payload, key) {
            let data = {}
            if (op === "zones") data = {entries:[{zone:"UTC",name:"UTC",offset:0,year:2026,month:11,day:12,hour:12,minute:0,second:0,isDay:true}]}
            if (op === "news") data = {articles:[{title:"Fixture news",url:"https://example.org/article",source:"example.org",timestamp:"2026-11-12T12:00:00Z"}]}
            if (op === "github") data = {contributions:[{date:"2026-01-01",count:13,level:3}],total:13}
            if (op === "lyrics") data = {status:"synced",lines:[{t:0,text:"Local fixture"}],plainText:""}
            if (op === "capabilities") data = capabilities
            if (op === "command") data = {exitCode:conversionFailure ? 1 : 0,exitStatus:0}
            requests = Object.assign({},requests,{[key]:data})
            Qt.callLater(() => {
                if (requests[key] === undefined) return
                const next = Object.assign({},requests); delete next[key]; requests = next
                results = Object.assign({},results,{[key]:data}); response(key,data)
            })
        }
        function release(prefix) {
            const jobs = Object.assign({},requests), cache = Object.assign({},results)
            for (const key of Object.keys(jobs)) if (key.startsWith(prefix)) delete jobs[key]
            for (const key of Object.keys(cache)) if (key.startsWith(prefix)) delete cache[key]
            requests = jobs; results = cache
        }
        function profileConsumer(key,wanted) { const next = Object.assign({},profiles); if (wanted) next[key] = true; else delete next[key]; profiles = next }
        function usageConsumer(key,wanted) { const next = Object.assign({},usage); if (wanted) next[key] = true; else delete next[key]; usage = next }
        function networkConsumer(key,wanted) { const next = Object.assign({},networks); if (wanted) next[key] = true; else delete next[key]; networks = next }
        function todayUsage() { return {totalSeconds:60,hourly:Array(24).fill(0),apps:{fixture:60}} }
        function action(name) {}
        function toggleMicMute() {}
        function toggleDnd() {}
        function toggleNightlight() {}
        function toggleGameMode() {}
        function toggleDarkMode() {}
        function playSound(path,volume,loop) { return loop ? 2 : 1 }
        function stopSound(handle) {}
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
            widgetRuntime: runtime
            spec: root.current >= 0 && root.current < ImportedWidgets.entries.length ? ({type: ImportedWidgets.entries[root.current].type, options: root.fixtureOptions(ImportedWidgets.entries[root.current].type)}) : null
        }
    }
    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: {
            try {
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
                root.check(Object.keys(runtime.profiles).length === 0 && Object.keys(runtime.usage).length === 0, "profile and usage subscriptions released")
                root.check(Object.keys(runtime.networks).length === 0, "network watchers released")
                root.check(Object.keys(runtime.results).length === 0, "instance I/O cache released")
                root.check(root.failures === 0, "every catalog component loads")
                console.log("IMPORTED_WIDGETS_PASS", ImportedWidgets.entries.length)
                Qt.quit()
                return
            }
            if (root.current >= 0) {
                const row = ImportedWidgets.entries[root.current]
                console.log("IMPORTED_WIDGET_RESULT", row.type, face.loadStatus, !!face.loadedItem, face.loadedItem ? face.loadedItem.implicitWidth : 0, face.loadedItem ? face.loadedItem.implicitHeight : 0)
                if (!face.loadedItem) root.failures++
                const bridge = face.widgetBridge
                if (row.type === "shima_todo") {
                    bridge.todo.addTask("Fixture task")
                    root.check(bridge.options.tasks[0].content === "Fixture task", "task is stored per instance")
                    bridge.todo.markDone(0)
                    root.check(bridge.options.tasks[0].done, "task completion persists")
                    bridge.todo.deleteItem(0)
                    root.check(bridge.options.tasks.length === 0, "task deletion persists")
                }
                if (row.type === "shima_notes") {
                    bridge.config.setNestedValue("background.widgets.notes.text", "Updated note")
                    root.check(bridge.options.text === "Updated note", "original note editor updates instance")
                }
                if (row.type === "shima_timers") {
                    bridge.timers.toggleStopwatch()
                    root.check(bridge.options.timerState.stopwatch.running, "stopwatch starts per instance")
                    bridge.timers.toggleStopwatch()
                    root.check(!bridge.options.timerState.stopwatch.running, "stopwatch pauses")
                    bridge.timers.stopwatchReset()
                    root.check(bridge.options.timerState.stopwatch.elapsed === 0, "stopwatch resets")
                }
                if (row.type === "shima_worldClock") root.check(bridge.worldClock.entries[0].offset === 0, "world clock receives zone data")
                if (row.type === "shima_newsTicker") root.check(bridge.news.articles[0].title === "Fixture news", "news receives RSS data")
                if (row.type === "shima_screenTime") root.check(bridge.screenTime.getToday().totalSeconds === 60, "screen time uses shared usage")
                if (row.type === "shima_userCard" || row.type === "python_UserFace") root.check(bridge.systemInfo.username === "fixture", "profile uses shared runtime")
                if (row.type === "shima_visualizer") {
                    const spectrum = root.find(face.loadedItem, node => node.nativePainter !== undefined)
                    root.check(!!spectrum && !!spectrum.nativePainter, "original C++ painter loads from physical plugin directory")
                    spectrum.points = [10,20,30]
                    spectrum.smoothing = 3
                    root.check(spectrum.nativePainter.points.length === 3 && spectrum.nativePainter.smoothing === 3, "painter receives live instance properties")
                }
                if (row.type === "shima_controls") root.check(!bridge.nightlight.available, "missing nightlight tool stays disabled")
                if (row.type === "python_NotesFace") root.check(face.loadedItem.notesList[0].title === "Fixture note", "Python notes receive saved collection")
                if (row.type === "python_GithubFace") {
                    root.check(face.loadedItem.totalContributions === 13, "GitHub uses actual contribution count")
                    face.loadedItem.hostUser = ""
                    root.check(face.loadedItem.totalContributions === 0 && face.loadedItem.username === "", "clearing GitHub account clears old contribution data")
                }
                if (row.type === "python_MusicFaceLyrics") {
                    root.check(bridge.lyrics.lyrics[0].text === "Fixture lyric", "full lyrics use shared MusicService")
                    let requested = false
                    bridge.settingsRequested.connect(() => { requested = true })
                    bridge.requestSettings()
                    root.check(requested, "local lyrics picker opens same widget settings")
                }
                if (row.type === "shima_imageConverter") {
                    root.check(typeof face.loadedItem.enqueueFiles === "function", "original converter drop action available")
                    if (root.converterStage === 0) {
                        face.loadedItem.enqueueFiles(["file:///tmp/fixture.png"])
                        root.converterStage = 1
                        return
                    }
                    if (root.converterStage === 1) {
                        root.check(face.loadedItem.conversionState === "done", "converter receives successful completion")
                        runtime.conversionFailure = true
                        face.loadedItem.enqueueFiles(["file:///tmp/failure.png"])
                        root.converterStage = 2
                        return
                    }
                    root.check(face.loadedItem.conversionState === "error", "converter displays failed conversion")
                    runtime.conversionFailure = false
                }
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
            } catch (error) {
                console.error("IMPORTED_WIDGETS_FAIL", root.current, error, error.stack)
                Qt.exit(1)
            }
        }
    }
}
