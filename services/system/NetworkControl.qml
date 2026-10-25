pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Networking as QsNet

QtObject {
    id: root

    property bool scanning: false
    readonly property bool managerPresent: QsNet.Networking.backend === QsNet.NetworkBackendType.NetworkManager
    readonly property bool wifiHardwareEnabled: QsNet.Networking.wifiHardwareEnabled
    readonly property bool wifiEnabled: QsNet.Networking.wifiEnabled
    readonly property int connectivity: QsNet.Networking.connectivity
    readonly property var devices: QsNet.Networking.devices

    function setWifiEnabled(value): bool {
        if (!managerPresent || !wifiHardwareEnabled)
            return false
        QsNet.Networking.wifiEnabled = !!value
        return true
    }

    function setAutoconnect(device, value): bool {
        if (!device)
            return false
        device.autoconnect = !!value
        return true
    }

    function needsPsk(entry): bool {
        if (!entry || entry.known || entry.connected || entry.security === undefined)
            return false
        return entry.security !== QsNet.WifiSecurityType.Open && entry.security !== QsNet.WifiSecurityType.Owe
    }

    function pskSupported(entry): bool {
        return !!entry && (entry.security === QsNet.WifiSecurityType.WpaPsk
            || entry.security === QsNet.WifiSecurityType.Wpa2Psk
            || entry.security === QsNet.WifiSecurityType.Sae)
    }

    function disconnectEntry(entry): bool {
        if (!entry)
            return false
        entry.disconnect()
        return true
    }

    function connectEntry(entry): bool {
        if (!entry)
            return false
        entry.connect()
        return true
    }

    function connectWithPsk(entry, psk): bool {
        if (!entry || typeof psk !== "string" || psk.length === 0)
            return false
        entry.connectWithPsk(psk)
        return true
    }

    property Instantiator scanners: Instantiator {
        model: QsNet.Networking.devices
        delegate: QtObject {
            required property var modelData
            property Binding scanBinding: Binding {
                target: modelData.type === QsNet.DeviceType.Wifi ? modelData : null
                property: "scannerEnabled"
                value: root.scanning
                when: modelData.type === QsNet.DeviceType.Wifi
                restoreMode: Binding.RestoreBindingOrValue
            }
        }
    }
}
