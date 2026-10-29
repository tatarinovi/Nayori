pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Networking as QsNet
import "../../services/system"

Column {
    id: root
    required property var tokens
    property bool scanning: false
    property var pending: null
    property string error: ""
    spacing: 16

    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    function kindText(device) {
        if (!device)
            return "Устройство"
        if (device.type === QsNet.DeviceType.Wifi)
            return "Wi\u2011Fi"
        if (device.type === QsNet.DeviceType.Wired)
            return "Ethernet"
        return "Сеть"
    }

    function failText(reason) {
        if (reason === QsNet.ConnectionFailReason.NoSecrets)
            return "Не удалось подключиться. Нужен пароль сети"
        if (reason === QsNet.ConnectionFailReason.WifiAuthTimeout)
            return "Не удалось подключиться. Точка доступа не ответила"
        if (reason === QsNet.ConnectionFailReason.WifiClientFailed)
            return "Не удалось подключиться к Wi\u2011Fi"
        if (reason === QsNet.ConnectionFailReason.WifiClientDisconnected)
            return "Соединение Wi\u2011Fi разорвано"
        if (reason === QsNet.ConnectionFailReason.WifiNetworkLost)
            return "Сеть Wi\u2011Fi пропала"
        return "Не удалось подключиться"
    }

    function connectivityText() {
        if (!control.managerPresent)
            return "NetworkManager недоступен"
        if (control.connectivity === QsNet.NetworkConnectivity.Full)
            return "Доступ в интернет есть"
        if (control.connectivity === QsNet.NetworkConnectivity.Portal)
            return "Нужна авторизация в сети"
        if (control.connectivity === QsNet.NetworkConnectivity.Limited)
            return "Подключение ограничено"
        if (control.connectivity === QsNet.NetworkConnectivity.None)
            return "Нет доступа в интернет"
        return "Состояние сети неизвестно"
    }

    function useEntry(entry) {
        error = ""
        if (!entry)
            return
        if (entry.connected) {
            control.disconnectEntry(entry)
            pending = null
            passwordField.text = ""
            return
        }
        if (control.needsPsk(entry)) {
            if (!control.pskSupported(entry)) {
                error = "Для этой сети нужен профиль администратора. Nayori его не создаёт"
                pending = null
                return
            }
            pending = entry
            passwordField.text = ""
            Qt.callLater(function() { passwordField.forceActiveFocus() })
            return
        }
        pending = null
        passwordField.text = ""
        control.connectEntry(entry)
    }

    function submitPassword() {
        const entry = pending
        const secret = passwordField.text
        passwordField.text = ""
        pending = null
        if (!entry || secret.length === 0) {
            error = "Введите пароль сети"
            return
        }
        control.connectWithPsk(entry, secret)
    }

    NetworkControl {
        id: control
        scanning: root.scanning
    }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: root.connectivityText() 
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: control.managerPresent && !control.wifiHardwareEnabled
        text: "Аппаратный выключатель Wi\u2011Fi выключен. Включить Wi\u2011Fi отсюда нельзя"
    
    }
    SettingsToggle {
        visible: control.managerPresent && control.wifiHardwareEnabled
        tokens: root.tokens
        text: "Wi\u2011Fi"
        checked: control.wifiEnabled
        onClicked: control.setWifiEnabled(checked)
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: !control.managerPresent
        text: "Без NetworkManager список сетей и подключение недоступны"
    
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: root.error !== ""
        text: root.error
    }

    WireGuardControls {
        width: parent.width
        tokens: root.tokens
        watching: root.scanning
    }

    Repeater {
        model: control.managerPresent ? control.devices : null
        delegate: Column {
            id: deviceSection
            required property var modelData
            width: parent.width
            spacing: 8
            Label {
                width: parent.width
                text: root.kindText(deviceSection.modelData) + " · " + (deviceSection.modelData.name || "без имени")
                font.family: root.tokens.type.display.family
                font.pixelSize: 18
            }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                visible: deviceSection.modelData.address !== ""
                text: deviceSection.modelData.connected
                      ? "Подключено · " + deviceSection.modelData.address
                      : deviceSection.modelData.address
            
            }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                visible: deviceSection.modelData.type === QsNet.DeviceType.Wired
                text: deviceSection.modelData.type !== QsNet.DeviceType.Wired ? ""
                      : deviceSection.modelData.hasLink
                        ? "Кабель подключён" + (deviceSection.modelData.linkSpeed ? " · " + deviceSection.modelData.linkSpeed + "\u00A0Мбит/с" : "")
                        : "Кабель не подключён"
            
            }
            SettingsToggle {
                tokens: root.tokens
                text: "Автоподключение"
                checked: deviceSection.modelData.autoconnect
                onClicked: control.setAutoconnect(deviceSection.modelData, checked)
            }
            Repeater {
                model: deviceSection.modelData.networks
                delegate: Column {
                    id: networkRow
                    required property var modelData
                    width: parent.width
                    spacing: 4
                    Action {
                        width: parent.width
                        enabled: !networkRow.modelData.stateChanging
                        selected: networkRow.modelData.connected
                        text: (networkRow.modelData.name || "Сеть")
                              + (networkRow.modelData.stateChanging ? " · подключение" : networkRow.modelData.connected ? " · подключено" : "")
                        onClicked: root.useEntry(networkRow.modelData)
                    }
                    Connections {
                        target: networkRow.modelData
                        function onConnectionFailed(reason) {
                            root.error = root.failText(reason)
                        }
                    }
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 8
        visible: root.pending !== null
        Label { width: parent.width; text: root.pending ? "Пароль для " + root.pending.name : "Пароль сети" }
        SettingsField {
            id: passwordField
            tokens: root.tokens
            echoMode: TextInput.Password
            placeholderText: "Пароль сети"
            Accessible.name: "Пароль сети"
            onAccepted: root.submitPassword()
        }
        Action { text: "Подключить"; selected: true; enabled: passwordField.text.length > 0; onClicked: root.submitPassword() }
        Action {
            text: "Отмена"
            onClicked: {
                root.pending = null
                passwordField.text = ""
            }
        }
    }
}
