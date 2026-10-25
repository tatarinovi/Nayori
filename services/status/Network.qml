pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Networking as QsNet

// Клиент NetworkManager через Quickshell.Networking.
// Статус подключения; управление соединениями открывается из панели.
QtObject {
    id: root

    readonly property bool managerPresent: QsNet.Networking.backend === QsNet.NetworkBackendType.NetworkManager
    readonly property int connectivity: QsNet.Networking.connectivity

    property bool available: false
    property bool linked: false
    property bool degraded: false
    property string label: ""
    property bool watching: false
    property bool scanning: false

    function publish(nextLabel, nextLinked, nextDegraded, nextAvailable) {
        label = nextLabel
        linked = nextLinked
        degraded = nextDegraded
        available = nextAvailable
    }

    function recompute() {
        if (!watching)
            return

        if (!managerPresent) {
            publish("", false, false, false)
            return
        }

        var wired = false
        var wifi = false
        var other = false
        var saw = false
        var count = devices.count
        for (var i = 0; i < count; i++) {
            var entry = devices.objectAt(i)
            if (entry === null)
                continue
            saw = true
            if (!entry.up)
                continue
            if (entry.kind === QsNet.DeviceType.Wired)
                wired = true
            else if (entry.kind === QsNet.DeviceType.Wifi)
                wifi = true
            else
                other = true
        }

        if (!saw) {
            publish("", false, false, false)
            return
        }

        if (connectivity === QsNet.NetworkConnectivity.Portal || connectivity === QsNet.NetworkConnectivity.Limited) {
            var captive = connectivity === QsNet.NetworkConnectivity.Portal
            publish(captive ? "portal" : "limited", true, true, true)
            return
        }

        if (wired || wifi || other) {
            publish(wired ? "lan" : (wifi ? "wifi" : "link"), true, false, true)
            return
        }

        if (connectivity === QsNet.NetworkConnectivity.Unknown) {
            publish("", false, false, false)
            return
        }

        publish("off", false, false, true)
    }

    onManagerPresentChanged: recompute()
    onConnectivityChanged: recompute()
    Component.onCompleted: {
        watching = true
        recompute()
    }

    // У QtObject нет свойства по умолчанию, поэтому список лежит в свойстве.
    property Instantiator devices: Instantiator {
        model: QsNet.Networking.devices

        delegate: QtObject {
            required property var modelData

            readonly property int kind: modelData.type
            property Binding scanBinding: Binding {
                target: kind === QsNet.DeviceType.Wifi ? modelData : null
                property: "scannerEnabled"
                value: root.scanning
                when: kind === QsNet.DeviceType.Wifi
                restoreMode: Binding.RestoreBindingOrValue
            }
            readonly property bool up: {
                if (modelData.connected)
                    return true
                return false
            }

            onKindChanged: root.recompute()
            onUpChanged: root.recompute()
            Component.onCompleted: root.recompute()
        }

        onObjectAdded: root.recompute()
        onObjectRemoved: root.recompute()
    }
}
