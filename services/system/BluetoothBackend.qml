pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth

// Загружается только через BluetoothService, если модуль существует.
QtObject {
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices : null
    readonly property bool adapterBusy: adapter && (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)
    readonly property string adapterStatus: !adapter ? "" : adapter.state === BluetoothAdapterState.Blocked ? "Bluetooth заблокирован. Проверьте аппаратный переключатель или rfkill"
        : adapter.state === BluetoothAdapterState.Enabling ? "Включение Bluetooth…"
        : adapter.state === BluetoothAdapterState.Disabling ? "Выключение Bluetooth…" : ""
    function deviceBusy(device): bool {
        return device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting
    }
    readonly property var adapters: Bluetooth.adapters
}
