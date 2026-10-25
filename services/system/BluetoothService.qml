pragma ComponentBehavior: Bound

import QtQuick

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

    function setPowered(value): bool {
        if (!adapter)
            return false
        adapter.enabled = !!value
        return true
    }

    function setDiscovering(value): bool {
        if (!adapter || !adapter.enabled)
            return false
        adapter.discovering = !!value
        return true
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
