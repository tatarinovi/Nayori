pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth

// Загружается только через BluetoothService, если модуль существует.
QtObject {
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices : null
    readonly property var adapters: Bluetooth.adapters
}
