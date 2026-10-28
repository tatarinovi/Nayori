pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: root
    required property var tokens
    property var bluetoothService: null
    property var settingsService: null
    spacing: 16

    SettingsToggle {
        tokens: root.tokens
        text: "Показывать Bluetooth в системном трее"
        checked: root.settingsService ? root.settingsService.bluetoothIconVisible : true
        enabled: !!root.settingsService && root.settingsService.ready
        onClicked: {
            root.settingsService.update({bluetoothIconVisible: !root.settingsService.bluetoothIconVisible})
            checked = Qt.binding(() => root.settingsService.bluetoothIconVisible)
        }
    }
    BluetoothControls {
        width: parent.width
        tokens: root.tokens
        bluetooth: root.bluetoothService
    }
}
