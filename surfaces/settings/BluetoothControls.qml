pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../../islands/status"

Column {
    id: root
    required property var tokens
    required property var bluetooth
    property bool showPowerToggle: true
    property bool active: visible
    property string forgetPath: ""
    spacing: 10
    onActiveChanged: if (!active && bluetooth) { bluetooth.stopDiscovery(); forgetPath = "" }
    Component.onDestruction: if (bluetooth) bluetooth.stopDiscovery()

    component Label: SettingsLabel { tokens: root.tokens; width: parent.width }
    component Action: SettingsAction { tokens: root.tokens; width: parent.width }

    Label {
        visible: !root.bluetooth || !root.bluetooth.powered || root.bluetooth.unavailableReason !== "" || (!!root.bluetooth.backend && root.bluetooth.backend.adapterStatus !== "")
        text: root.bluetooth ? root.bluetooth.statusText : "Bluetooth недоступен"
        color: root.tokens.color.textMuted
    }
    SettingsSwitch {
        visible: root.showPowerToggle
        tokens: root.tokens
        text: "Bluetooth"
        checked: !!root.bluetooth && root.bluetooth.powered
        enabled: !!root.bluetooth && !!root.bluetooth.adapter && !root.bluetooth.busy && root.bluetooth.bridgeReady
        onClicked: { root.bluetooth.setPowered(!root.bluetooth.powered); checked = Qt.binding(() => root.bluetooth.powered) }
    }
    Label {
        visible: !!root.bluetooth && !root.bluetooth.powered && !!root.bluetooth.adapter
        text: "Включите Bluetooth, чтобы подключать и искать устройства"
    }
    Label {
        visible: !!root.bluetooth && root.bluetooth.error !== ""
        text: root.bluetooth ? root.bluetooth.error : ""
        color: root.tokens.color.secondary
    }
    Label {
        visible: !!root.bluetooth && root.bluetooth.busy
        text: root.bluetooth && root.bluetooth.operation === "pair" ? "Сопряжение…" : "Выполняется операция…"
    }
    Column {
        width: parent.width
        spacing: 8
        visible: !!root.bluetooth && !!root.bluetooth.agentRequest
        readonly property var request: root.bluetooth ? root.bluetooth.agentRequest : null
        Label {
            text: {
                const r = root.bluetooth ? root.bluetooth.agentRequest : null
                if (!r) return ""
                if (r.method === "RequestPinCode") return "Введите PIN устройства"
                if (r.method === "RequestPasskey") return "Введите шестизначный код устройства"
                if (r.method === "DisplayPinCode" || r.method === "DisplayPasskey") return "Введите на устройстве код: " + r.code
                if (r.method === "RequestConfirmation") return "Код на устройстве совпадает? " + r.code
                return "Разрешить сопряжение с устройством?"
            }
        }
        SettingsField {
            id: pin
            tokens: root.tokens
            width: parent.width
            visible: !!root.bluetooth && !!root.bluetooth.agentRequest && ["RequestPinCode", "RequestPasskey"].indexOf(root.bluetooth.agentRequest.method) >= 0
            maximumLength: root.bluetooth && root.bluetooth.agentRequest && root.bluetooth.agentRequest.method === "RequestPasskey" ? 6 : 16
            onVisibleChanged: text = ""
        }
        Action {
            text: "Подтвердить"
            visible: !!root.bluetooth && !!root.bluetooth.agentRequest && !root.bluetooth.agentRequest.method.startsWith("Display")
            enabled: !pin.visible || (root.bluetooth.agentRequest.method === "RequestPasskey" ? /^\d{1,6}$/.test(pin.text) : pin.text.length > 0)
            onClicked: root.bluetooth.answerAgent(true, pin.text)
        }
        Action {
            text: "Отклонить"
            visible: !!root.bluetooth && !!root.bluetooth.agentRequest && !root.bluetooth.agentRequest.method.startsWith("Display")
            onClicked: root.bluetooth.answerAgent(false, "")
        }
    }
    Repeater {
        model: ["Подключённые", "Сопряжённые", "Устройства поблизости"]
        delegate: Column {
            id: group
            required property string modelData
            required property int index
            width: parent.width
            spacing: 8
            readonly property var members: root.bluetooth ? root.bluetooth.deviceList.filter(device => {
                const saved = device.paired || device.bonded
                return group.index === 0 ? device.connected : group.index === 1 ? saved && !device.connected : !saved && !device.connected
            }) : []
            visible: !!root.bluetooth && root.bluetooth.powered && members.length > 0
            Label { text: group.modelData; color: root.tokens.color.textMuted; font.pixelSize: 14; font.weight: Font.Medium }
            Repeater {
                model: group.members
                delegate: Column {
                    id: row
                    required property var modelData
                    readonly property bool saved: modelData.paired || modelData.bonded
                    readonly property bool working: root.bluetooth.deviceBusy(modelData)
                    readonly property string path: modelData.dbusPath
                    width: parent.width
                    spacing: 6
                    Row {
                        width: parent.width
                        spacing: 8
                        SettingsNavGlyph {
                            width: 24; height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            ink: root.tokens.color.textMuted
                            name: {
                                const icon = row.modelData.icon || ""
                                if (/audio|headset|headphone/.test(icon)) return "sound"
                                if (/keyboard/.test(icon)) return "keyboard"
                                if (/mouse/.test(icon)) return "mouse"
                                if (/phone|tablet/.test(icon)) return "phone"
                                if (/computer/.test(icon)) return "display"
                                return "bluetooth"
                            }
                        }
                        SettingsLabel {
                            tokens: root.tokens
                            width: parent.width - 112
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.name || row.modelData.deviceName || row.modelData.address || "Устройство"
                        }
                        StatusButton {
                            tokens: root.tokens
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: row.modelData.connected ? "device-disconnect" : "device-connect"
                            hint: row.modelData.connected ? "Отключить" : row.saved ? "Подключить" : "Сопрячь"
                            enabled: !row.working && root.bluetooth.bridgeReady
                            onClicked: root.bluetooth.act(row.modelData, row.modelData.connected ? "disconnect" : row.saved ? "connect" : "pair")
                        }
                        StatusButton {
                            tokens: root.tokens
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "device-forget"
                            hint: "Удалить сопряжение"
                            visible: row.saved
                            enabled: !row.working && root.bluetooth.bridgeReady
                            onClicked: root.forgetPath = row.path
                        }
                    }
                    Label {
                        color: root.tokens.color.textMuted
                        font.pixelSize: 12
                        text: (row.modelData.pairing ? "Сопряжение…" : row.working && root.bluetooth.operationPath === row.path ? "Выполняется…" : row.modelData.connected ? "Подключено" : row.saved ? "Сопряжено" : "Не сопряжено")
                            + (root.bluetooth.batteryText(row.modelData) ? " · " + root.bluetooth.batteryText(row.modelData) : "")
                    }
                    Label {
                        visible: root.forgetPath === row.path
                        text: "Удалить сопряжение с «" + (row.modelData.name || row.modelData.address) + "»? Для подключения потребуется новое сопряжение."
                    }
                    Action {
                        visible: root.forgetPath === row.path
                        enabled: !row.working
                        text: "Да, удалить сопряжение"
                        onClicked: { root.bluetooth.act(row.modelData, "forget"); root.forgetPath = "" }
                    }
                    Action {
                        visible: root.forgetPath === row.path
                        text: "Отмена"
                        onClicked: root.forgetPath = ""
                    }
                }
            }
        }
    }
    Action {
        visible: !!root.bluetooth && root.bluetooth.powered
        enabled: !!root.bluetooth && !root.bluetooth.busy && root.bluetooth.bridgeReady
        text: root.bluetooth && root.bluetooth.scanOwned ? "Остановить поиск" : "Найти устройства"
        onClicked: root.bluetooth.setDiscovering(!root.bluetooth.scanOwned)
    }
    Label {
        visible: !!root.bluetooth && root.bluetooth.powered && root.bluetooth.discovering
        text: "● Идёт поиск устройств…"
        color: root.tokens.color.accent
    }
    Label {
        visible: !!root.bluetooth && root.bluetooth.powered && root.bluetooth.deviceList.length === 0
        text: "Устройств пока нет. Нажмите «Найти устройства»"
    }
}
