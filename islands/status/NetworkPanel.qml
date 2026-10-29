pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Networking as QsNet
import "../../services/system"
import "../../surfaces/settings"
import "NetworkEntries.js" as Entries

FocusScope {
    id: root
    objectName: "network-panel"
    required property var tokens
    property bool active: false
    property real maxBodyHeight: 460
    property var control: nativeControl
    property alias wireguardControl: wireguard
    property int page: 0 // 0: summary, 1: remaining Wi-Fi, 2: password
    property bool keyboardTransition: false
    property var pending: null
    property string error: ""
    readonly property var deviceList: Entries.values(control.devices)
    readonly property var wiredDevices: deviceList.filter(device => device.type === QsNet.DeviceType.Wired)
    readonly property var wifiDevices: deviceList.filter(device => device.type === QsNet.DeviceType.Wifi)
    readonly property var wifiNetworks: Entries.ranked(control.devices, QsNet.DeviceType.Wifi)
    readonly property var nearestNetworks: wifiNetworks.slice(0, 3)
    readonly property var otherNetworks: wifiNetworks.slice(3)
    readonly property bool motionRunning: slideMotion.running
    property real slide: page === 0 ? 0 : 1
    readonly property real bodyHeight: Math.min(maxBodyHeight, Math.max(180, summary.implicitHeight))
    readonly property string statusText: !control.managerPresent ? "NetworkManager недоступен"
        : control.connectivity === QsNet.NetworkConnectivity.Full ? "Доступ в интернет есть"
        : control.connectivity === QsNet.NetworkConnectivity.Portal ? "Нужна авторизация в сети"
        : control.connectivity === QsNet.NetworkConnectivity.Limited ? "Подключение ограничено" : "Нет доступа в интернет"
    signal closeRequested(bool keyboard)
    signal settingsRequested()

    implicitWidth: 328
    implicitHeight: header.height + 12 + bodyHeight
    NetworkControl { id: nativeControl; scanning: root.active && root.control === nativeControl }
    WireGuardControl { id: wireguard; watching: root.active }

    Behavior on slide {
        enabled: !root.tokens.motion.off && !root.keyboardTransition && root.active
        NumberAnimation {
            id: slideMotion
            duration: root.tokens.motion.base
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.tokens.motion.easeOut
        }
    }

    function navigate(nextPage, keyboard) {
        keyboardTransition = !!keyboard
        if (nextPage !== 2) {
            pending = null
            password.clear()
        }
        page = nextPage
        Qt.callLater(function() {
            if (nextPage === 2) password.forceActiveFocus()
            else if (nextPage === 1) backButton.forceActiveFocus()
            else if (moreButton.visible) moreButton.forceActiveFocus()
            else wifiSwitch.forceActiveFocus()
        })
    }
    function dismissDetail(keyboard) {
        if (page === 2 && otherNetworks.indexOf(pending) >= 0)
            navigate(1, keyboard)
        else
            navigate(0, keyboard)
    }
    function useNetwork(entry, keyboard) {
        error = ""
        if (!entry || entry.stateChanging) return
        if (entry.connected) {
            control.disconnectEntry(entry)
        } else if (control.needsPsk(entry)) {
            if (!control.pskSupported(entry)) {
                error = "Для этой сети нужен профиль администратора. Откройте настройки сети"
                return
            }
            pending = entry
            password.clear()
            navigate(2, keyboard)
        } else {
            control.connectEntry(entry)
        }
    }
    function submitPassword() {
        if (!pending || password.text.length === 0) return
        const entry = pending
        const secret = password.text
        password.clear()
        navigate(0, true)
        control.connectWithPsk(entry, secret)
    }
    function reset() {
        keyboardTransition = true
        page = 0
        pending = null
        password.clear()
        error = ""
        mainScroll.contentY = 0
        otherScroll.contentY = 0
    }
    onActiveChanged: if (!active) reset()
    onWifiNetworksChanged: {
        if (pending && wifiNetworks.indexOf(pending) < 0) {
            navigate(0, true)
            error = "Сеть больше недоступна. Выберите другую сеть"
        }
    }
    Connections {
        target: root.control
        function onWifiEnabledChanged() { if (!root.control.wifiEnabled) root.navigate(0, true) }
    }
    Instantiator {
        model: root.wifiNetworks
        delegate: QtObject {
            id: watchedNetwork
            required property var modelData
            property Connections failure: Connections {
                target: watchedNetwork.modelData
                function onConnectionFailed(reason) {
                    root.error = reason === QsNet.ConnectionFailReason.NoSecrets ? "Не удалось подключиться. Проверьте пароль сети"
                        : reason === QsNet.ConnectionFailReason.WifiNetworkLost ? "Сеть Wi-Fi пропала. Выберите другую сеть"
                        : "Не удалось подключиться к Wi-Fi. Проверьте пароль и повторите попытку"
                }
            }
        }
    }
    Keys.onEscapePressed: event => {
        if (root.page !== 0) root.dismissDetail(true)
        else root.closeRequested(true)
        event.accepted = true
    }

    component Caption: Text {
        color: root.tokens.color.textMuted
        font { family: root.tokens.type.body.family; pixelSize: 12 }
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
    }
    component Rule: Rectangle {
        width: parent.width
        height: 1
        color: Qt.alpha(root.tokens.color.text, 0.13)
    }
    component IconButton: AbstractButton {
        id: button
        property string glyph: "settings"
        implicitWidth: 32; implicitHeight: 32
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        Accessible.name: text
        background: Rectangle {
            radius: root.tokens.radius.small
            color: button.hovered || button.down ? Qt.alpha(root.tokens.color.accent, 0.12) : "transparent"
            border.width: button.visualFocus ? 1 : 0
            border.color: root.tokens.color.accent
        }
        contentItem: Item {
            NetworkGlyph { anchors.centerIn: parent; name: button.glyph; ink: root.tokens.color.text; width: 20; height: 20 }
        }
    }
    component WifiRow: NetworkRow {
        id: row
        required property var modelData
        tokens: root.tokens
        width: parent.width
        glyph: "wifi"
        text: modelData.name
        detail: modelData.stateChanging ? (modelData.state === QsNet.ConnectionState.Disconnecting ? "Отключение…" : "Подключение…")
            : modelData.connected ? "Подключено" : ""
        selected: modelData.connected
        strength: modelData.signalStrength
        secured: modelData.security !== QsNet.WifiSecurityType.Open && modelData.security !== QsNet.WifiSecurityType.Owe
        enabled: root.control.wifiEnabled && !modelData.stateChanging
        onInvoked: keyboard => root.useNetwork(row.modelData, keyboard)
    }

    Row {
        id: header
        width: parent.width
        height: 40
        spacing: 4
        IconButton {
            id: backButton
            objectName: "network-back"
            visible: root.page !== 0
            glyph: "back"; text: "Назад"
            onClicked: root.dismissDetail(false)
            Keys.onReturnPressed: root.dismissDetail(true)
            Keys.onSpacePressed: root.dismissDetail(true)
        }
        Text {
            width: parent.width - (backButton.visible ? 36 : 0) - 72
            height: 40
            text: root.page === 1 ? "Другие сети" : root.page === 2 ? "Подключение" : "Сеть"
            color: root.tokens.color.text
            font { family: root.tokens.type.display.family; pixelSize: root.page ? 23 : 28; weight: 500 }
            textFormat: Text.PlainText
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        IconButton { objectName: "network-settings"; text: "Настройки сети"; onClicked: root.settingsRequested() }
        IconButton {
            objectName: "network-close"
            glyph: "close"; text: "Закрыть"
            onClicked: root.closeRequested(false)
            Keys.onReturnPressed: root.closeRequested(true)
            Keys.onSpacePressed: root.closeRequested(true)
        }
    }
    Item {
        id: viewport
        y: header.height + 12
        width: parent.width
        height: root.bodyHeight
        clip: true
        Flickable {
            id: mainScroll
            objectName: "network-summary-scroll"
            width: parent.width; height: parent.height
            contentHeight: summary.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: root.page === 0
            enabled: root.page === 0
            visible: root.slide < 1
            transform: Translate { x: -root.slide * viewport.width }
            opacity: 1 - root.slide * 0.25
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            Column {
                id: summary
                width: parent.width
                spacing: 8
                Caption { width: parent.width; text: root.statusText }
                Repeater {
                    model: root.wiredDevices
                    delegate: NetworkRow {
                        required property var modelData
                        tokens: root.tokens
                        objectName: "network-ethernet"
                        width: parent.width
                        glyph: "ethernet"
                        text: "Ethernet"
                        detail: !modelData.hasLink ? "Кабель не подключён" : modelData.connected
                            ? "Подключено" + (modelData.linkSpeed ? " · " + Entries.speed(modelData.linkSpeed) : "")
                            : "Кабель подключён · Нет соединения"
                        selected: modelData.connected
                        actionable: false
                        Accessible.description: modelData.name + (modelData.address ? " · " + modelData.address : "")
                        actionText: modelData.network && modelData.network.stateChanging ? "Ожидание…" : ""
                    }
                }
                Caption {
                    visible: root.wiredDevices.length === 0
                    width: parent.width
                    text: "Ethernet · Адаптер не найден"
                }
                Rule {}
                SettingsSwitch {
                    id: wifiSwitch
                    objectName: "network-wifi-switch"
                    tokens: root.tokens
                    width: parent.width
                    text: "Wi-Fi"
                    description: !root.control.wifiHardwareEnabled ? "Аппаратный выключатель выключен"
                        : root.wifiDevices.length === 0 ? "Адаптер не найден"
                        : root.control.wifiEnabled ? "" : "Выключен"
                    checked: root.control.wifiEnabled
                    enabled: root.control.managerPresent && root.control.wifiHardwareEnabled && root.wifiDevices.length > 0
                    onClicked: {
                        root.control.setWifiEnabled(!root.control.wifiEnabled)
                        checked = Qt.binding(() => root.control.wifiEnabled)
                    }
                }
                Column {
                    visible: root.control.wifiEnabled && root.control.managerPresent
                    width: parent.width
                    spacing: 2
                    Repeater { model: root.nearestNetworks; delegate: WifiRow { objectName: "network-nearest-row" } }
                    Caption { visible: root.wifiNetworks.length === 0; width: parent.width; text: "Поиск сетей…" }
                    NetworkRow {
                        id: moreButton
                        objectName: "network-more"
                        tokens: root.tokens
                        width: parent.width
                        visible: root.otherNetworks.length > 0
                        text: "Другие сети"
                        actionText: root.otherNetworks.length + "  ›"
                        onInvoked: keyboard => root.navigate(1, keyboard)
                    }
                }
                Rule {}
                Column {
                    objectName: "wireguard-controls"
                    property alias control: wireguard
                    width: parent.width
                    spacing: 4
                    Text {
                        text: "WireGuard"
                        color: root.tokens.color.text
                        font { family: root.tokens.type.display.family; pixelSize: 18; weight: 500 }
                    }
                    Caption { visible: !wireguard.ready || wireguard.profiles.length === 0; width: parent.width; text: !wireguard.ready ? "Загрузка подключений…" : "Нет сохранённых подключений" }
                    Repeater {
                        model: wireguard.profiles
                        delegate: NetworkRow {
                            required property var modelData
                            readonly property bool pending: wireguard.operationUuid === modelData.uuid
                            tokens: root.tokens
                            width: parent.width
                            glyph: "shield"
                            text: modelData.name
                            detail: pending ? (wireguard.operation === "up" ? "Подключение…" : "Отключение…")
                                : modelData.state === "activating" ? "Подключение…" : modelData.state === "deactivating" ? "Отключение…"
                                : modelData.active ? (modelData.device ? modelData.device + " · " : "") + "Подключено" : "Не подключено"
                            selected: modelData.active
                            actionText: modelData.active ? "Отключить" : "Подключить"
                            enabled: wireguard.available && !wireguard.busy && modelData.state !== "activating" && modelData.state !== "deactivating"
                            onInvoked: wireguard.toggle(modelData)
                        }
                    }
                    Caption { width: parent.width; visible: wireguard.error !== ""; text: wireguard.error; color: root.tokens.color.secondary; Accessible.role: Accessible.AlertMessage }
                    NetworkRow { visible: wireguard.error !== ""; tokens: root.tokens; width: parent.width; text: "Обновить список"; enabled: !wireguard.busy; onInvoked: wireguard.refresh(true) }
                }
                Caption { width: parent.width; visible: root.error !== ""; text: root.error; color: root.tokens.color.secondary; Accessible.role: Accessible.AlertMessage }
            }
        }
        Item {
            width: parent.width; height: parent.height
            visible: root.slide > 0
            enabled: root.page !== 0
            transform: Translate { x: (1 - root.slide) * viewport.width }
            opacity: 0.75 + root.slide * 0.25
            Flickable {
                id: otherScroll
                objectName: "network-other-scroll"
                anchors.fill: parent
                visible: root.page !== 2
                contentHeight: remaining.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                Column {
                    id: remaining
                    width: parent.width
                    spacing: 4
                    Caption { width: parent.width; text: "По уровню сигнала" }
                    Repeater { model: root.otherNetworks; delegate: WifiRow { objectName: "network-other-row" } }
                    Caption { visible: root.otherNetworks.length === 0; width: parent.width; text: "Других сетей нет" }
                    Caption { width: parent.width; visible: root.error !== ""; text: root.error; color: root.tokens.color.secondary }
                }
            }
            Column {
                visible: root.page === 2
                width: parent.width
                spacing: 12
                Caption { width: parent.width; text: root.pending ? root.pending.name : ""; font.pixelSize: 14; color: root.tokens.color.text }
                Caption { width: parent.width; text: "Введите пароль сети" }
                SettingsField {
                    id: password
                    objectName: "network-password"
                    tokens: root.tokens
                    width: parent.width
                    echoMode: TextInput.Password
                    placeholderText: "Пароль сети"
                    Accessible.name: "Пароль сети"
                    onAccepted: root.submitPassword()
                }
                NetworkRow {
                    tokens: root.tokens
                    width: parent.width
                    text: "Подключить"
                    selected: true
                    enabled: password.text.length > 0
                    onInvoked: root.submitPassword()
                }
            }
        }
    }
}
