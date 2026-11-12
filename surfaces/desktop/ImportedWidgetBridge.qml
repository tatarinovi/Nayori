import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "vendor/widgets"
import "ImportedWidgets.js" as ImportedWidgets
import "ImportedWidgetData.js" as ImportedData
import "vendor/widgets/PythonTranslations.js" as PythonTranslations
import "../../services/desktop"

// Per-instance read adapters. System workers and persistence remain owned by
// Nayori; this object never writes upstream config or starts a process.
Item {
    id: root
    required property var tokens
    property string type: ""
    property var savedOptions: ({})
    property var runtime: null
    property var pendingOptions: null
    signal optionsEdited(var options)
    signal settingsRequested()
    function requestSettings() { settingsRequested() }
    function editOption(key, value) {
        const parts = key.split(".")
        if (parts.some(part => ["__proto__","constructor","prototype"].includes(part))) return
        const next = ImportedWidgets.clone(pendingOptions || savedOptions || {})
        let target = next
        for (const part of parts.slice(0,-1)) { if (!target[part] || typeof target[part] !== "object") target[part] = {}; target = target[part] }
        target[parts[parts.length-1]] = value
        pendingOptions = next
        optionsEdited(pendingOptions)
    }
    function optionKey(path) {
        const marker = ".widgets." + (entry ? entry.id : "") + "."
        return path.includes(marker) ? path.split(marker).pop() : path.split(".").pop()
    }
    function optionValue(key, fallback) {
        let value = options
        for (const part of key.split(".")) { if (value === null || value === undefined) return fallback; value = value[part] }
        return value === undefined ? fallback : value
    }
    onSavedOptionsChanged: pendingOptions = null
    onTypeChanged: pendingOptions = null
    function sessionAction(name) { if (runtime) runtime.action(name) }
    property ImportedWidgetInstance instance: ImportedWidgetInstance { host: root }
    property bool active: true
    property var systemReader: null
    property var music: null
    property var calendarStore: null
    property var weatherService: null
    property var audioReaction: null
    property real hostX: 0
    property real hostY: 0
    property string wallpaperSource: ""
    readonly property var systemSnapshot: systemReader && systemReader.monitorService ? systemReader.monitorService.data : ({})
    readonly property var disk: (systemSnapshot.disks || []).find(row => row.mount === "/") || null
    readonly property var entry: ImportedWidgets.entry(type)
    readonly property var options: ImportedWidgets.options(type, pendingOptions || savedOptions)
    readonly property bool dynamicColors: options.dynamicColors === true
    readonly property int motionDuration: tokens.motion.off ? 0 : 200
    readonly property bool reducedMotion: tokens.motion.off
    property alias colorUtils: colorUtilities
    ColorUtils { id: colorUtilities }
    SystemClock { id: systemClock; enabled: root.active; precision: SystemClock.Seconds }
    readonly property QtObject dateTime: QtObject {
        readonly property var clock: systemClock
        readonly property date now: systemClock.date
        readonly property string hours: String(systemClock.hours)
        readonly property string minutes: String(systemClock.minutes).padStart(2, "0")
        readonly property string seconds: String(systemClock.seconds).padStart(2, "0")
        readonly property string hour: String(systemClock.hours).padStart(2, "0")
        readonly property string minute: minutes
        readonly property bool hasSeconds: true
        readonly property bool is12Hour: false
        readonly property bool use12HourClock: false
        readonly property string time: Qt.formatDateTime(systemClock.date, "HH:mm")
        readonly property string longDate: Qt.formatDateTime(systemClock.date, "dddd, d MMMM")
        readonly property string uptime: root.runtime ? root.runtime.profile.uptime : ""
        readonly property string meridiem: systemClock.hours < 12 ? "AM" : "PM"
    }
    readonly property var config: ({
        ready: true,
        getNestedValue: function(path, fallback) { return root.optionValue(root.optionKey(path), fallback) },
        setNestedValue: function(path,value) { root.editOption(root.optionKey(path),value) },
        setNestedValues: function(values) { for (const key of Object.keys(values)) this.setNestedValue(key,values[key]) },
        getSetting: function(key,fallback) { return fallback },
        rawSettings: {},
        options: {
            panelFamily: "iris",
            background: {widgets: ImportedWidgets.widgetDefaults(root.type, root.options)},
            appearance: {transparency: {enable: false, popups: false}},
            iris: {appearance: Object.assign({frontend: "inir"}, root.options.irisAppearance || {}),widgets:{material:root.options.irisMaterial || "solid",outline:root.options.irisOutline || "auto",opacity:root.options.irisOpacity ?? 100}},
            bar: {weather: {city: root.weatherService ? root.weatherService.city : ""}},
            lock: {centerWidget: "", showLockedText: false},
            time: {secondPrecision: true, firstDayOfWeek: 0, format: "HH:mm"}
        }
    })
    readonly property QtObject globalStates: QtObject {
        property bool screenLocked: false
        property bool widgetEditMode: false
        property bool shellEntryReady: true
        property bool sessionOpen: false
        onSessionOpenChanged: if (sessionOpen) { root.sessionAction("session"); sessionOpen = false }
        function openSettings() { root.sessionAction("settings") }
        function openIrisEqualizer(screen) { root.sessionAction("equalizer") }
    }
    readonly property var translation: ({locale: Qt.locale(), tr: function(value) { return value }})
    readonly property var scaler: ({s: function(value) { return value }})
    readonly property var i18n: ({tr: function(value) { return value }, currentLang: Qt.locale().name, t: function(key, fallback) { return PythonTranslations.t(Qt.locale().name.split("_")[0], key, fallback) }})
    readonly property var directories: ({assetsPath: Qt.resolvedUrl("vendor/widgets/assets").toString().replace(/^file:\/\//, ""), generatedWallpaperCategoryPath: "", picturesPath:Quickshell.env("HOME") + "/Pictures", userAvatarSourcePrimary:root.systemInfo.avatarPath ? "file://" + root.systemInfo.avatarPath : "", userAvatarPaths:root.systemInfo.avatarPath ? [root.systemInfo.avatarPath] : [], avatarSourceAt:function(index) { return index === 0 && root.systemInfo.avatarPath ? "file://" + root.systemInfo.avatarPath : "" }, payloadPath: function(path) { return Qt.resolvedUrl("vendor/widgets/" + path) }})

    readonly property var weatherData: ImportedData.weather(weatherService ? weatherService.data : null, weatherService ? weatherService.city : "", options.weatherUnit || "metric", accent.toString(), systemClock.date)
    readonly property QtObject weather: QtObject {
        readonly property var data: Object.assign({}, root.weatherData, {sunset: root.sunset})
        readonly property bool enabled: !!root.weatherService && root.weatherService.enabled
        readonly property bool isReady: !!root.weatherCurrent
        readonly property bool isLoading: !!root.weatherService && root.weatherService.loading
        readonly property string currentTemp: root.weatherData.current_temp
        readonly property string currentIcon: root.weatherData.current_icon
        readonly property string currentHex: root.accent.toString()
        readonly property bool showVisibleCity: true
        readonly property string visibleCity: root.weatherService ? root.weatherService.city : ""
        readonly property bool stale: !!root.weatherService && !!root.weatherService.error
        readonly property string updatedLabel: root.weatherService && root.weatherService.updatedAt ? Qt.formatDateTime(new Date(root.weatherService.updatedAt), "HH:mm") : "—"
        signal weatherUpdated()
        onDataChanged: weatherUpdated()
        function isNightNow() { return systemClock.hours < 6 || systemClock.hours >= 18 }
        function displayTime(label, minutes) { return label }
    }
    readonly property var location: ({city: root.weatherService ? root.weatherService.city : ""})
    readonly property var network: ({online:root.runtime ? root.runtime.networkStatus.linked : !root.weatherService || !root.weatherService.error, offlineReason:"Network unavailable", ethernet:root.runtime ? root.runtime.networkStatus.ethernetConnected : false, wifiEnabled:root.runtime ? root.runtime.network.wifiEnabled : false, networkName:root.runtime ? root.runtime.networkStatus.wifiLabel : "", toggleWifi:function() { if (root.runtime) root.runtime.network.setWifiEnabled(!root.runtime.network.wifiEnabled) }})
    property Icons icons: Icons {}
    readonly property var weatherCurrent: root.weatherService && root.weatherService.data && root.weatherService.data.current_condition ? root.weatherService.data.current_condition[0] : null
    readonly property string sunset: {
        const data = root.weatherService ? root.weatherService.data : null
        return data && data.weather && data.weather[0] && data.weather[0].astronomy && data.weather[0].astronomy[0] ? data.weather[0].astronomy[0].sunset : ""
    }
    readonly property QtObject battery: QtObject {
        readonly property real percentage: UPower.displayDevice.percentage
        readonly property bool available: UPower.displayDevice.isPresent
        readonly property bool isCharging: UPower.displayDevice.state === UPowerDeviceState.Charging
        readonly property bool isPluggedIn: UPower.onBattery === false
        readonly property bool isLow: available && percentage <= 0.2
        readonly property real timeToFull: available ? UPower.displayDevice.timeToFull : 0
        readonly property real timeToFullEffective: timeToFull
        readonly property real timeToEmpty: available ? UPower.displayDevice.timeToEmpty : 0
        readonly property bool atChargeCeiling: available && UPower.displayDevice.state === UPowerDeviceState.FullyCharged
        // UPower exposes full charge, not a configured vendor-specific ceiling.
        readonly property bool chargeLimitReached: false
    }
    readonly property QtObject resourceUsage: QtObject {
        readonly property real cpuUsage: root.sysData.cpu / 100
        readonly property real gpuUsage: root.systemReader && root.systemReader.gpu !== null ? root.systemReader.gpu : NaN
        readonly property real cpuTemp: root.sysData.temp
        readonly property real gpuTemp: root.systemReader && root.systemReader.gpuTemp !== null ? root.systemReader.gpuTemp : NaN
        readonly property real memoryUsed: root.systemReader && root.systemReader.memoryUsedKb !== null ? root.systemReader.memoryUsedKb : NaN
        readonly property real memoryTotal: root.systemReader && root.systemReader.memoryTotalKb !== null ? root.systemReader.memoryTotalKb : NaN
        readonly property real diskUsed: root.disk ? root.disk.used : NaN
        readonly property real diskTotal: root.disk ? root.disk.total : NaN
        readonly property real diskUsedPercentage: root.disk ? root.disk.used / root.disk.total : NaN
        readonly property var cpuUsageHistory: root.systemReader ? root.systemReader.cpuHistory : []
        readonly property var memoryUsageHistory: []
        readonly property var gpuUsageHistory: root.systemReader ? root.systemReader.gpuHistory : []
        readonly property var cpuTempHistory: []
        readonly property var gpuTempHistory: []
        function requestMetric(metric, wanted) {} // existing host owns the shared request
        function requestGpuMonitoring(wanted) {}
        readonly property real memoryUsedPercentage: root.systemReader && root.systemReader.memory !== null ? root.systemReader.memory : NaN
    }
    readonly property QtObject sysData: QtObject {
        readonly property real cpu: root.systemReader && root.systemReader.cpu !== null ? root.systemReader.cpu * 100 : NaN
        readonly property real ramPercent: root.systemReader && root.systemReader.memory !== null ? root.systemReader.memory * 100 : NaN
        readonly property real ramGb: root.systemReader && root.systemReader.memoryUsedKb !== null ? root.systemReader.memoryUsedKb / 1048576 : NaN
        readonly property real temp: root.systemReader && root.systemReader.cpuTemp !== null ? root.systemReader.cpuTemp : NaN
        readonly property real diskGb: root.disk ? root.disk.used / 1073741824 : NaN
        readonly property real diskTotalGb: root.disk ? root.disk.total / 1073741824 : NaN
        readonly property real diskPercent: root.disk ? root.disk.used / root.disk.total * 100 : NaN
        // The existing host controls the single shared monitor subscription.
        function subscribe() {}
        function unsubscribe() {}
    }
    readonly property var systemInfo: ({isDesktop: !UPower.displayDevice.isLaptopBattery,username:root.runtime ? root.runtime.profile.username : Quickshell.env("USER") || "",displayName:root.runtime ? root.runtime.profile.username : Quickshell.env("USER") || "",hostname:root.runtime ? root.runtime.profile.hostname : "",avatarPath:root.runtime ? root.runtime.profile.avatar.replace(/^file:\/\//,"") : "",distroId:""})
    readonly property var todo: instance.todo
    readonly property var timers: instance.timers
    readonly property var worldClock: instance.worldClock
    readonly property var news: instance.news
    readonly property var screenTime: instance.screenTime
    readonly property var brightness: instance.brightness
    readonly property var floating: ({showNotes:function(screen) { root.requestSettings() }})
    readonly property var sounds: ({playSfx:function(path,volume) { return root.runtime ? root.runtime.playSound(path,volume || 0.5,false) : -1 },playUntilStopped:function(path,volume,unused) { return root.runtime ? root.runtime.playSound(path,volume || 0.5,true) : -1 },stopSfx:function(handle) { if (root.runtime) root.runtime.stopSound(handle) }})
    readonly property var fileUtils: ({trimFileProtocol:function(path) { return String(path || "").startsWith("file://") ? decodeURIComponent(String(path).replace(/^file:\/\//,"")) : String(path || "") },fileNameForPath:function(path) { return String(path || "").split("/").pop() }})
    readonly property var images: ({validImageExtensions:["png","jpg","jpeg","webp","avif","bmp","gif","svg"],validVideoExtensions:["mp4","mkv","webm","mov"],isValidImageByName:function(path) { return /\.(png|jpe?g|webp|avif|bmp|gif|svg)$/i.test(path) },isValidVideoByName:function(path) { return /\.(mp4|mkv|webm|mov)$/i.test(path) },isValidMediaByName:function(path) { return this.isValidImageByName(path) || this.isValidVideoByName(path) }})
    readonly property var wallpaperListener: ({wallpaperUrlForScreen:function(screen) { return root.wallpaperSource }})
    readonly property var wallpapers: ({videoMotionAllowedOn:function(screen) { return root.active && !root.reducedMotion }})
    readonly property var widgetPower: ({widgetsActive:root.active,widgetsActiveForOutput:function(output) { return root.active }})
    readonly property var shellLayout: ({desktopInsets:function(screen) { return {left:0,right:0,top:0,bottom:0} }})
    readonly property var cavaTheme: ({primaryColor:root.accent,visualizerColors:[root.accent,root.tokens.color.secondary,root.ink]})
    readonly property var uiPreferences: ({shippedText:function(value) { return value }})
    readonly property var audio: ({sink:root.runtime ? root.runtime.audio.sink : null,source:root.runtime ? root.runtime.source : null,micMuted:root.runtime && root.runtime.source && root.runtime.source.audio ? root.runtime.source.audio.muted : true,value:root.runtime ? root.runtime.audio.level : 0,setSinkVolume:function(value) { if (root.runtime) root.runtime.audio.setVolume(value) },toggleMute:function() { if (root.runtime) root.runtime.audio.toggleMuted() },toggleMicMute:function() { if (root.runtime) root.runtime.toggleMicMute() }})
    readonly property var bluetooth: ({enabled:root.runtime && root.runtime.bluetooth ? root.runtime.bluetooth.powered : false,available:root.runtime && root.runtime.bluetooth ? root.runtime.bluetooth.adapter !== null : false,activeDeviceSummary:function() { return root.runtime && root.runtime.bluetooth ? String(root.runtime.bluetooth.connectedCount) : "" },toggle:function() { if (root.runtime && root.runtime.bluetooth) root.runtime.bluetooth.setPowered(!root.runtime.bluetooth.powered) }})
    readonly property var notifications: ({manualDndActive:root.runtime && root.runtime.notifications ? root.runtime.notifications.active : false,toggleSilent:function() { if (root.runtime) root.runtime.toggleDnd() }})
    readonly property var nightlight: ({active:root.runtime ? root.runtime.nightlightActive : false,available:root.runtime ? root.runtime.capabilities.nightlight === true : false,toggle:function() { if (root.runtime) root.runtime.toggleNightlight() }})
    readonly property var idle: ({inhibit:root.runtime ? root.runtime.keepAwake : false,toggleInhibit:function() { if (root.runtime) { root.runtime.inhibitWindow = root.QsWindow.window; root.runtime.keepAwake = !root.runtime.keepAwake } }})
    readonly property var gameMode: ({active:root.runtime ? root.runtime.gameMode : false,visualizersSuppressed:root.runtime ? root.runtime.gameMode : false,toggle:function() { if (root.runtime) root.runtime.toggleGameMode() }})
    readonly property string audioKey: "imported-widget-" + String(root)
    property int audioSubscribers: 0
    function syncAudio() {
        if (!audioReaction) return
        const wanted = active && audioSubscribers > 0 && !reducedMotion
        const system = type.indexOf("Visualizer") >= 0 || type === "shima_visualizer" || type === "shima_organicEdge"
        audioReaction.consumer(audioKey, wanted && !system)
        audioReaction.systemConsumer(audioKey, wanted && system)
    }
    onActiveChanged: { syncAudio(); syncLyrics() }
    onReducedMotionChanged: syncAudio()
    onAudioReactionChanged: syncAudio()
    Component.onDestruction: {
        if (audioReaction) { audioReaction.consumer(audioKey, false); audioReaction.systemConsumer(audioKey, false) }
        if (lyricsMusic && typeof lyricsMusic.consumer === "function") lyricsMusic.consumer(lyricsKey, false)
    }
    readonly property string lyricsKey: "imported-lyrics-" + String(root)
    property int lyricsSubscribers: 0
    property var lyricsMusic: null
    function syncLyrics() {
        if (lyricsMusic && lyricsMusic !== music && typeof lyricsMusic.consumer === "function") lyricsMusic.consumer(lyricsKey, false)
        lyricsMusic = music
        if (lyricsMusic && typeof lyricsMusic.consumer === "function") lyricsMusic.consumer(lyricsKey, active && lyricsSubscribers > 0)
    }
    onMusicChanged: syncLyrics()
    readonly property QtObject lyrics: QtObject {
        readonly property var player: root.music ? root.music.player : null
        readonly property bool isMediaActive: !!player
        readonly property bool loading: !!root.music && root.music.status === "loading"
        readonly property var source: root.instance.localLyrics && !root.instance.localLyrics.error ? root.instance.localLyrics : root.music
        readonly property var lyrics: !source ? [] : source.status === "synced"
            ? (source.lines || []).map(line => ({text:line.text, time:line.t, words:[]}))
            : source.status === "plain" && source.plainText ? String(source.plainText).split("\n").map(text => ({text:text, words:[]})) : []
        readonly property bool hasLyrics: lyrics.length > 0
        readonly property int currentIndex: {
            if (!source || source.status !== "synced") return -1
            if (source === root.music) return root.music.currentIndex
            let current = -1
            for (let i = 0; i < lyrics.length; i++) if (lyrics[i].time <= currentPosition) current = i
            return current
        }
        readonly property real currentPosition: root.music ? root.music.position : 0
        readonly property string status: hasLyrics ? "ok" : root.network.online ? "empty" : "offline"
        readonly property var lyricsLines: lyrics
        readonly property var slots: [-3,-2,-1,0,1,2,3].map(delta => lyrics[currentIndex + delta] ? lyrics[currentIndex + delta].text : "")
        function loadLocalLyricsFile(path) { root.editOption("localLyricsPath",path) }
        function subscribe() { root.lyricsSubscribers++; root.syncLyrics() }
        function unsubscribe() { root.lyricsSubscribers = Math.max(0, root.lyricsSubscribers - 1); root.syncLyrics() }
        function noteSeek(seconds) { if (root.music && typeof root.music.syncPosition === "function") root.music.syncPosition(true) }
        function getLineOpacity(index, current) { return Math.max(0.2, 0.7 - Math.abs(index - current) * 0.1) }
    }
    readonly property QtObject cava: QtObject {
        readonly property var barLevels: root.audioReaction ? root.audioReaction.spectrum : []
        readonly property int barCount: barLevels.length
        function registerConsumer() { root.audioSubscribers++; root.syncAudio() }
        function unregisterConsumer() { root.audioSubscribers = Math.max(0, root.audioSubscribers - 1); root.syncAudio() }
    }
    readonly property QtObject mpris: QtObject {
        readonly property var activePlayer: root.music ? root.music.player : null
        readonly property bool isPlaying: !!activePlayer && activePlayer.isPlaying
        readonly property string artUrl: activePlayer ? activePlayer.trackArtUrl || "" : ""
        readonly property string trackTitle: activePlayer ? activePlayer.trackTitle || "" : ""
        readonly property string trackArtist: activePlayer ? activePlayer.trackArtist || "" : ""
        readonly property real livePosition: root.music ? root.music.position : 0
        function titleOf(player) { return player ? player.trackTitle || "" : "" }
        function artistOf(player) { return player ? player.trackArtist || "" : "" }
        function effectiveArtUrl(player) { return player ? player.trackArtUrl || "" : "" }
    }
    readonly property var session: ({wallIsVideo: false, livePoster: "", wallpaper: root.wallpaperSource.replace(/^file:\/\//, "")})
    readonly property var caching: ({assetsPath: Qt.resolvedUrl("vendor/widgets/assets").toString().replace(/^file:\/\//, ""), payloadDir: Qt.resolvedUrl("vendor/widgets").toString().replace(/^file:\/\//, "")})
    readonly property var timeFormat: ({pattern: function() { return "HH:mm" }})
    property ShimaCalendarData calendarView: ShimaCalendarData { hostBridge: root }
    readonly property var calendarEvents: (calendarStore ? calendarStore.events : []).map(event => Object.assign({}, event, {content:event.title, summary:event.title, startDate: new Date(event.allDay ? event.start + "T00:00:00" : event.start), endDate: new Date(event.allDay ? event.end + "T00:00:00" : event.end)}))
    function eventsOn(date) {
        const start = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
        const end = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime()
        return calendarEvents.filter(event => event.startDate.getTime() < end && event.endDate.getTime() > start)
    }
    readonly property var calendarService: ({khalAvailable: !!root.calendarStore, events:root.calendarEvents, eventsForDay: function(date) { return root.eventsOn(date) }, isAllDayEvent: function(event) { return event.allDay }})
    readonly property var spawn: ({runApp: function(args, options) {
        if (Array.isArray(args) && args.length === 2 && args[0] === "xdg-open" && /^https:\/\//.test(args[1])) Qt.openUrlExternally(args[1])
    }})
    readonly property var faceData: ({
        capitalized: function(value) { const text = String(value === undefined || value === null ? "" : value); return text.charAt(0).toUpperCase() + text.slice(1) },
        eventDate: function(event) { return new Date(event ? event.startDate : 0) },
        upcomingEvents: function(from, days) {
            const end = new Date(from.getFullYear(), from.getMonth(), from.getDate() + days).getTime()
            return root.calendarEvents.filter(event => event.endDate.getTime() >= from.getTime() && event.startDate.getTime() < end).sort((a,b) => a.startDate - b.startDate)
        },
        hasEvents: function(date) { return root.eventsOn(date).length > 0 },
        eventTitle: function(event) { return event ? event.title : "" },
        eventTint: function(event, fallback) { return event && event.sourceColor ? event.sourceColor : fallback },
        eventWhen: function(event, now) { return event ? event.allDay ? "All day" : Qt.formatDateTime(event.startDate, "ddd HH:mm") : "" }
    })
    property bool shimaRequested: false
    onEntryChanged: if (entry && entry.category === "Shima widgets") shimaRequested = true
    readonly property var irisStyle: irisStyleLoader.item
    Loader {
        id: irisStyleLoader
        active: root.shimaRequested
        sourceComponent: IrisStyle { hostBridge: root }
    }
    readonly property var themeTokens: ({ui: "Inter", display: "Inter", mono: "monospace", light: root.tokens.light, paper: root.background, paperLift: root.surface, ink: root.ink, inkDim: root.muted, inkMuted: root.muted, sun: root.accent, inkOnBone: root.background, bone: root.ink})
    readonly property var irisMood: ({sampled: false, factor: function() { return 1 }})
    readonly property var compositorBlur: ({usable: false})
    property LumeMath lume: LumeMath { colorUtils: colorUtilities; function screenNamed(name) { return null } }
    readonly property var shimaWidget: ({
        _resourceModel: (root.options.resources || ["cpu", "mem", "gpu"]).map(key => ({key: key, label: key})),
        showLabels: root.options.showLabels !== false,
        timeLabel: "", animationsActive: !root.reducedMotion,
        _getValue: function(key) { return key === "cpu" ? root.resourceUsage.cpuUsage : key === "mem" ? root.resourceUsage.memoryUsedPercentage : key === "gpu" ? root.resourceUsage.gpuUsage : key === "temp" ? root.sysData.temp / 100 : key === "gpuTemp" ? root.resourceUsage.gpuTemp / 100 : NaN },
        _getDisplayText: function(key) { const v = this._getValue(key); return isFinite(v) ? String(Math.round(v * 100)) : "—" },
        sessionSeconds: Math.max(0, Number(root.systemSnapshot.uptime) || 0),
        sessionDay: Math.max(1, Math.floor(Number(root.systemSnapshot.uptime || 0) / 86400) + 1),
        bootLabel: root.systemSnapshot.uptime ? Qt.formatDateTime(new Date(systemClock.date.getTime() - root.systemSnapshot.uptime * 1000), "HH:mm") : "—",
        showSince: root.options.showSince !== false, showBreakdown: root.options.showBreakdown !== false,
        upcomingEvents: root.faceData.upcomingEvents(systemClock.date, Number(root.options.days || 7)),
        showAdjacentDays: root.options.showAdjacentDays !== false,
        temperatureText: root.weatherData.temp, showLocation: root.options.showLocation !== false,
        irisSize: root.options.irisSize || "small", scaleFactor: 1, cornerRadiusOverride: -1, widgetCardRadius: 22,
        powerActive: root.active, visible: root.active, ryokuHosted: true, motionActive: root.active && !root.reducedMotion,
        irisMaterial: root.options.irisMaterial || "solid", irisSurfaceOpacity: Math.max(0, Math.min(1, Number(root.options.irisOpacity ?? 100) / 100)), irisOutline: root.options.irisOutline || "auto", irisRim: false,
        inkOnLight: false, forceDarkInk: false, legibleAlways: false, regionBrightness: 0.2, regionBrightnessSpread: 0,
        irisAccent: root.dynamicColors || !root.irisStyle ? root.accent : root.irisStyle.accent, irisAccent2: root.dynamicColors || !root.irisStyle ? root.accent : root.irisStyle.secondaryAccent, irisAccent3: root.dynamicColors || !root.irisStyle ? root.accent : root.irisStyle.secondaryAccent,
        irisPlate: root.dynamicColors || !root.irisStyle ? root.surface : root.irisStyle.surface, ryokuInkOverride: Qt.color("transparent"), widgetTitleWeight: 500,
        stacked: false, stackPos: 0, stackShown: true, stack: null, stackDropHint: false, containsPress: false,
        x: 0, y: 0, ryokuScreenX: root.hostX, ryokuScreenY: root.hostY, screenWidth: root.width, screenHeight: root.height,
        outputName: "", parent: null,
        today: systemClock.date,
        dayFraction: (systemClock.hours * 3600 + systemClock.minutes * 60 + systemClock.seconds) / 86400,
        isDaytime: systemClock.hours >= 6 && systemClock.hours < 18,
        dayOfYear: Math.floor((Date.UTC(systemClock.date.getFullYear(), systemClock.date.getMonth(), systemClock.date.getDate()) - Date.UTC(systemClock.date.getFullYear(), 0, 0)) / 86400000),
        daysInYear: new Date(systemClock.date.getFullYear(), 1, 29).getMonth() === 1 ? 366 : 365,
        showWeekday: root.options.showWeekday !== false, showYear: root.options.showYear !== false, showOrdinal: root.options.showOrdinal !== false,
        irisOption: function(key, fallback) { return root.options[key] === undefined ? fallback : root.options[key] }
        ,noteText:root.options.text || "",showCompleted:root.options.showCompleted !== false,
        taskEntries:(root.options.tasks || []).map((task,index) => Object.assign({},task,{originalIndex:index})),pendingCount:(root.options.tasks || []).filter(task => !task.done).length,
        cities:root.worldClock.entries,showNames:root.options.showNames !== false,showOffsets:root.options.showOffsets !== false,
        cityDayDelta:function(index) { const city = root.worldClock.cityDisplayDate(index); return Math.round((Date.UTC(city.getFullYear(),city.getMonth(),city.getDate())-Date.UTC(systemClock.date.getFullYear(),systemClock.date.getMonth(),systemClock.date.getDate()))/86400000) },
        showHostname:root.options.showHostname !== false,showAvatar:root.options.showAvatar !== false,showWeather:root.options.showWeather !== false,lockScreen:function() { root.sessionAction("lock") },
        headlineIndex:Math.floor(systemClock.date.getTime()/Math.max(5000,Number(root.options.rotationSeconds || 30)*1000)),showMeta:root.options.showMeta !== false,
        formatSeconds:function(value) { const seconds = Math.max(0,Math.floor(value)); return String(Math.floor(seconds/60)).padStart(2,"0") + ":" + String(seconds%60).padStart(2,"0") }
    })
    readonly property var appearance: ({
        frontend:"iris",globalStyle:"iris",effectsEnabled:true,gameModeMinimal:root.gameMode.active,
        zzzEverywhere:false,cookieEverywhere:false,regaliaEverywhere:false,angelEverywhere:false,auroraEverywhere:false,inirEverywhere:false,editorialEverywhere:false,
        blurTopology:{unsupported:"unsupported"},blurBackendFor:function() { return "unsupported" },
        toggleDarkMode:function() { if (root.runtime) root.runtime.toggleDarkMode() },
        wallpaperDominantColor: root.accent, reducedMotion: root.reducedMotion, animationsEnabled: !root.reducedMotion, calcEffectiveDuration: function(ms) { return root.reducedMotion ? 0 : ms },
        fontSizeScale: 1, font: {family: {main: "Space Grotesk", title: "Fraunces", numbers: "SpaceMono Nerd Font", display: "Fraunces", expressive: "Space Grotesk", reading: "sans-serif", monospace: "monospace", iconMaterial: "Material Symbols Rounded"},
            pixelSize: {small: 14, smallie: 13, smallest: 10, smaller: 12, normal: 16, large: 22, larger: 24, huge: 32}, variableAxes: {main: {}, title: {}, blend: function(a, b, t) { return Math.round(a + (b - a) * Math.round(Math.max(0, Math.min(1, t)) * 3) / 3) }}},
        rounding: {small: 8, normal: 12, large: 24, windowRounding: 24, verylarge: 32, full: 9999},
        sizes: {elevationMargin: 10}, transparency: {enable: false, popups: false},
        colors: root.colors, m3colors: root.colors.m3colors,
        cookie:{onColor:root.ink}, inir:{colBorder:root.muted}, aurora:{colTooltipBorder:root.muted,popupTransparentize:0},editorial:{glassActive:false,paperStack:false,glassBlur:0,glassOpacity:1,edge:root.muted},angel:{blurIntensity:0,blurSaturation:1,colInsetGlow:root.accent,insetGlowHeight:0,colorStrength:0,overlayOpacity:0},
        animationCurves: {standardDecel:[0.05,0.7,0.1,1,1,1],standard:[0.2,0,0,1,1,1],expressiveFastSpatial:[0.2,0,0,1,1,1],emphasized: [0.2, 0, 0, 1, 1, 1]},
        animation: {scroll:{duration:root.motionDuration,type:Easing.OutCubic,bezierCurve:[0.2,0,0,1,1,1]},elementMoveEnter:{duration:root.motionDuration,type:Easing.OutCubic,bezierCurve:[0.2,0,0,1,1,1]},elementMove: {duration: root.motionDuration, type: Easing.OutCubic,bezierCurve:[0.2,0,0,1,1,1]}, elementMoveFast: {duration: root.motionDuration, type: Easing.OutCubic, bezierCurve: [0.2, 0, 0, 1, 1, 1]}, elementMoveSnap: {duration: root.motionDuration, type: Easing.OutCubic,bezierCurve:[0.2,0,0,1,1,1]}}
    })
    readonly property color ink: dynamicColors ? tokens.color.text : "#cdc4ba"
    readonly property color muted: dynamicColors ? tokens.color.textMuted : "#b0a9a0"
    readonly property color accent: dynamicColors ? tokens.color.accent : "#e2342a"
    readonly property color background: dynamicColors ? tokens.color.background : "#000000"
    readonly property color surface: dynamicColors ? tokens.color.surface : "#0a0a0a"
    readonly property var colors: ({
        cardBgColor: root.surface, textColorOnBg: root.ink, subtextColorOnBg: root.muted,
        accentColor: root.accent, onAccentColor: root.background,
        pillBgColor: root.background, pillFillColor: root.accent,
        textColorOnPillFill: root.background, textColorOnPillTrack: root.ink,
        innerShapeColor: root.background, highlightCircleColor: root.accent, highlightTextColor: root.background,
        surfaceVariantColor: root.surface, successColor: "#b6cd9b", warningColor: "#e7c16f",
        colLayer0:root.background,colLayer1:root.surface,colOnLayer0:root.ink,colOnLayer1:root.ink,colOnPrimary:root.background,colOnPrimaryContainer:root.ink,colSubtext:root.muted,colPrimaryHover:root.accent,colPrimaryActive:root.accent,colSecondaryContainerHover:root.surface,colSecondaryContainerActive:root.surface,
        colLayer0Base: root.background, colScrim: "#000000", colPrimary: root.accent, colOnSecondary: root.background, colSecondary: root.accent,
        colTertiary: root.accent, colSecondaryContainer: root.surface, colOnSecondaryContainer: root.ink,
        colPrimaryContainer: root.surface, colOnSurface: root.ink,
        colSecondaryActive: root.surface, colSecondaryHover: root.surface,
        colLayer1Active: root.surface, colLayer1Hover: root.surface, colOutlineVariant: root.muted, colShadow: "#66000000",
        colors: {colTertiaryContainerHover:root.tokens.color.surfaceAlt,colTertiaryContainerActive:root.tokens.color.surfaceAlt,colLayer1Hover:root.tokens.color.surfaceAlt,colLayer1Active:root.tokens.color.surfaceAlt,colOnPrimary:root.background,colOnSecondary:root.background,colOnSurface:root.ink,colOnSurfaceVariant:root.muted,colSurfaceContainerHighest:root.tokens.color.surfaceAlt,colSurfaceContainerLow:root.surface,colOnSecondaryContainer: root.ink, colTertiary: root.accent, colSecondary: root.accent, colPrimary: root.accent, colPrimaryContainer:root.surface, colTertiaryContainer:root.surface, colOnTertiaryContainer:root.ink, colSecondaryContainer: root.surface, colShadow: "#66000000"},
        m3colors: {darkmode: !root.tokens.light, m3shadow: "#000000", m3background: root.background, m3onSurface: root.ink, m3surface: root.surface,m3surfaceContainer:root.surface,m3secondaryContainer:root.surface,m3tertiaryContainer:root.surface, m3secondary: root.muted, m3tertiary: root.accent, m3onPrimary: root.background, m3onBackground: root.ink, m3primary: root.accent},
        tintBackground: function(value) { return value }
    })
    readonly property QtObject pythonTheme: QtObject {
        readonly property color base: root.background
        readonly property color crust: root.background
        readonly property bool blurBackground: root.options.blurBackground === true
        readonly property bool liquidGlass: root.options.liquidGlass === true
        readonly property int clampedBorderRadius: 8
        readonly property string fontFamily: root.options.fontFamily || "JetBrainsMono Nerd Font"
        readonly property string iconFont: "JetBrainsMono Nerd Font Mono"
        readonly property int borderRadius: root.options.borderRadius === undefined ? 8 : Number(root.options.borderRadius)
        readonly property real elementOpacity: root.options.elementOpacity === undefined ? 1 : Number(root.options.elementOpacity) / 100
        readonly property color text: root.ink
        readonly property color onSurface: root.ink
        readonly property color subtext0: root.muted
        readonly property color subtext1: root.muted
        readonly property color overlay0: root.muted
        readonly property color overlay1: root.muted
        readonly property color overlay2: root.muted
        readonly property color surface0: root.surface
        readonly property color surface1: root.surface
        readonly property color surface2: root.surface
        readonly property color primary: root.accent
        readonly property color mauve: root.accent
        readonly property color peach: "#efb8a0"
        readonly property color yellow: "#ead49b"
        readonly property color green: "#b2cead"
        readonly property color red: "#e8a1a1"
        readonly property color teal: "#a0cfca"
        readonly property color blue: "#a6c8ee"
        readonly property color sapphire: "#93c6dc"
        readonly property color pink: "#dca7cc"
        readonly property var matugenColors: ({primary: root.accent})
    }
}
