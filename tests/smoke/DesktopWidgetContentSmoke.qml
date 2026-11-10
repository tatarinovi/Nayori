pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "tokens"
import "tokens/AccentRoles.js" as AccentRoles
import "surfaces/desktop"
import "services/niri"

ShellRoot {
    id: test
    property int phase: 0
    property string note: ""
    property int moved: 0
    property real resizedWidth: 0
    property real resizedHeight: 0
    property int menus: 0
    property int plays: 0
    function check(ok, message) { if (!ok) { console.error("DESKTOP_CONTENT_FAIL " + message); Qt.exit(1) } }
    function findItem(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) { const result = findItem(child, name); if (result) return result }
        return null
    }
    Tokens { id: theme }
    Test.TestEvent { id: input }
    FontMetrics { id: clockMetrics; font.family: "Nayori Zen Clock"; font.pixelSize: 80 }
    SystemReader { id: systemReader }
    QtObject {
        id: player
        property bool isPlaying: true
        property string trackTitle: "Трек"
        property string trackArtist: "Исполнитель"
        property string trackAlbum: "Альбом"
        property real length: 120
        property real position: 20
        function togglePlaying() { test.plays++ }
    }
    QtObject { id: audio; property bool available: true; property real energy: 0.8 }
    FloatingWindow {
        visible: true; implicitWidth: 520; implicitHeight: 400
        color: theme.color.background
        DesktopWidgetFaces {
            id: faces
            x: 260; width: 260; height: 168
            tokens: theme
            items: [{ id: "face", type: "note", x: 0, y: 0, size: "compact", style: "card", text: "пример" }]
            hiddenIds: test.phase > 0 ? ["face"] : []
        }
        DesktopWidgetFrame {
            id: frame
            tokens: theme
            screenWidth: 520; screenHeight: 400
            spec: ({ id: "note", type: "note", x: 20, y: 20, size: "compact", style: "card", text: test.note })
            onNoteEdited: (id, value) => test.note = value
            onMenuRequested: (id, x, y) => test.menus++
            onCommitPosition: (id, x, y, snap) => test.moved++
            onCommitGeometry: (id, x, y, width, height) => { test.resizedWidth = width; test.resizedHeight = height }
        }
        DesktopWidgetFrame {
            id: clockFrame
            tokens: theme
            screenWidth: 1200; screenHeight: 800
            spec: ({ id: "clock", type: "clock", x: 700, y: 0, size: "large", style: "card" })
        }
        ClockWidget {
            id: clockWidget
            width: 388; height: 148
            tokens: theme
            now: new Date(2025, 3, 24, 14, 28)
            large: true
            size: "large"
        }
        DesktopWidgetFrame {
            id: systemFrame
            tokens: theme
            systemReader: systemReader
            spec: ({id: "system", type: "system", x: 300, y: 20, size: "compact", style: "card"})
        }
        SystemWidget {
            id: systemDetailed
            x: 800; width: 388; height: 278; size: "large"
            tokens: theme
            reader: ({cpu: 0.3, gpu: 0.4, gpuFailed: false, gpuName: "GPU", cpuTemp: 55, gpuTemp: 60,
                      memoryUsedKb: 2000, memoryTotalKb: 4000, gpuMemoryUsedKb: 1000, gpuMemoryTotalKb: 2000,
                      networkRx: 1000, networkTx: 2000, networkRxHistory: [500, 1000], networkTxHistory: [1000, 2000], cpuHistory: [0.1, 0.2], gpuHistory: [0.2, 0.4],
                      topProcesses: [{name: "one", cpu: 6}, {name: "two", cpu: 4}, {name: "three", cpu: 1}]})
        }
        SystemWidget {
            id: systemWidget
            width: 278; height: 184
            tokens: theme
            reader: systemReader
        }
        WeatherWidget {
            id: weatherWidget
            width: 216; height: 124
            tokens: theme
            service: ({ city: "Москва", error: "", loading: false, data: { current_condition: [{ temp_C: "18", weatherCode: "116" }], weather: [{ date: "2026-11-02", maxtempC: "21", mintempC: "13" }] } })
        }
        MusicWidget {
            id: musicWidget
            x: 20; y: 250; width: 268; height: 120
            tokens: theme
            music: ({ player: player })
            audioReaction: audio
        }
    }
    Timer {
        interval: 300; repeat: true; running: true
        onTriggered: {
            if (test.phase === 0) {
                Niri.applyEvent({OverviewOpenedOrClosed: {is_open: true}}, Niri._streamEpoch)
                test.check(Niri.overviewOpen, "overview opened")
                Niri.applyEvent({OverviewOpenedOrClosed: {is_open: false}}, Niri._streamEpoch)
                test.check(!Niri.overviewOpen, "overview closed")
                test.check(test.findItem(faces, "desktop-widget-face").visible, "wallpaper face shown")
                const clockContent = test.findItem(clockFrame, "desktop-widget-content")
                test.check(clockContent.x === 16 && clockContent.y === 16
                           && clockFrame.width - clockContent.x - clockContent.width === 16
                           && clockFrame.height - clockContent.y - clockContent.height === 16,
                           "clock card padding is equal on all sides")
                const frameClockTime = test.findItem(clockFrame, "desktop-clock-time")
                test.check(frameClockTime.style === Text.Normal, "card frame uses filled style")
                clockFrame.spec = ({ id: "clock", type: "clock", x: 700, y: 0, size: "large", style: "plain" })
                test.check(frameClockTime.style === Text.Outline && clockContent.x === 0, "cardless frame uses outline")
                const clockTime = test.findItem(clockWidget, "desktop-clock-time")
                const clockDate = test.findItem(clockWidget, "desktop-clock-date-side")
                test.check(clockWidget.clockFontReady && clockTime.font.family === "Nayori Zen Clock", "bundled clock font loaded")
                test.check(Math.abs(clockMetrics.advanceWidth("1") - clockMetrics.advanceWidth("8")) < 0.1, "clock digits have equal width")
                const monthLabel = test.findItem(clockWidget, "desktop-clock-month")
                const weekdayLabel = test.findItem(clockWidget, "desktop-clock-weekday")
                test.check(monthLabel.contentWidth <= monthLabel.width && weekdayLabel.contentWidth <= weekdayLabel.width, "date text fits")
                clockWidget.card = false
                test.check(clockTime.style === Text.Outline, "cardless clock has outlined text")
                clockWidget.card = true
                test.check(clockTime.style === Text.Normal, "card clock uses plain text")
                test.check(clockTime.text === "14:28" && clockTime.color === clockWidget.clockAccent && clockDate.visible, "clock displays themed time and date")
                test.check(AccentRoles.contrast(clockTime.color, theme.color.background) >= 4.5, "dark clock accent contrast")
                test.check(AccentRoles.luminance(clockTime.color) > AccentRoles.luminance(theme.color.background), "dark theme clock is light")
                clockWidget.wallpaperAccent = "#E9C8EF"
                test.check(String(clockTime.color).toUpperCase() === "#E9C8EF", "clock uses wallpaper accent")
                theme.colorScheme = "light"
                clockWidget.card = false
                test.check(AccentRoles.contrast(clockTime.color, clockWidget.outlineColor) >= 4.5, "cardless light-theme clock contrasts with outline")
                test.check(AccentRoles.luminance(clockTime.color) > AccentRoles.luminance(clockWidget.outlineColor), "cardless light-theme clock stays light")
                clockWidget.card = true
                test.check(AccentRoles.contrast(clockTime.color, theme.color.background) >= 4.5, "light clock accent contrast")
                test.check(AccentRoles.luminance(clockTime.color) < AccentRoles.luminance(theme.color.background), "light theme clock is dark")
                theme.accentDerived = true
                theme.accentSource = "#357795"
                const lightWallpaperColor = String(clockTime.color)
                test.check(AccentRoles.contrast(clockTime.color, theme.color.background) >= 4.5, "light wallpaper accent contrast")
                theme.colorScheme = "dark"
                test.check(AccentRoles.contrast(clockTime.color, theme.color.background) >= 4.5, "dark wallpaper accent contrast")
                test.check(String(clockTime.color) !== lightWallpaperColor, "clock responds to theme")
                theme.accentDerived = false
                test.check(clockTime.width > 0 && clockTime.width + clockDate.width <= clockWidget.width, "clock fits large card")
                test.check(clockDate.y >= 0 && clockDate.y + clockDate.height <= clockWidget.height, "date centered without clipping")
                test.check(test.findItem(clockWidget, "desktop-clock-day").text === "24", "clock date uses day")
                test.check(Math.abs(clockDate.x + clockDate.width - clockWidget.width) < 0.1, "date aligns to right edge")
                for (const spec of [{size: "large", width: 388, height: 122},
                                     {size: "extraLarge", width: 528, height: 168},
                                     {size: "huge", width: 668, height: 213}]) {
                    clockWidget.size = spec.size
                    clockWidget.width = spec.width
                    clockWidget.height = spec.height
                    clockWidget.now = new Date(2026, 8, 28, 11, 11)
                    test.check(clockDate.y >= 0 && clockDate.y + clockDate.height <= clockWidget.height, "date fits " + spec.size)
                    test.check(monthLabel.contentWidth <= monthLabel.width && weekdayLabel.contentWidth <= weekdayLabel.width, "long date fits " + spec.size)
                    test.check(clockTime.contentWidth <= clockTime.width + 0.5, "time fits " + spec.size)
                }
                clockWidget.width = 388; clockWidget.height = 148; clockWidget.size = "large"
                clockWidget.now = new Date(2025, 3, 24, 14, 28)
                clockWidget.editing = true
                test.check(clockTime.fontSizeMode === Text.Fit, "clock fits while editing")
                clockWidget.editing = false
                clockWidget.large = false
                clockWidget.size = "compact"
                test.check(!clockDate.visible && test.findItem(clockWidget, "desktop-clock-date-compact").visible, "compact clock date")
                const forecast = test.findItem(weatherWidget, "desktop-weather-forecast")
                test.check(forecast.visible && forecast.mapToItem(weatherWidget, 0, forecast.height).y <= weatherWidget.height, "compact weather forecast fits")
                weatherWidget.service = null
                test.check(weatherWidget.message === "Погода недоступна", "weather unavailable fallback")
                const play = test.findItem(musicWidget, "desktop-music-play")
                const previous = test.findItem(musicWidget, "desktop-music-previous")
                const next = test.findItem(musicWidget, "desktop-music-next")
                test.check(play && previous && next && play.width === 40 && play.height === 40 && previous.width === 40 && next.width === 40, "larger music controls")
                const pos = play.mapToItem(musicWidget, 0, 0)
                test.check(pos.y >= 0 && pos.y + play.height <= musicWidget.height, "music controls fit compact card")
                const progress = test.findItem(musicWidget, "desktop-music-progress")
                const progressBottom = progress.mapToItem(musicWidget, 0, progress.height).y
                test.check(progressBottom <= pos.y && pos.y + play.height <= musicWidget.height, "compact music progress and controls fit")
                input.mouseClick(play, 20, 20, Qt.LeftButton, Qt.NoModifier, -1)
                test.check(test.plays === 1, "music play button works")
                const systemContent = test.findItem(systemFrame, "desktop-widget-content")
                test.check(systemContent.x === 16 && systemContent.y === 10 && systemFrame.height - systemContent.y - systemContent.height === 10, "system card vertical padding")
                systemReader.showDetails = true
                systemReader.consumeExtra('{"cpuTemp":55,"rx":1000,"tx":500,"processes":[{"name":"firefox","cpu":6}]}')
                test.check(systemReader.cpuTemp === 55 && systemReader.topProcesses.length === 1 && systemReader.networkRx === null, "initial extra data")
                systemReader.networkRx = 500; systemReader.networkTx = 1000; systemReader.recordNetwork()
                test.check(systemReader.networkRxHistory[systemReader.networkRxHistory.length - 1] === 500 && systemReader.networkTxHistory[systemReader.networkTxHistory.length - 1] === 1000, "network samples recorded")
                for (let i = 0; i < 35; i++) systemReader.recordNetwork()
                test.check(systemReader.networkRxHistory.length === 30 && systemReader.networkTxHistory.length === 30, "network history bounded")
                systemReader.consumeExtra("bad")
                test.check(systemReader.networkRxHistory[systemReader.networkRxHistory.length - 1] === -1, "missing network sample leaves a gap")
                test.check(systemReader.cpuTemp === null && systemReader.topProcesses.length === 0, "invalid extra data fallback")
                systemReader.consumeCpu("cpu 100 0 50 200 10 0 0 0\n")
                systemReader.consumeCpu("cpu 110 0 60 240 20 0 0 0\n")
                systemReader.consumeMemory("MemTotal: 16777216 kB\nMemAvailable: 10485760 kB\n")
                systemReader.consumeGpu("NVIDIA\n42, 2048, 8192, 52\n")
                test.check(systemReader.gpu === 0.42 && systemReader.gpuMemoryUsedKb === 2097152, "NVIDIA GPU memory parsed")
                test.check(test.findItem(systemWidget, "desktop-system-detail-memory").text === "6.4 / 17.2 GB", "memory detail shown")
                test.check(test.findItem(systemWidget, "desktop-system-detail-gpu").text === "2.1 / 8.6 GB", "GPU memory detail shown")
                const detail = test.findItem(systemWidget, "desktop-system-detail-gpu")
                test.findItem(systemWidget, "desktop-system-meters").forceLayout()
                test.check(detail.mapToItem(systemWidget, 0, detail.height).y <= systemWidget.height, "system detail fits compact card")
                systemReader.consumeGpu("AMD\n50\n1073741824\n4294967296\n52000\n")
                test.check(systemReader.gpu === 0.5 && systemReader.gpuMemoryTotalKb === 4194304 && systemReader.gpuTemp === 52, "AMD GPU data parsed")
                systemReader.consumeGpu("NVIDIA\n42, N/A, N/A, N/A\n")
                test.check(systemReader.gpu === 0.42 && test.findItem(systemWidget, "desktop-system-detail-gpu").text === "—" && systemReader.gpuTemp === null, "missing GPU memory and temperature handled")
                systemReader.consumeMemory("broken")
                test.check(systemReader.memoryUsedKb === null && systemReader.memoryTotalKb === null, "invalid RAM data cleared")
                systemReader.consumeGpu("42\n")
                test.check(systemReader.gpu === 0.42 && !systemReader.gpuFailed, "GPU percentage parsed")
                systemReader.consumeGpu("N/A")
                test.check(systemReader.gpu === null && systemReader.gpuFailed, "unavailable GPU handled")
                test.check(!test.findItem(systemFrame, "desktop-system-gpu").visible, "missing GPU hidden")
                const audioBar = test.findItem(musicWidget, "desktop-music-waveform")
                test.check(audioBar && audioBar.visible && audioBar.level > 0, "audio visualizer responds")
                player.isPlaying = false
                test.check(!audioBar.visible, "audio visualizer hidden on pause")
                player.isPlaying = true
                theme.animationsEnabled = false
                test.check(!audioBar.visible, "audio visualizer hidden with animations disabled")
                theme.animationsEnabled = true
                audio.available = false
                test.check(!audioBar.visible, "audio visualizer hidden when unavailable")
                systemReader.consumeGpu("42\n")
                test.check(systemFrame.height === systemFrame.box.height, "GPU return restores system card")
                const editor = test.findItem(frame, "desktop-note-editor")
                test.check(editor && frame.takesInput, "note is interactive")
                input.mouseClick(frame, 8, 8, Qt.RightButton, Qt.NoModifier, -1)
                test.check(test.menus === 1, "right click opens menu")
                input.mouseClick(editor, 10, 10, Qt.LeftButton, Qt.NoModifier, -1)
                input.keyClickChar("a", Qt.NoModifier, -1)
                test.check(editor.activeFocus && editor.text === "a", "note accepts keyboard input")
            } else if (test.phase === 2) {
                const compactNetworkGraph = test.findItem(systemWidget, "desktop-network-graph")
                test.check(compactNetworkGraph && compactNetworkGraph.visible && compactNetworkGraph.mapToItem(systemWidget, 0, compactNetworkGraph.height).y <= systemWidget.height, "network graph fits compact size")
                const networkGraph = test.findItem(systemDetailed, "desktop-network-graph")
                test.check(networkGraph && networkGraph.visible && networkGraph.peak === 2000 && networkGraph.mapToItem(systemDetailed, 0, networkGraph.height).y <= systemDetailed.height, "network graph fits medium size and uses a shared scale")
                const lastProcess = test.findItem(systemDetailed, "desktop-system-process-2")
                test.check(lastProcess && lastProcess.mapToItem(systemDetailed, 0, lastProcess.height).y <= systemDetailed.height, "all processes fit medium system widget")
                systemDetailed.size = "extraLarge"
                systemDetailed.width = 508; systemDetailed.height = 368
                test.check(!test.findItem(faces, "desktop-widget-face").visible, "interactive face hidden on backdrop")
                test.check(test.note === "a", "note edit saved")
                musicWidget.large = true
                musicWidget.height = 152
                frame.editing = true
                frame.forceActiveFocus()
                input.keyClick(Qt.Key_Right, Qt.NoModifier, -1)
                test.check(test.moved === 1, "keyboard moves widget")
                const grip = test.findItem(frame, "desktop-widget-resize")
                test.check(grip && grip.visible, "resize grip shown")
                input.mousePress(grip, 14, 14, Qt.LeftButton, Qt.NoModifier, -1)
                input.mouseMove(frame, 286, 184, 20, Qt.LeftButton, Qt.NoModifier)
                input.mouseRelease(frame, 286, 184, Qt.LeftButton, Qt.NoModifier, -1)
                test.check(test.resizedWidth > 260 && test.resizedHeight > 168 && Math.abs(test.resizedWidth / test.resizedHeight - 260 / 168) < 0.02, "resize drag commits custom dimensions")
            } else if (test.phase === 3) {
                const networkGraph = test.findItem(systemDetailed, "desktop-network-graph")
                test.check(networkGraph && networkGraph.mapToItem(systemDetailed, 0, networkGraph.height).y <= systemDetailed.height, "network graph fits large size")
                const lastProcess = test.findItem(systemDetailed, "desktop-system-process-2")
                test.check(lastProcess && lastProcess.mapToItem(systemDetailed, 0, lastProcess.height).y <= systemDetailed.height, "all processes fit large system widget")
                const play = test.findItem(musicWidget, "desktop-music-play")
                const pos = play.mapToItem(musicWidget, 0, 0)
                test.check(pos.y >= 0 && pos.y + play.height <= musicWidget.height, "music controls fit large card")
                const progress = test.findItem(musicWidget, "desktop-music-progress")
                const progressBottom = progress.mapToItem(musicWidget, 0, progress.height).y
                test.check(progressBottom <= pos.y && pos.y + play.height <= musicWidget.height, "large music progress and controls fit")
                frame.spec = ({ id: "note", type: "note", x: 20, y: 20, size: "compact", style: "card", text: "a", opacity: 0.6, width: 320, height: 210 })
                test.check(frame.opacity === 0.6 && frame.width === 320 && frame.height === 210, "instance appearance applied")
                frame.inputOverlay = true
                frame.editing = false
                frame.focusId = ""
                test.check(frame.box.width === 320 && frame.box.height === 210, "saved dimensions reach frame")
                console.log("DESKTOP_CONTENT_PASS")
                Qt.quit()
            }
            test.phase++
        }
    }
}
