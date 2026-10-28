pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var backend: null
    property string loadError: ""
    property bool loadFinished: false

    readonly property bool moduleReady: backend !== null
    readonly property var adapter: backend ? backend.adapter : null
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property bool discovering: adapter ? adapter.discovering : false
    readonly property string adapterName: adapter ? (adapter.name || adapter.adapterId || "") : ""
    readonly property var devices: backend ? backend.devices : null
    readonly property string unavailableReason: {
        if (loadError !== "")
            return loadError
        if (!loadFinished)
            return ""
        if (!adapter)
            return "Адаптер Bluetooth не найден. Проверьте, что BlueZ запущен и адаптер подключён"
        return ""
    }

    // Quickshell owns the live model; the bridge supplies async results and Agent1.
    property string error: ""
    property string operation: ""
    property string operationPath: ""
    property int serial: 0
    property var agentRequest: null
    property bool scanOwned: false
    property bool scanStopping: false
    property bool stopRequested: false
    property bool bridgeReady: true
    readonly property bool busy: operation !== "" || scanStopping || (backend ? backend.adapterBusy : false)
    readonly property var deviceList: devices ? devices.values : []
    readonly property var batteryDevices: powered ? deviceList.filter(d => batteryText(d) !== "") : []
    readonly property int connectedCount: deviceList.filter(d => d.connected).length
    readonly property string statusText: !loadFinished ? "Загрузка Bluetooth…"
        : unavailableReason || (backend ? backend.adapterStatus : "") || (!powered ? "Bluetooth выключен" : discovering ? "Идёт поиск устройств…"
        : connectedCount ? "Устройство подключено" : "Bluetooth включён")

    property var bridgeCommand: ["python3", decodeURIComponent(Qt.resolvedUrl("../../scripts/bluetooth-bridge.py").toString()).replace(/^file:\/\//, "")]
    property Process bridge: Process {
        command: root.bridgeCommand
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: data => root.receive(data) }
        stderr: StdioCollector { }
        onExited: function(code) {
            root.bridgeReady = false
            root.operation = ""
            root.agentRequest = null
            root.scanOwned = false
            root.scanStopping = false
            root.error = "Сервис операций Bluetooth недоступен. Проверьте BlueZ и python-gobject, затем перезапустите Nayori."
        }
    }
    property Timer scanLimit: Timer {
        interval: 60000
        onTriggered: root.stopDiscovery()
    }

    onPoweredChanged: if (!powered && scanOwned) stopDiscovery()
    onAdapterChanged: if (!adapter) { scanOwned = false; scanLimit.stop() }

    function receive(data) {
        try {
            const message = JSON.parse(data)
            if (message.event === "agent") {
                agentRequest = message.request
            } else if (message.event === "scanStopped") {
                scanStopping = false
                if (!message.error) {
                    scanOwned = false
                    scanLimit.stop()
                } else {
                    error = "Не удалось остановить поиск: " + message.error
                    scanLimit.restart()
                }
            } else if (message.event === "fatal") {
                error = "BlueZ недоступен: " + message.error
            } else if (message.event === "result" && message.id === serial) {
                const previous = operation
                operation = ""
                operationPath = ""
                if (message.error) error = "Ошибка Bluetooth: " + message.error
                if (previous === "power" && !powered && !message.error) {
                    scanOwned = false
                    scanLimit.stop()
                }
                if (previous === "scan" && !message.error) {
                    scanOwned = true
                    scanLimit.restart()
                }
                if (stopRequested) {
                    stopRequested = false
                    stopDiscovery()
                }
            }
        } catch (exception) {
            error = "Некорректный ответ сервиса Bluetooth"
        }
    }
    function request(op, path, value): bool {
        if (busy || !bridgeReady || !adapter || !path) return false
        error = ""
        operation = op
        operationPath = path
        serial++
        bridge.write(JSON.stringify({id: serial, op: op, path: path, value: value}) + "\n")
        return true
    }
    function setPowered(value): bool {
        return request("power", adapter ? adapter.dbusPath : "", !!value)
    }
    function setDiscovering(value): bool {
        if (!value) { stopDiscovery(); return true }
        if (!powered || scanOwned) return false
        return request("scan", adapter.dbusPath, true)
    }
    function stopDiscovery() {
        if (operation === "scan") { stopRequested = true; return }
        if (scanOwned && !scanStopping && bridgeReady) {
            scanStopping = true
            bridge.write(JSON.stringify({op: "stopScan"}) + "\n")
        }
    }
    function deviceBusy(device): bool {
        return busy || device.pairing || (backend && backend.deviceBusy(device))
    }
    function act(device, action): bool {
        if (!powered || !device || deviceBusy(device)) return false
        return request(action, device.dbusPath, null)
    }
    function answerAgent(accept, value) {
        if (!agentRequest) return
        bridge.write(JSON.stringify({op: "reply", request: agentRequest.id, accept: accept, value: value || ""}) + "\n")
    }
    function batteryText(device): string {
        const value = device.battery
        return device.connected && device.batteryAvailable && typeof value === "number"
            && isFinite(value) && value >= 0 && value <= 1 ? Math.round(value * 100) + "%" : ""
    }

    function load() {
        if (loadFinished)
            return
        const component = Qt.createComponent("BluetoothBackend.qml")
        if (component.status === Component.Error) {
            loadError = "Модуль Quickshell.Bluetooth недоступен. Управление Bluetooth в Nayori выключено"
            loadFinished = true
            return
        }
        if (component.status === Component.Loading) {
            component.statusChanged.connect(function() {
                finishLoad(component)
            })
            return
        }
        finishLoad(component)
    }

    function finishLoad(component) {
        if (loadFinished)
            return
        if (component.status === Component.Loading) return
        if (component.status !== Component.Ready) {
            loadError = "Модуль Quickshell.Bluetooth недоступен. Управление Bluetooth в Nayori выключено"
            loadFinished = true
            return
        }
        backend = component.createObject(root)
        if (!backend)
            loadError = "Модуль Quickshell.Bluetooth недоступен. Управление Bluetooth в Nayori выключено"
        loadFinished = true
    }

    Component.onCompleted: load()
}
