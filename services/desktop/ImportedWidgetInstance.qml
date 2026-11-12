pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Per-instance actions; persistence is a signal to the existing desktop editor.
QtObject {
    id: root
    required property var host
    readonly property var runtime: host.runtime
    readonly property var options: host.options
    readonly property date now: host.dateTime.clock.date
    readonly property string key: "widget-io-" + String(root)
    property var zoneData: ({entries:[]})
    property var newsData: ({articles:[]})
    property var localLyrics: null
    property string lastRequest: ""
    function set(key, value) { host.editOption(key, value) }
    function request(op, data, suffix) { if (runtime && host.active) runtime.request(op, data, key + suffix) }
    function refresh() {
        if (!host.active || !runtime) return
        if (host.type === "shima_worldClock") request("zones", {zones:options.timezones || []}, "zones")
        if (host.type === "shima_newsTicker" && options.feedUrl) request("news", {url:options.feedUrl}, "news")
        if (/MusicFaceLyrics/.test(host.type) && options.localLyricsPath) request("lyrics", {path:options.localLyricsPath}, "lyrics")
        if (["shima_controls","shima_mediaControls"].includes(host.type)) request("capabilities",{},"capabilities")
        runtime.usageConsumer(key, host.type === "shima_screenTime" && options.enabled === true)
        runtime.profileConsumer(key,["shima_userCard","python_UserFace"].includes(host.type))
        runtime.networkConsumer(key,["shima_controls","shima_mediaControls"].includes(host.type) || /MusicFaceLyrics/.test(host.type))
    }
    onOptionsChanged: {
        const signature = JSON.stringify([host.type,options.timezones,options.feedUrl,options.localLyricsPath,options.enabled])
        if (signature !== lastRequest) { lastRequest = signature; localLyrics = null; Qt.callLater(refresh) }
    }
    property Connections hostConnection: Connections {
        target: root.host
        function onActiveChanged() {
            if (root.host.active) root.refresh()
            else if (root.runtime) { root.runtime.usageConsumer(root.key, false); root.runtime.profileConsumer(root.key,false); root.runtime.networkConsumer(root.key,false); root.runtime.release(root.key) }
        }
        function onRuntimeChanged() { root.refresh() }
    }
    Component.onCompleted: refresh()
    Component.onDestruction: if (runtime) { runtime.usageConsumer(key, false); runtime.profileConsumer(key,false); runtime.networkConsumer(key,false); runtime.release(key) }
    property Timer refreshClock: Timer {
        interval: 60000; repeat: true; running: root.host.active && !!root.runtime && ["shima_worldClock","shima_newsTicker"].includes(root.host.type)
        onTriggered: root.refresh()
    }
    property Connections io: Connections {
        target: root.runtime
        function onResponse(id, data) {
            if (id === root.key + "zones") root.zoneData = data
            if (id === root.key + "news") root.newsData = data.error ? Object.assign({},root.newsData,{error:data.error}) : data
            if (id === root.key + "lyrics") root.localLyrics = data
            if (id === root.key + "brightness") root.brightnessData = data
            if (id === root.key + "capabilities" && data.brightness) root.request("brightness",{},"brightness")
        }
    }
    readonly property QtObject todo: QtObject {
        function tasks() { return (root.options.tasks || []).slice() }
        function addTask(text) { const list = tasks(); list.push({id:Date.now().toString(36),content:text,done:false}); root.set("tasks",list) }
        function change(index, done) { const list = tasks(); if (!list[index]) return; list[index] = Object.assign({},list[index],{done:done}); root.set("tasks",list) }
        function markDone(index) { change(index,true) }
        function markUnfinished(index) { change(index,false) }
        function deleteItem(index) { const list = tasks(); list.splice(index,1); root.set("tasks",list) }
    }
    function timerValue(name) { return (options.timerState || {})[name] || {} }
    function elapsed(name) {
        const t = timerValue(name)
        return Number(t.elapsed || 0) + (t.running ? Math.max(0, (now.getTime() - Number(t.startedAt || now.getTime())) / 1000) : 0)
    }
    function duration(name) {
        if (name !== "focus") return Math.max(1,Number(options.countdownSeconds || 300))
        const t = timerValue("focus"), longBreak = t.isBreak && Number(t.cycle || 0)+1 >= Number(options.cyclesBeforeLongBreak || 4)
        return Math.max(1,Number(t.isBreak ? longBreak ? options.longBreakMinutes || 15 : options.breakMinutes || 5 : options.focusMinutes || 25)*60)
    }
    function left(name) { return Math.max(0, duration(name) - elapsed(name)) }
    function toggle(name) {
        const data = Object.assign({}, options.timerState || {}), t = timerValue(name)
        const running = !!t.running && (name === "stopwatch" || left(name) > 0)
        data[name] = Object.assign({},t,{elapsed:elapsed(name),startedAt:now.getTime(),running:!running})
        if (name !== "stopwatch" && left(name) <= 0) data[name].elapsed = 0
        set("timerState",data)
    }
    function reset(name) { const data = Object.assign({},options.timerState || {}); data[name] = {elapsed:0,running:false}; set("timerState",data) }
    readonly property QtObject timers: QtObject {
        readonly property real pomodoroSecondsLeft: root.left("focus")
        readonly property real pomodoroLapDuration: root.duration("focus")
        readonly property bool pomodoroRunning: !!root.timerValue("focus").running && pomodoroSecondsLeft > 0
        readonly property bool pomodoroPaused: !pomodoroRunning && root.elapsed("focus") > 0
        readonly property bool pomodoroBreak: !!root.timerValue("focus").isBreak
        readonly property bool pomodoroLongBreak: pomodoroBreak && Number(root.timerValue("focus").cycle || 0)+1 >= Number(root.options.cyclesBeforeLongBreak || 4)
        readonly property real stopwatchTime: root.elapsed("stopwatch") * 100
        readonly property bool stopwatchRunning: !!root.timerValue("stopwatch").running
        readonly property bool stopwatchPaused: !stopwatchRunning && stopwatchTime > 0
        readonly property real countdownSecondsLeft: root.left("countdown")
        readonly property real countdownDuration: root.duration("countdown")
        readonly property bool countdownRunning: !!root.timerValue("countdown").running && countdownSecondsLeft > 0
        readonly property bool countdownPaused: !countdownRunning && root.elapsed("countdown") > 0
        function togglePomodoro() { root.toggle("focus") }
        function resetPomodoro() { root.reset("focus") }
        function toggleStopwatch() { root.toggle("stopwatch") }
        function stopwatchReset() { root.reset("stopwatch") }
        function toggleCountdown() { root.toggle("countdown") }
        function resetCountdown() { root.reset("countdown") }
        function adjustCountdownDuration(seconds) { root.set("countdownSeconds",Math.max(1,Number(root.options.countdownSeconds || 300) + seconds)) }
    }
    readonly property QtObject worldClock: QtObject {
        readonly property date now: root.now
        readonly property var entries: root.zoneData.entries || []
        readonly property var offsetsMinutes: entries.map(row => row.offset)
        function cityDisplayDate(index) {
            const city = entries[index]
            if (!city) return new Date(NaN)
            return new Date(city.year,city.month-1,city.day,city.hour,city.minute,city.second)
        }
    }
    readonly property QtObject news: QtObject {
        readonly property var articles: root.newsData.articles || []
        readonly property string lastError: root.newsData.error || ""
        readonly property bool loading: !!root.runtime && root.runtime.requests[root.key + "news"] !== undefined
        function formatTime(value) { const date = new Date(value); return isNaN(date.getTime()) ? "" : Qt.formatDateTime(date,"HH:mm") }
        function openArticle(article) { const url = article.url || article.link || ""; if (/^https?:\/\//.test(url)) Qt.openUrlExternally(url) }
    }
    readonly property QtObject screenTime: QtObject {
        readonly property bool enabled: root.options.enabled === true && !!root.runtime
        readonly property string currentAppName: root.runtime ? root.runtime.currentAppName : ""
        property int revision: root.runtime ? root.runtime.usageRevision : 0
        signal dataChanged()
        onRevisionChanged: dataChanged()
        function getToday() { return root.runtime ? root.runtime.todayUsage() : {totalSeconds:0,hourly:Array(24).fill(0),apps:{}} }
        function getAppList(days) {
            const apps = getToday().apps || {}
            return Object.keys(apps).map(name => ({id:name,originalId:name,name:name, appId:name, icon:name, seconds:apps[name], totalSeconds:apps[name]})).sort((a,b) => b.seconds-a.seconds)
        }
    }
    property var brightnessData: ({available:false,value:0})
    readonly property QtObject brightness: QtObject {
        readonly property real brightness: root.brightnessData.value || 0
        function setBrightness(value) { root.request("brightness",{value:value},"brightness") }
        function getMonitorForScreen(screen) { return root.brightnessData.available ? root.brightness : null }
    }
}
