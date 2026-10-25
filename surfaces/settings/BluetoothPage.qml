pragma ComponentBehavior: Bound

import QtQuick
import "../../services/system"

Column {
    id: root
    required property var tokens
    spacing: 16
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    function percentText(value) {
        if (typeof value !== "number" || !isFinite(value) || value < 0)
            return ""
        const pct = value <= 1 ? Math.round(value * 100) : Math.round(value)
        return pct + "%"
    }

    BluetoothService { id: bluetooth }

    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: bluetooth.loadFinished && bluetooth.unavailableReason !== ""
        text: bluetooth.unavailableReason
    
    }
    Label {
        visible: bluetooth.adapter !== null
        width: parent.width
        text: bluetooth.adapterName || "Адаптер"
        font.family: root.tokens.type.display.family
        font.pixelSize: 18
    }
    SettingsToggle {
        visible: bluetooth.adapter !== null
        tokens: root.tokens
        text: "Bluetooth"
        checked: bluetooth.powered
        onClicked: bluetooth.setPowered(checked)
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: bluetooth.adapter !== null && !bluetooth.powered
        text: "Сначала включите Bluetooth, затем можно искать устройства"
    
    }
    Action {
        visible: bluetooth.adapter !== null && bluetooth.powered && !bluetooth.discovering
        text: "Найти устройства"
        onClicked: bluetooth.setDiscovering(true)
    }
    Action {
        visible: bluetooth.adapter !== null && bluetooth.discovering
        text: "Остановить поиск"
        onClicked: bluetooth.setDiscovering(false)
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: bluetooth.adapter !== null && bluetooth.powered
        text: bluetooth.discovering ? "Идёт поиск устройств" : "Поиск выключен"
    
    }
    Repeater {
        model: bluetooth.devices
        delegate: Column {
            id: deviceRow
            required property var modelData
            width: parent.width
            spacing: 6
            Label { width: parent.width; text: modelData.name || modelData.deviceName || modelData.address || "Устройство" }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                text: (modelData.connected ? "Подключено" : modelData.paired ? "Сопряжено" : "Не сопряжено")
                      + (modelData.batteryAvailable ? " · батарея " + root.percentText(modelData.battery) : "")
            
            }
            Action {
                visible: modelData.connected
                text: "Отключить"
                onClicked: deviceRow.modelData.disconnect()
            }
            Action {
                visible: !modelData.connected && modelData.paired
                text: "Подключить"
                onClicked: deviceRow.modelData.connect()
            }
            Action {
                visible: !modelData.connected && !modelData.paired
                text: "Сопрячь"
                onClicked: deviceRow.modelData.pair()
            }
        }
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: bluetooth.adapter !== null && bluetooth.powered && bluetooth.devices && bluetooth.devices.count === 0
        text: "Устройств пока нет. Нажмите «Найти устройства», чтобы увидеть находящиеся рядом"
    
    }
}
