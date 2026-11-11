pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtTest
import Quickshell
import "tokens"
import "services/system"
import "surfaces/island"
import "surfaces/desktop"

ShellRoot {
    id: testRoot
    Tokens { id: theme; animationsEnabled: false }
    SystemMonitor {
        id: monitor
        testCommand: ["python3", "-u", "-c", "import json,time; print(json.dumps({'time':1,'memory':{'used':8*1024**3,'total':16*1024**3}}),flush=True); time.sleep(30)"]
    }
    QtObject {
        id: fixture
        property bool profileAvailable: true
        property bool hasPerformanceProfile: true
        property string profile: "balanced"
        property string profileError: ""
        function chooseProfile(key) { profile = key }
        property bool ready: true
        property string error: ""
        property var info: ({osName: "Arch Linux", kernel: "6.18.2"})
        property var networkStatus: ({wifiConnected: true, ethernetConnected: false, wifiLabel: "Домашняя сеть", ethernetLabel: "Отключено"})
        property var histories: ({})
        property var data: ({time:60, uptime:482820, cpu: {load:9, ghz:3, model:"AMD Ryzen 7 · длинное название процессора", cores:8, threads:16}, memory:{used:10.2*1024*1024*1024,total:16*1024*1024*1024}, gpus:[{id:"0000:01:00.0",model:"NVIDIA RTX 3060",load:49,temperature:42,used:2*1024**3,total:8*1024**3}], disks:[{id:"/",mount:"/",source:"/dev/nvme0n1p2",used:858.6*1024**3,total:1.21*1024**4,available:380*1024**3,read:265.4*1024,write:0,ioDevice:"nvme0n1p2"}],network:[{id:"wlan0",state:"up",down:6.2*1024,up:7.1*1024,tunnel:false}],temperatures:[{kind:"cpu",value:44},{kind:"ssd",value:35}],profile:"balanced",status:"running"})
        property bool subscribed: false
        function consumer(key, shown) { subscribed = shown }
    }
    FloatingWindow {
        id: win
        visible: true; implicitWidth: 760; implicitHeight: 590
        color: theme.color.background
        IslandDashboard { id: dashboard; width: parent.width; height: parent.height; tokens: theme; testMode: true; systemMonitorService: fixture; monitoring: true; currentPage: 3; showDate: false }
    }
    SystemReader { id: adapter; monitorService: fixture; active: true }
    function find(parent, name) {
        if (parent.objectName === name) return parent
        for (const child of parent.children || []) { const found = find(child, name); if (found) return found }
        return null
    }
    Timer { interval: 400; running: true; onTriggered: { try { tests.test_selectors(); tests.test_dashboard(); tests.test_worker_lifecycle_and_history(); Qt.quit() } catch (error) { console.error("SYSTEM_MONITOR_FAIL", error, error.stack); Qt.exit(1) } } }
    TestCase {
        id: tests
        name: "SystemMonitor"
        when: false
        function checkGraphs() {
            for (const name of ["systemCpuCard", "systemGpuCard", "systemDiskCard", "systemNetworkCard"]) {
                const card = testRoot.find(dashboard, name)
                const graph = testRoot.find(card, "systemGraph")
                if (!graph || !graph.visible) continue
                if (graph.height < 18) throw new Error(name + " graph height " + graph.height)
                if (graph.mapToItem(card, 0, graph.height).y > card.height + 0.5) throw new Error(name + " graph outside card " + graph.mapToItem(card, 0, graph.height).y + " / " + card.height)
            }
        }
        function test_selectors() {
            const original = fixture.data
            const multiple = JSON.parse(JSON.stringify(original))
            multiple.disks.push(Object.assign({}, multiple.disks[0], {id:"/home",mount:"/home"}))
            multiple.network.push(Object.assign({}, multiple.network[0], {id:"eth0"}))
            multiple.gpus.push(Object.assign({}, multiple.gpus[0], {id:"0000:02:00.0"}))
            multiple.disks.push(Object.assign({}, multiple.disks[0], {id:"/mnt/data",mount:"/mnt/data"}))
            multiple.disks.push(Object.assign({}, multiple.disks[0], {id:"/mnt/backup",mount:"/mnt/backup"}))
            multiple.disks.push(Object.assign({}, multiple.disks[0], {id:"/mnt-other",mount:"/mnt-other"}))
            multiple.disks.push(Object.assign({}, multiple.disks[0], {id:"/mnt",mount:"/mnt"}))
            fixture.data = multiple
            wait(50)
            compare(testRoot.find(dashboard, "systemDiskPicker"), null)
            compare(testRoot.find(dashboard, "systemDiskMountLabel0").text, "/")
            compare(testRoot.find(dashboard, "systemDiskMountLabel1").text, "/mnt/backup")
            compare(testRoot.find(dashboard, "systemDiskMountLabel2").text, "/mnt/data")
            compare(testRoot.find(dashboard, "systemDiskMountLabel3"), null)
            const mountCard = testRoot.find(dashboard, "systemDiskCard")
            const lastMount = testRoot.find(mountCard, "systemDiskMount2")
            verify(lastMount.mapToItem(mountCard, 0, lastMount.height).y <= mountCard.height)
            fixture.data = Object.assign({}, multiple, {disks: [Object.assign({}, multiple.disks[0], {id:"/home",mount:"/home"})]})
            wait(50)
            verify(!mountCard.visible)
            fixture.data = multiple
            wait(50)
            for (const kind of ["Network", "Gpu"]) {
                const picker = testRoot.find(dashboard, "system" + kind + "Picker")
                verify(picker.visible)
                picker.popup.open()
                tryCompare(dashboard, "popupOpen", true)
                wait(700) // Longer than ScreenPanels' 600 ms auto-collapse delay.
                verify(dashboard.popupOpen)
                compare(dashboard.currentPage, 3)
                dashboard.closePopups()
                tryCompare(dashboard, "popupOpen", false)
                picker.popup.open()
                tryCompare(dashboard, "popupOpen", true)
                dashboard.currentPage = 1
                tryCompare(picker.popup, "visible", false)
                compare(dashboard.popupOpen, false)
                dashboard.currentPage = 3
            }
            fixture.data = original
            wait(50)
        }
        function checkTitles() {
            const names = ["Cpu", "Gpu", "Memory", "Disk", "Network", "State", "Power"]
            for (const name of names) {
                const card = testRoot.find(dashboard, "system" + name + "Card")
                if (!card.visible) continue
                const title = testRoot.find(card, "systemCardTitle")
                const icon = testRoot.find(title, "systemIcon")
                const text = testRoot.find(title, "systemCardTitleText")
                const top = title.mapToItem(card, 0, 0).y
                if (Math.abs(top - (dashboard.width < 600 ? 8 : 10)) > 0.5) throw new Error(name + " title top " + top)
                const iconCenter = icon.mapToItem(title, 0, icon.height / 2).y
                const textCenter = text.mapToItem(title, 0, text.height / 2).y
                fuzzyCompare(textCenter, iconCenter + 1, 0.5)
            }
        }
        function checkPower() {
            const state = testRoot.find(dashboard, "systemStateCard")
            const power = testRoot.find(dashboard, "systemPowerCard")
            verify(state.visible && power.visible)
            verify(state.x < power.x)
            compare(state.y, power.y)
            verify(state.height <= 104 && power.height <= 104)
            compare(testRoot.find(dashboard, "systemTemperatureCard"), null)
            const buttons = ["power-saver", "balanced", "performance"].map(key => testRoot.find(dashboard, "systemProfile-" + key))
            for (const button of buttons) {
                verify(button.parent.parent === power.children[0])
                fuzzyCompare(button.width, buttons[0].width, 1)
                compare(button.height, buttons[0].height)
                compare(button.y, buttons[0].y)
                const icon = testRoot.find(button, "systemIcon")
                compare(icon.status, Image.Ready)
                const center = icon.mapToItem(button, icon.width / 2, icon.height / 2)
                fuzzyCompare(center.y, button.height / 2, 0.5)
                if (dashboard.width < 600) fuzzyCompare(center.x, button.width / 2, 0.5)
            }
        }
        function test_dashboard() {
            compare(dashboard.pageCount, 4)
            tryCompare(fixture, "subscribed", true)
            const layout = testRoot.find(dashboard, "systemLayout")
            verify(layout !== null)
            const cpu = testRoot.find(dashboard, "systemCpuCard")
            const gpu = testRoot.find(dashboard, "systemGpuCard")
            const ram = testRoot.find(dashboard, "systemMemoryCard")
            verify(cpu.width > 220 && cpu.width < 250)
            verify(gpu.x > cpu.x && ram.x > gpu.x)
            compare(testRoot.find(dashboard, "systemCpuValue").text, "9%")
            checkGraphs()
            checkPower()
            checkTitles()
            compare(adapter.cpu, 0.09)
            compare(adapter.memoryUsedKb, 10.2*1024*1024)
            verify(!adapter.localActive)
            const histories = {}
            const points = []
            for (let i=0; i<60; i++) points.push({t:i+1,v:15+12*Math.sin(i/4)})
            for (const key of ["cpu","gpu:0000:01:00.0","disk:/","net:wlan0"]) histories[key]=points
            fixture.histories = histories
            wait(100)
            let saved = false
            dashboard.grabToImage(result => { result.saveToFile("/tmp/nayori-system-wide.png"); saved = true })
            tryVerify(() => saved)
            dashboard.width = 360; dashboard.height = 520
            wait(100)
            verify(cpu.width > 90 && cpu.width < 110)
            verify(gpu.x > cpu.x && ram.x > gpu.x)
            checkGraphs()
            checkPower()
            checkTitles()
            const state = testRoot.find(dashboard, "systemStateCard")
            const page = state.parent.parent.parent
            verify(state.mapToItem(page, 0, state.height).y <= page.height + 1)
            const saver = testRoot.find(dashboard, "systemProfile-power-saver")
            verify(saver.enabled)
            saver.clicked()
            compare(fixture.profile, "power-saver")
            fixture.profileAvailable = false
            verify(!saver.enabled)
            fixture.profileAvailable = true
            fixture.hasPerformanceProfile = false
            verify(!testRoot.find(dashboard, "systemProfile-performance").enabled)
            fixture.hasPerformanceProfile = true
            saved = false
            dashboard.grabToImage(result => { result.saveToFile("/tmp/nayori-system-narrow.png"); saved = true })
            tryVerify(() => saved)
            const available = JSON.parse(JSON.stringify(fixture.data))
            const reduced = JSON.parse(JSON.stringify(available))
            reduced.gpus = []
            reduced.temperatures = [{kind:"cpu",value:44}]
            fixture.data = reduced
            wait(50)
            verify(!gpu.visible)
            verify(cpu.width > 150 && ram.width > 150)
            verify(testRoot.find(dashboard, "systemUptimeCompact").visible)
            verify(testRoot.find(dashboard, "systemUptimeCompact").text.includes("5 д"))
            verify(testRoot.find(dashboard, "systemPowerCard").visible)
            fixture.profileAvailable = false
            wait(50)
            verify(!testRoot.find(dashboard, "systemPowerCard").visible)
            verify(testRoot.find(dashboard, "systemStateCard").width > 300)
            fixture.profileAvailable = true
            fixture.data = ({})
            verify(!cpu.visible && !gpu.visible && !ram.visible)
            compare(testRoot.find(dashboard, "systemCpuValue").text, "—")
            compare(adapter.cpu, null)
            compare(adapter.gpu, null)
            dashboard.currentPage = 1
            tryCompare(fixture, "subscribed", false)
            dashboard.currentPage = 3
            tryCompare(fixture, "subscribed", true)
            dashboard.monitoring = false
            tryCompare(fixture, "subscribed", false)
        }
        function test_worker_lifecycle_and_history() {
            compare(monitor.worker.running, false)
            monitor.consumer("a", true)
            monitor.consumer("b", true)
            tryCompare(monitor, "ready", true, 3000)
            monitor.cpu.active = false
            monitor.cpu.consume("cpu 100 0 0 100 0 0 0 0") // disabled: must stay unknown
            monitor.consume(JSON.stringify({time:2,cpu:{},gpus:[{id:"gpu",load:null}],network:[],disks:[]}))
            compare(monitor.data.cpu.load, null)
            for (let i=3; i<150; i++) monitor.consume(JSON.stringify({time:i,cpu:{},gpus:[{id:"gpu",load:i%100}]}))
            verify(monitor.histories["gpu:gpu"].length <= 61)
            verify(monitor.histories["gpu:gpu"][0].t > 89)
            monitor.consume(JSON.stringify({time:151,cpu:{},gpus:[]}))
            compare(monitor.histories["gpu:gpu"], undefined)
            monitor.consume("bad json")
            compare(monitor.ready, false)
            compare(Object.keys(monitor.data).length, 0)
            monitor.consume(JSON.stringify({time:152,cpu:{}}))
            compare(monitor.ready, true)
            monitor.consumer("a", false)
            verify(monitor.worker.running)
            monitor.consumer("b", false)
            tryCompare(monitor.worker, "running", false)
            compare(Object.keys(monitor.histories).length, 0)
            for (let i=0; i<4; i++) {
                monitor.consumer("cycle", true)
                tryCompare(monitor, "ready", true, 3000)
                monitor.consumer("cycle", false)
                tryCompare(monitor.worker, "running", false)
            }
            monitor.consumer("restart", true)
            tryCompare(monitor, "ready", true, 3000)
            monitor.worker.running = false
            tryCompare(monitor, "ready", false)
            tryCompare(monitor, "ready", true, 5000)
            monitor.consumer("restart", false)
            tryCompare(monitor.worker, "running", false)
            console.log("SYSTEM_MONITOR_PASS")
        }
    }
}
