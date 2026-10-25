pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Networking as QsNet
import Quickshell
import Quickshell.Services.Pipewire as QsPw
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../services/status"
import "../shared"

// Содержимое правого острова. Окна слоя здесь нет.
// Общая геометрия панели: строка 32 и отступ 8.
Rectangle {
    id: root

    required property var tokens
    property var menuWindow: null

    readonly property int pad: tokens.spacing.small

    implicitWidth: cluster.implicitWidth + pad * 2
    implicitHeight: 32 + pad * 2
    width: implicitWidth
    height: implicitHeight
    radius: tokens.radius.small + pad
    color: tokens.color.surfaceAlt
    border.width: 1
    border.color: tokens.color.border
    antialiasing: true

    Audio {
        id: audio
    }

    Network {
        id: network
        scanning: root.opened === "network"
    }

    Tray {
        id: tray
    }

    property string opened: ""
    property var trayMenuStack: []
    property var selectedNetwork: null
    property string networkError: ""
    onOpenedChanged: {
        clearTrayMenus()
        selectedNetwork = null
        networkError = ""
        passwordField.clear()
    }
    Component {
        id: trayMenuFactory
        QsMenuOpener {}
    }
    readonly property var currentTrayMenu: trayMenuStack.length
            ? trayMenuStack[trayMenuStack.length - 1] : null

    function pushTrayMenu(handle) {
        if (!handle)
            return
        const opener = trayMenuFactory.createObject(root, { menu: handle })
        if (opener)
            trayMenuStack = trayMenuStack.concat([opener])
    }

    function popTrayMenu() {
        if (!trayMenuStack.length)
            return
        const opener = trayMenuStack[trayMenuStack.length - 1]
        trayMenuStack = trayMenuStack.slice(0, -1)
        opener.menu = null
        opener.destroy()
    }

    function clearTrayMenus() {
        while (trayMenuStack.length)
            popTrayMenu()
    }

    Component.onDestruction: clearTrayMenus()

    function connectNetwork(entry) {
        networkError = ""
        if (entry.connected) {
            entry.disconnect()
        } else if (!entry.known && entry.security !== undefined
                   && entry.security !== QsNet.WifiSecurityType.Open
                   && entry.security !== QsNet.WifiSecurityType.Owe) {
            if (entry.security !== QsNet.WifiSecurityType.WpaPsk
                    && entry.security !== QsNet.WifiSecurityType.Wpa2Psk
                    && entry.security !== QsNet.WifiSecurityType.Sae) {
                networkError = "This network requires an administrator connection profile."
                return
            }
            selectedNetwork = entry
            Qt.callLater(function() { passwordField.forceActiveFocus() })
        } else {
            entry.connect()
        }
    }

    function togglePopup(name) {
        opened = opened === name ? "" : name
    }

    function openTrayMenu(entry, anchor) {
        if (!entry || !entry.hasMenu)
            return
        clearTrayMenus()
        pushTrayMenu(entry.menu)

    }

    component StatusText: Text {
        property var role: root.tokens.type.body
        color: root.tokens.color.text
        font.family: role.family
        font.pixelSize: role.size
        font.weight: role.weight
        font.letterSpacing: role.letterSpacing
        lineHeight: role.lineHeight
        lineHeightMode: Text.ProportionalHeight
        renderType: Text.NativeRendering
        textFormat: Text.PlainText
    }

    Row {
        id: cluster
        anchors.centerIn: parent
        spacing: 4

        StatusButton {
            tokens: root.tokens
            visible: trayIcons.count > 0
            iconName: root.opened === "tray" ? "chevron-down" : "chevron-up"
            hint: "System tray (" + trayIcons.count + ")"
            checked: root.opened === "tray"
            onClicked: root.togglePopup("tray")
        }
        StatusButton {
            tokens: root.tokens
            iconName: network.linked ? (network.label === "wifi" ? "network-wireless-symbolic" : "network-wired-symbolic") : "network-offline-symbolic"
            hint: "Network: " + (network.available ? network.label : "unavailable")
            checked: root.opened === "network"
            onClicked: root.togglePopup("network")
        }
        StatusButton {
            tokens: root.tokens
            iconName: !audio.available || audio.muted ? "audio-volume-muted-symbolic"
                      : audio.level < 0.34 ? "audio-volume-low-symbolic"
                      : audio.level < 0.67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"
            hint: "Sound: " + (audio.available ? audio.label : "unavailable") + " · scroll to adjust"
            checked: root.opened === "audio"
            onClicked: root.togglePopup("audio")
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                onClicked: audio.toggleMuted()
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y !== 0) {
                        audio.setVolume(audio.level + wheel.angleDelta.y / 120 * 0.05)
                        wheel.accepted = true
                    }
                }
            }
        }

    }

    PopupWindow {
        id: popup
        visible: root.opened !== "" && root.menuWindow !== null
        anchor.item: root
        anchor.edges: Edges.Top | Edges.Right
        anchor.gravity: Edges.Top | Edges.Left
        anchor.margins.top: 8
        implicitWidth: 320
        implicitHeight: popupColumn.implicitHeight + 24
        color: "transparent"
        grabFocus: true
        onVisibleChanged: {
            if (!visible)
                root.opened = ""
            else
                Qt.callLater(function() { popupColumn.forceActiveFocus() })
        }

        Rectangle {
            anchors.fill: parent
            radius: root.tokens.radius.small + 12
            color: root.tokens.color.surfaceAlt
            border.width: 1
            border.color: root.tokens.color.border

            Column {
                id: popupColumn
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 8
                focus: true
                Keys.onEscapePressed: {
                    if (root.selectedNetwork) {
                        root.selectedNetwork = null
                        passwordField.clear()
                    } else if (root.trayMenuStack.length)
                        root.popTrayMenu()
                    else
                        root.opened = ""
                }

                Row {
                    width: parent.width
                    StatusText {
                        width: parent.width - 32
                        height: 32
                        verticalAlignment: Text.AlignVCenter
                        text: root.opened === "tray" ? "System tray" : root.opened === "audio" ? "Sound" : "Network"
                        font.family: root.tokens.type.display.family
                        font.pixelSize: root.tokens.type.display.size
                    }
                    StatusButton {
                        tokens: root.tokens
                        text: "×"
                        hint: "Close"
                        onClicked: root.opened = ""
                    }
                }
                Grid {
                    id: trayGrid
                    visible: root.opened === "tray" && !root.trayMenuStack.length
                    columns: 8
                    spacing: 4
                Repeater {
                    id: trayIcons
                    model: tray.available ? SystemTray.items : null

                    delegate: Item {
                        id: trayIcon

                        required property var modelData

                        readonly property string iconSource: modelData && modelData.icon ? String(modelData.icon) : ""
                        readonly property bool iconAvailable: {
                            if (iconSource.indexOf("image://icon/") !== 0)
                                return iconSource !== ""
                            const name = decodeURIComponent(iconSource.slice(13).split("?")[0])
                            return Quickshell.hasThemeIcon(name)
                        }
                        readonly property string iconName: {
                            var title = modelData ? (modelData.title || modelData.id || "") : ""
                            var text = String(title).trim()
                            return text.length > 0 ? text.charAt(0).toUpperCase() : ""
                        }
                        readonly property bool needsAttention: !!(modelData && modelData.status === Status.NeedsAttention)

                        width: 32
                        height: 32

                        activeFocusOnTab: true
                        Keys.onReturnPressed: {
                            if (modelData.onlyMenu)
                                root.openTrayMenu(modelData, trayIcon)
                            else
                                modelData.activate()
                        }
                        Keys.onSpacePressed: {
                            if (modelData.onlyMenu)
                                root.openTrayMenu(modelData, trayIcon)
                            else
                                modelData.activate()
                        }
                        Keys.onMenuPressed: root.openTrayMenu(modelData, trayIcon)
                        PanelTooltip {
                            tokens: root.tokens
                            target: trayIcon
                            hovered: trayMouse.containsMouse && !trayMouse.pressed
                            text: trayIcon.modelData ? String(trayIcon.modelData.tooltipTitle || trayIcon.modelData.title || trayIcon.modelData.id || "") : ""
                        }
                        Accessible.onPressAction: {
                            if (modelData.onlyMenu)
                                root.openTrayMenu(modelData, trayIcon)
                            else
                                modelData.activate()
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData
                                          ? String(modelData.title || modelData.tooltipTitle || modelData.id || "")
                                          : ""

                        Rectangle {
                            anchors.fill: parent
                            visible: trayIcon.needsAttention || trayIcon.activeFocus || trayMouse.containsMouse
                            radius: root.tokens.radius.small
                            color: trayMouse.containsMouse ? root.tokens.color.surface : "transparent"
                            border.width: trayIcon.needsAttention || trayIcon.activeFocus ? 1 : 0
                            border.color: root.tokens.color.secondary
                            antialiasing: true
                        }

                        IconImage {
                            id: trayImage
                            anchors.centerIn: parent
                            implicitSize: 20
                            width: implicitSize
                            height: implicitSize
                            visible: trayIcon.iconAvailable && status !== Image.Error
                            source: trayIcon.iconAvailable ? trayIcon.iconSource : ""
                            asynchronous: true
                            mipmap: true
                        }

                        StatusText {
                            visible: !trayImage.visible && trayIcon.iconName !== ""
                            anchors.centerIn: parent
                            text: trayIcon.iconName
                            color: root.tokens.color.textMuted
                        }

                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                var entry = trayIcon.modelData
                                if (!entry)
                                    return
                                if (mouse.button === Qt.MiddleButton) {
                                    entry.secondaryActivate()
                                    return
                                }
                                if (mouse.button === Qt.RightButton) {
                                    if (entry.hasMenu)
                                        root.openTrayMenu(entry, trayIcon)
                                    else
                                        entry.secondaryActivate()
                                    return
                                }
                                if (entry.onlyMenu)
                                    root.openTrayMenu(entry, trayIcon)
                                else
                                    entry.activate()
                            }
                            onWheel: function (wheel) {
                                var entry = trayIcon.modelData
                                if (!entry)
                                    return
                                if (wheel.angleDelta.y !== 0)
                                    entry.scroll(wheel.angleDelta.y, false)
                                else if (wheel.angleDelta.x !== 0)
                                    entry.scroll(wheel.angleDelta.x, true)
                            }
                        }
                    }
                }
                }
                Flickable {
                    width: parent.width
                    height: visible ? Math.min(360, menuColumn.implicitHeight) : 0
                    contentHeight: menuColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    visible: root.opened === "tray" && root.trayMenuStack.length > 0
                    Column {
                    id: menuColumn
                    width: parent.width
                    spacing: 4
                    StatusButton {
                        tokens: root.tokens
                        width: parent.width
                        text: "‹ Back"
                        hint: "Back to previous menu"
                        onClicked: root.popTrayMenu()
                    }
                    Repeater {
                        model: root.currentTrayMenu ? root.currentTrayMenu.children : null
                        delegate: StatusButton {
                            required property var modelData
                            tokens: root.tokens
                            width: popupColumn.width
                            height: modelData.isSeparator ? 9 : 36
                            enabled: modelData.enabled && !modelData.isSeparator
                            text: (modelData.checkState === Qt.Checked ? "✓  " : "")
                                  + modelData.text.replace(/&([^&])/g, "$1")
                                  + (modelData.hasChildren ? "  ›" : "")
                            Rectangle {
                                visible: parent.modelData.isSeparator
                                anchors.centerIn: parent
                                width: parent.width - 16
                                height: 1
                                color: root.tokens.color.border
                            }
                            onClicked: {
                                if (modelData.hasChildren)
                                    root.pushTrayMenu(modelData)
                                else {
                                    modelData.triggered()
                                    root.opened = ""
                                }
                            }
                        }
                    }
                }
                }
                Column {
                    visible: root.opened === "audio"
                    width: parent.width
                    spacing: 8
                    StatusText {
                        width: parent.width
                        elide: Text.ElideRight
                        text: audio.available ? audio.sink.description : "No audio output available"
                    }
                    Flickable {
                        width: parent.width
                        height: Math.min(180, outputsColumn.implicitHeight)
                        contentHeight: outputsColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: outputsColumn
                            width: parent.width
                            spacing: 4
                    Repeater {
                        model: QsPw.Pipewire.nodes
                        delegate: StatusButton {
                            required property var modelData
                            tokens: root.tokens
                            visible: modelData.isSink && !modelData.isStream && modelData.audio !== null
                            width: parent.width
                            text: modelData.description || modelData.name
                            checked: audio.sink === modelData
                            hint: "Use this audio output"
                            onClicked: QsPw.Pipewire.preferredDefaultAudioSink = modelData
                        }
                    }
                        }
                    }
                    Slider {
                        id: volumeSlider
                        implicitHeight: 32
                        width: parent.width
                        from: 0
                        to: 1
                        value: audio.level
                        enabled: audio.available
                        Accessible.name: "Output volume"
                        onMoved: audio.setVolume(value)
                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                            width: volumeSlider.availableWidth
                            height: 4
                            radius: 2
                            color: root.tokens.color.surface
                            Rectangle {
                                width: volumeSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: root.tokens.color.accent
                            }
                        }
                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                            width: 16
                            height: 16
                            radius: 8
                            color: root.tokens.color.text
                            border.width: volumeSlider.visualFocus ? 2 : 0
                            border.color: root.tokens.color.accent
                        }
                    }
                    Row {
                        spacing: 8
                        StatusButton {
                            tokens: root.tokens
                            enabled: audio.available
                            iconName: audio.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                            hint: audio.muted ? "Unmute" : "Mute"
                            onClicked: audio.toggleMuted()
                        }
                        StatusText {
                            height: 32
                            verticalAlignment: Text.AlignVCenter
                            text: audio.available ? audio.label : "Unavailable"
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
                Column {
                    visible: root.opened === "network"
                    width: parent.width
                    spacing: 8
                    StatusText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: !network.available ? "NetworkManager unavailable"
                              : network.degraded ? "Connection requires attention: " + network.label
                              : network.linked ? "Connected · " + network.label : "Disconnected"
                    }
                    StatusButton {
                        tokens: root.tokens
                        width: parent.width
                        text: !QsNet.Networking.wifiHardwareEnabled ? "Wi-Fi hardware disabled"
                              : QsNet.Networking.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"
                        checked: QsNet.Networking.wifiEnabled
                        enabled: network.managerPresent && QsNet.Networking.wifiHardwareEnabled
                        onClicked: QsNet.Networking.wifiEnabled = !QsNet.Networking.wifiEnabled
                    }
                    Flickable {
                        width: parent.width
                        height: Math.min(260, devicesColumn.implicitHeight)
                        contentHeight: devicesColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: devicesColumn
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: QsNet.Networking.devices
                                delegate: Column {
                                    id: deviceSection
                                    required property var modelData
                                    width: devicesColumn.width
                                    spacing: 4
                                    StatusText {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: deviceSection.modelData.name + (deviceSection.modelData.connected ? " · connected" : "")
                                        color: root.tokens.color.textMuted
                                        font.pixelSize: root.tokens.type.small.size
                                    }
                                    Repeater {
                                        model: deviceSection.modelData.networks
                                        delegate: StatusButton {
                                            required property var modelData
                                            tokens: root.tokens
                                            width: deviceSection.width
                                            text: modelData.name + (modelData.stateChanging ? " · connecting…" : modelData.connected ? " · connected" : "")
                                            checked: modelData.connected
                                            enabled: !modelData.stateChanging
                                            hint: modelData.connected ? "Disconnect" : "Connect"
                                            onClicked: root.connectNetwork(modelData)
                                            Connections {
                                                target: modelData
                                                function onConnectionFailed(reason) {
                                                    root.networkError = "Could not connect · " + QsNet.ConnectionFailReason.toString(reason)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: 8
                        visible: root.selectedNetwork !== null
                        StatusText {
                            width: parent.width
                            text: root.selectedNetwork ? "Password for " + root.selectedNetwork.name : ""
                            elide: Text.ElideRight
                        }
                        TextField {
                            id: passwordField
                            width: parent.width
                            echoMode: TextInput.Password
                            placeholderText: "Network password"
                            color: root.tokens.color.text
                            placeholderTextColor: root.tokens.color.textMuted
                            font.family: root.tokens.type.body.family
                            font.pixelSize: root.tokens.type.body.size
                            selectByMouse: true
                            Accessible.name: "Network password"
                            background: Rectangle {
                                color: root.tokens.color.background
                                radius: root.tokens.radius.small
                                border.width: 1
                                border.color: passwordField.activeFocus ? root.tokens.color.accent : root.tokens.color.border
                            }
                            onAccepted: connectAction.clicked()
                        }
                        StatusButton {
                            id: connectAction
                            tokens: root.tokens
                            width: parent.width
                            text: "Connect"
                            enabled: passwordField.text.length > 0
                            onClicked: {
                                if (root.selectedNetwork && passwordField.text.length) {
                                    root.selectedNetwork.connectWithPsk(passwordField.text)
                                    passwordField.clear()
                                    root.selectedNetwork = null
                                }
                            }
                        }
                    }
                    StatusText {
                        width: parent.width
                        visible: root.networkError !== ""
                        text: root.networkError
                        wrapMode: Text.Wrap
                        color: root.tokens.color.secondary
                    }
                }
            }
        }
    }
}
