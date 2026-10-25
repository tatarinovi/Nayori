pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../../services/status"
import "../../services/system"

Column {
    id: root
    required property var tokens
    property string userName: ""
    property string avatarSource: ""
    signal panelsRequested()
    signal networkRequested()
    signal bluetoothRequested()
    signal updatesRequested()

    spacing: 24
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    function networkText() {
        if (!network.available)
            return "NetworkManager недоступен"
        if (network.label === "wifi")
            return "Подключено по Wi\u2011Fi"
        if (network.label === "lan")
            return "Подключено по Ethernet"
        if (network.label === "portal")
            return "Нужна авторизация в сети"
        if (network.label === "limited")
            return "Подключение ограничено"
        if (network.label === "link" || network.linked)
            return "Есть подключение"
        return "Нет подключения"
    }

    Network { id: network }
    Audio { id: audio }
    BluetoothService { id: bluetooth }
    SystemInfo { id: info }

    Item {
        width: parent.width
        height: 72
        Rectangle {
            id: avatar
            width: 72
            height: 72
            radius: root.tokens.radius.small
            color: root.tokens.color.surfaceAlt
            Label {
                anchors.centerIn: parent
                visible: portrait.status !== Image.Ready
                text: (root.userName.trim().charAt(0) || "N").toUpperCase()
                color: root.tokens.color.accent
                font.family: root.tokens.type.display.family
                font.pixelSize: 30
            }
            Image {
                id: portrait
                anchors { fill: parent; margins: 4 }
                source: root.avatarSource
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                sourceSize: Qt.size(128, 128)
            }
        }
        Column {
            anchors { left: avatar.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 5
            Label { width: parent.width; text: root.userName || "Nayori"; font.pixelSize: 22; elide: Text.ElideRight; wrapMode: Text.NoWrap }
            Label { text: "NayoriOS"; color: root.tokens.color.textMuted; font.pixelSize: 13 }
        }
    }

    Column {
        width: parent.width
        spacing: 8
        Label { text: "Сеть"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
        Label {
            width: parent.width
            color: root.tokens.color.textMuted
            font.pixelSize: 13
             text: root.networkText() 
        }
        Action { text: "Открыть сеть"; onClicked: root.networkRequested() }
    }

    Column {
        width: parent.width
        spacing: 8
        Label { text: "Bluetooth"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
        SettingsToggle {
            visible: bluetooth.adapter !== null
            tokens: root.tokens
            text: "Bluetooth"
            description: bluetooth.adapterName
            checked: bluetooth.powered
            onClicked: bluetooth.setPowered(checked)
        }
        Label {
            width: parent.width
            color: root.tokens.color.secondary
            font.pixelSize: 13
            visible: bluetooth.loadFinished && bluetooth.adapter === null
            text: bluetooth.unavailableReason
        
        }
        Action { text: "Открыть устройства"; onClicked: root.bluetoothRequested() }
    }

    Column {
        width: parent.width
        spacing: 8
        Label { text: "Звук"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
        Label {
            width: parent.width
            color: root.tokens.color.secondary
            font.pixelSize: 13
            visible: !audio.available
            text: "Звук недоступен. PipeWire не передал устройство вывода"
        
        }
        SettingsSlider {
            width: parent.width
            tokens: root.tokens
            enabled: audio.available
            source: audio.level
            label: "Громкость"
            onChanged: value => audio.setVolume(value)
        }
        SettingsToggle {
            enabled: audio.available
            tokens: root.tokens
            text: "Без звука"
            checked: audio.muted
            onClicked: {
                if (audio.available && audio.muted !== checked)
                    audio.toggleMuted()
            }
        }
    }

    Column {
        width: parent.width
        spacing: 8
        Label { text: "Nayori"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
        Label {
            width: parent.width
            color: root.tokens.color.textMuted
            font.pixelSize: 13
             text: info.summary 
        }
        Action { text: "Открыть обновления"; selected: true; onClicked: root.updatesRequested() }
        Action { text: "Настроить панели"; onClicked: root.panelsRequested() }
    }
}
