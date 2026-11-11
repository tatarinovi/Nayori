pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire as Pw
import Quickshell.Wayland
import QtMultimedia
import "../system"
import "../status"
import "../niri"

// One shell-owned I/O queue. No background requests until a visible widget asks.
QtObject {
    id: root
    property var settings: null
    property var bluetooth: null
    property var notifications: null
    property var notificationModel: null
    property int noticeId: -90000000
    property var pending: []
    property var requests: ({})
    property var results: ({})
    property int serial: 0
    property string workerError: ""
    property var capabilities: ({})
    property bool nightlightActive: false
    readonly property bool gameMode: !!settings && settings.values.importedWidgetGameMode === true
    property var workerCommand: ["python3", "-u", Qt.resolvedUrl("imported_widget_worker.py").toString().replace(/^file:\/\//, "")]
    property bool testMode: false
    signal requestSent(string operation, var payload, string key)
    signal response(string key, var data)
    signal settingsRequested()
    signal sessionRequested()
    signal actionRequested(string action)
    property var profileConsumers: ({})
    property UserProfile profile: UserProfile { active: Object.keys(root.profileConsumers).length > 0 }
    function profileConsumer(key, wanted) {
        const next = Object.assign({},profileConsumers)
        if (wanted) next[key] = true; else delete next[key]
        profileConsumers = next
    }
    property Audio audio: Audio {}
    property NetworkControl network: NetworkControl {}
    property Network networkStatus: Network {}
    property SessionActions session: SessionActions {}
    property var inhibitWindow: null
    property IdleInhibitor inhibitor: IdleInhibitor { enabled: root.keepAwake; window: root.inhibitWindow }
    property IdleMonitor idleMonitor: IdleMonitor { enabled: Object.keys(root.usageConsumers).length > 0; timeout: 300; respectInhibitors:false }
    property bool keepAwake: false
    readonly property var source: Pw.Pipewire.defaultAudioSource
    property Pw.PwObjectTracker sourceTracker: Pw.PwObjectTracker { objects: root.source ? [root.source] : [] }
    function request(op, data, key) {
        requestSent(op, data, key)
        if (testMode) return
        if (requests[key] && requests[key].op === op && JSON.stringify(requests[key].data) === JSON.stringify(data)) return
        const token = ++serial
        const next = Object.assign({}, requests); next[key] = {op:op, data:data,token:token}; requests = next
        pending = pending.filter(row => row.key !== key).concat([{op:op, data:data, key:key,token:token}])
        worker.running = true
        flush()
    }
    function flush() {
        if (!worker.running || !worker.connected) return
        const queue = pending; pending = []
        for (const row of queue) worker.write(JSON.stringify(row) + "\n")
    }
    function accept(key, data, token) {
        const job = requests[key]
        if (!testMode && (!job || token !== undefined && token !== job.token)) return
        if (job && job.op === "capabilities" && !data.error) capabilities = data
        if (job && job.op === "nightlight" && !data.error) nightlightActive = data.enabled
        if (data.error) workerError = data.error
        const next = Object.assign({}, results); next[key] = data; results = next
        const jobs = Object.assign({}, requests); delete jobs[key]; requests = jobs
        response(key, data)
    }
    function release(prefix) {
        const jobs = Object.assign({},requests), cache = Object.assign({},results)
        for (const key of Object.keys(jobs)) if (key.startsWith(prefix)) delete jobs[key]
        for (const key of Object.keys(cache)) if (key.startsWith(prefix)) delete cache[key]
        requests = jobs; results = cache; pending = pending.filter(row => !row.key.startsWith(prefix))
    }
    property Process worker: Process {
        property bool connected: false
        command: root.workerCommand
        stdinEnabled: true
        onStarted: { connected = true; root.flush() }
        onExited: {
            connected = false
            for (const key of Object.keys(root.requests)) root.accept(key, {error:"Widget worker stopped",exitCode:1,exitStatus:0})
        }
        stdout: SplitParser {
            onRead: line => {
                try { const row = JSON.parse(line); root.accept(row.key, row.data, row.token) }
                catch (error) { root.workerError = "Invalid widget worker response" }
            }
        }
    }
    function toggleMicMute() { if (source && source.audio) source.audio.muted = !source.audio.muted }
    function toggleDnd() { if (settings) settings.update({notificationsDndManual: !notifications.active, notificationsDndUntil:0}) }
    function toggleNightlight() { request("nightlight",{enabled:!nightlightActive},"nightlight") }
    function toggleGameMode() { if (settings) settings.update({importedWidgetGameMode:!gameMode}) }
    function toggleDarkMode() { if (settings) settings.update({colorScheme:settings.values.colorScheme === "light" ? "dark" : "light"}) }
    function playSound(path, volume, loop) {
        if (!/^reusables\/fillbutton\/(button|charge_loop)\.wav$/.test(path)) return -1
        const effect = loop ? loopSound : clickSound
        effect.stop(); effect.source = Qt.resolvedUrl("../../surfaces/desktop/vendor/widgets/assets/sounds/" + path)
        effect.volume = Math.max(0,Math.min(1,volume)); effect.play()
        return loop ? 2 : 1
    }
    function stopSound(handle) { if (handle === 2) loopSound.stop(); else if (handle === 1) clickSound.stop() }
    property SoundEffect clickSound: SoundEffect {}
    property SoundEffect loopSound: SoundEffect { loops: SoundEffect.Infinite }
    function action(name) {
        actionRequested(name)
        if (testMode) return
        if (name === "settings") settingsRequested()
        else if (name === "session") sessionRequested()
        else if (name === "lock") session.lock()
        else if (name === "sleep") session.suspend()
        else if (name === "reboot") session.reboot()
        else if (name === "poweroff") session.powerOff()
        else if (name === "equalizer") { if (capabilities.easyeffects) Quickshell.execDetached(["easyeffects"]); else workerError = "EasyEffects is not installed" }
    }
    function notify(title, body) {
        if (!testMode && notificationModel) notificationModel.receive({id:noticeId--,appName:"Виджеты",appIcon:"alarm",summary:title,body:body,urgency:1,actions:[]})
    }
    function timerLayouts() { return settings && settings.ready ? settings.values.desktopWidgets || {} : {} }
    function hasRunningTimers() {
        const layouts = timerLayouts()
        return Object.keys(layouts).some(screen => (layouts[screen].items || []).some(item => item.type === "shima_timers" && item.options && item.options.timerState && ["focus","countdown"].some(name => item.options.timerState[name] && item.options.timerState[name].running)))
    }
    function advanceTimers(now) {
        const layouts = JSON.parse(JSON.stringify(timerLayouts()))
        let changed = false
        for (const screen of Object.keys(layouts)) for (const item of layouts[screen].items || []) {
            if (item.type !== "shima_timers" || !item.options || !item.options.timerState) continue
            const opts = item.options, state = opts.timerState
            let notice = ""
            if (state.focus && state.focus.running) {
                const t = state.focus
                // Bound catch-up after a long suspend; keep the phase anchored to its deadline.
                for (let count = 0; count < 1000; count++) {
                    const longBreak = t.isBreak && Number(t.cycle || 0) + 1 >= Number(opts.cyclesBeforeLongBreak || 4)
                    const duration = Math.max(1,Number(t.isBreak ? longBreak ? opts.longBreakMinutes || 15 : opts.breakMinutes || 5 : opts.focusMinutes || 25) * 60)
                    const elapsed = Number(t.elapsed || 0) + (now - Number(t.startedAt || now)) / 1000
                    if (elapsed < duration) break
                    t.startedAt = now - (elapsed-duration)*1000; t.elapsed = 0; t.isBreak = !t.isBreak
                    if (!t.isBreak) t.cycle = (Number(t.cycle || 0)+1) % Math.max(1,Number(opts.cyclesBeforeLongBreak || 4))
                    changed = true; notice = t.isBreak ? "Пора сделать перерыв" : "Время сосредоточиться"
                }
            }
            if (state.countdown && state.countdown.running && Number(state.countdown.elapsed || 0) + (now-Number(state.countdown.startedAt || now))/1000 >= Number(opts.countdownSeconds || 300)) {
                state.countdown = {elapsed:Number(opts.countdownSeconds || 300),running:false}; changed = true; notice = "Таймер завершён"
            }
            if (notice) notify("Таймер",notice)
        }
        if (changed && settings) settings.update({desktopWidgets:layouts})
    }
    property Timer timerClock: Timer { interval:1000; repeat:true; running:root.hasRunningTimers(); onTriggered:root.advanceTimers(Date.now()) }
    // Shared foreground accounting is opt-in and stored by SettingsService.
    property var usageConsumers: ({})
    property var usage: settings && settings.values.importedWidgetUsage || ({})
    property int usageRevision: 0
    property int unsavedSeconds: 0
    readonly property string currentAppName: (Niri.windows.find(window => window.focused) || {}).appId || ""
    function usageConsumer(key, wanted) {
        const next = Object.assign({}, usageConsumers)
        if (wanted) next[key] = true; else delete next[key]
        usageConsumers = next
    }
    function todayUsage() { return usage[Qt.formatDate(new Date(), "yyyy-MM-dd")] || {totalSeconds:0,hourly:Array(24).fill(0),apps:{}} }
    function saveUsage() { if (settings && settings.ready && unsavedSeconds) { settings.update({importedWidgetUsage:usage}); unsavedSeconds = 0 } }
    property Timer usageClock: Timer {
        interval: 1000; repeat: true
        running: !!root.settings && root.settings.ready && Object.keys(root.usageConsumers).length > 0
        onRunningChanged: if (!running) root.saveUsage()
        onTriggered: {
            if (!root.currentAppName || root.idleMonitor.isIdle) return
            const next = JSON.parse(JSON.stringify(root.usage)), key = Qt.formatDate(new Date(), "yyyy-MM-dd")
            const day = next[key] || {totalSeconds:0,hourly:Array(24).fill(0),apps:{}}
            day.totalSeconds++; day.hourly[new Date().getHours()]++; day.apps[root.currentAppName] = (day.apps[root.currentAppName] || 0) + 1
            next[key] = day
            for (const old of Object.keys(next).sort().slice(0, Math.max(0,Object.keys(next).length-31))) delete next[old]
            root.usage = next; root.usageRevision++; root.unsavedSeconds++
            if (root.unsavedSeconds >= 30) root.saveUsage()
        }
    }
    Component.onDestruction: saveUsage()
}
