pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Networking as QsNet
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire as QsPw
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../services/status"
import "../shared"
import "../../surfaces/settings"

// Содержимое правого острова. Окна слоя здесь нет.
// Общая геометрия панели: строка 32 и отступ 8.
Rectangle {
    id: root

    required property var tokens
    property var bluetoothService: null
    property var settingsService: null
    signal bluetoothSettingsRequested()
    property var menuWindow: null
    property var mixerSources: []
    signal mixerSourcesSeen(var sources)

    readonly property int pad: tokens.spacing.small

    implicitWidth: cluster.implicitWidth + pad * 2
    implicitHeight: 32 + pad * 2
    width: implicitWidth
    height: implicitHeight
    radius: tokens.radius.small + pad
    color: tokens.material.panel
    border.width: 1
    border.color: tokens.color.border
    antialiasing: true

    Audio {
        id: audio
        mixerSources: root.mixerSources
    }

    readonly property var noticedSources: {
        const apps = audio.applications || []
        const seen = []
        for (let i = 0; i < apps.length; i++) {
            const group = apps[i]
            if (!group)
                continue
            seen.push({
                key: group.key,
                title: audio.applicationTitle(group.nodes, group.title)
            })
        }
        return seen
    }
    onNoticedSourcesChanged: mixerSourcesSeen(noticedSources)

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
        if (opened !== "bluetooth" && bluetoothService) bluetoothService.stopDiscovery()
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

    component MixerSlider: Slider {
        id: mixerSlider
        property real source: 0
        implicitHeight: 32
        width: parent.width
        from: 0
        to: 1
        value: source
        background: Rectangle {
            x: mixerSlider.leftPadding
            y: mixerSlider.topPadding + (mixerSlider.availableHeight - height) / 2
            width: mixerSlider.availableWidth
            height: 4
            radius: 2
            color: root.tokens.color.surface
            Rectangle {
                width: mixerSlider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: root.tokens.color.accent
            }
        }
        handle: Rectangle {
            x: mixerSlider.leftPadding + mixerSlider.visualPosition * (mixerSlider.availableWidth - width)
            y: mixerSlider.topPadding + (mixerSlider.availableHeight - height) / 2
            width: 16
            height: 16
            radius: 8
            color: root.tokens.color.text
            border.width: mixerSlider.visualFocus ? 2 : 0
            border.color: root.tokens.color.accent
        }
    }

    function iconUrl(name) {
        const icon = String(name || "").trim()
        if (icon === "")
            return ""
        if (icon.charAt(0) === "/")
            return "file://" + icon
        if (icon.startsWith("file:"))
            return icon
        try {
            if (!Quickshell.hasThemeIcon(icon))
                return ""
            const path = Quickshell.iconPath(icon)
            return path ? String(path) : ""
        } catch (error) {
            return ""
        }
    }

    function playbackIcon(nodes) {
        const fromDesktop = root.iconUrl(audio.applicationIcon(nodes))
        if (fromDesktop !== "")
            return fromDesktop
        if (!nodes)
            return ""
        for (let i = 0; i < nodes.length; i++) {
            const props = nodes[i] && nodes[i].properties
            const name = props ? String(props["application.icon-name"] || "") : ""
            const fromStream = root.iconUrl(name)
            if (fromStream !== "")
                return fromStream
        }
        return ""
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
        Row {
            spacing: 3
            visible: !!root.bluetoothService && (!root.settingsService || root.settingsService.bluetoothIconVisible)
            StatusButton {
                tokens: root.tokens
                iconName: !root.bluetoothService || !root.bluetoothService.adapter ? "bluetooth-unavailable"
                    : !root.bluetoothService.powered ? "bluetooth-off"
                    : root.bluetoothService.connectedCount > 0 ? "bluetooth-connected" : "bluetooth"
                hint: root.bluetoothService ? root.bluetoothService.statusText : "Bluetooth недоступен"
                checked: root.opened === "bluetooth"
                onClicked: root.togglePopup("bluetooth")
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: root.togglePopup("bluetooth-context")
                }
            }
            Repeater {
                model: root.bluetoothService ? root.bluetoothService.batteryDevices : []
                delegate: Item {
                    id: batteryIndicator
                    required property var modelData
                    readonly property string percentage: root.bluetoothService.batteryText(modelData)
                    width: 9
                    height: 32
                    Accessible.role: Accessible.StaticText
                    Accessible.name: (modelData.name || modelData.address) + ": " + percentage
                    Rectangle {
                        x: 3; y: 6
                        width: 3; height: 20; radius: 1.5
                        color: root.tokens.color.border
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.height * batteryIndicator.modelData.battery
                            radius: 1.5
                            color: batteryIndicator.modelData.battery <= 0.15 ? root.tokens.color.secondary : root.tokens.color.accent
                            Behavior on height { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast } }
                        }
                    }
                    HoverHandler { id: batteryHover }
                    PanelTooltip {
                        tokens: root.tokens
                        target: batteryIndicator
                        hovered: batteryHover.hovered
                        text: (batteryIndicator.modelData.name || batteryIndicator.modelData.address) + " · " + batteryIndicator.percentage
                    }
                }
            }
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
        Region { id: popupGlass; item: popupGlassSurface; radius: root.tokens.radius.small + 12 }
        BackgroundEffect.blurRegion: root.tokens.frosted ? popupGlass : null
        implicitWidth: root.opened === "bluetooth" ? 360 : 320
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
            id: popupGlassSurface
            anchors.fill: parent
            radius: root.tokens.radius.small + 12
            color: root.tokens.material.menu
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
                        width: parent.width - 32 - (root.opened === "bluetooth" ? 84 : 0)
                        height: 32
                        verticalAlignment: Text.AlignVCenter
                        text: root.opened === "tray" ? "System tray" : root.opened === "audio" ? "Sound" : root.opened.startsWith("bluetooth") ? "Bluetooth" : "Network"
                        font.family: root.tokens.type.display.family
                        font.pixelSize: root.tokens.type.display.size
                    }
                    SettingsSwitch {
                        tokens: root.tokens
                        visible: root.opened === "bluetooth"
                        width: 52
                        height: 32
                        text: ""
                        Accessible.name: "Включить Bluetooth"
                        checked: !!root.bluetoothService && root.bluetoothService.powered
                        enabled: !!root.bluetoothService && !!root.bluetoothService.adapter && !root.bluetoothService.busy && root.bluetoothService.bridgeReady
                        onClicked: {
                            root.bluetoothService.setPowered(!root.bluetoothService.powered)
                            checked = Qt.binding(() => root.bluetoothService.powered)
                        }
                    }
                    StatusButton {
                        tokens: root.tokens
                        visible: root.opened === "bluetooth"
                        iconName: "settings"
                        hint: "Настройки Bluetooth"
                        onClicked: { root.opened = ""; root.bluetoothSettingsRequested() }
                    }
                    StatusButton {
                        tokens: root.tokens
                        text: "×"
                        hint: "Close"
                        onClicked: root.opened = ""
                    }
                }
                StatusButton {
                    tokens: root.tokens
                    visible: root.opened === "bluetooth-context"
                    width: parent.width
                    text: "Скрыть иконку"
                    enabled: !!root.settingsService && root.settingsService.ready
                    onClicked: {
                        root.settingsService.update({bluetoothIconVisible: false})
                        root.opened = ""
                    }
                }
                Flickable {
                    visible: root.opened === "bluetooth"
                    width: parent.width
                    height: visible ? Math.min(480, bluetoothColumn.implicitHeight) : 0
                    contentHeight: bluetoothColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: bluetoothColumn
                        width: parent.width
                        spacing: 8
                        BluetoothControls {
                            width: parent.width
                            tokens: root.tokens
                            bluetooth: root.bluetoothService
                            showPowerToggle: false
                            active: root.opened === "bluetooth"
                        }
                    }
                    ScrollBar.vertical: ScrollBar { }
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
                    MixerSlider {
                        source: audio.level
                        enabled: audio.available
                        Accessible.name: "Output volume"
                        onMoved: audio.setVolume(value)
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
                    StatusText {
                        width: parent.width
                        visible: audio.available
                        text: "Applications"
                        color: root.tokens.color.textMuted
                        font.pixelSize: root.tokens.type.small.size
                    }
                    StatusText {
                        width: parent.width
                        visible: audio.available && audio.applications.length === 0
                        text: "Nothing is playing"
                        color: root.tokens.color.textMuted
                        wrapMode: Text.Wrap
                    }
                    Flickable {
                        width: parent.width
                        height: visible ? Math.min(240, appsColumn.implicitHeight) : 0
                        contentHeight: appsColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        visible: audio.visibleApplications.length > 0
                        Column {
                            id: appsColumn
                            width: parent.width
                            spacing: 12
                            Repeater {
                                model: audio.visibleApplications
                                delegate: Column {
                                    id: appRow
                                    required property var modelData
                                    readonly property string title: audio.applicationTitle(modelData.nodes, modelData.title)
                                    readonly property string detail: audio.applicationDetail(modelData.nodes)
                                    readonly property string iconSource: root.playbackIcon(modelData.nodes)
                                    readonly property string mark: {
                                        const text = title.trim()
                                        return text.length > 0 ? text.charAt(0).toUpperCase() : ""
                                    }
                                    width: appsColumn.width
                                    spacing: 2

                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        Item {
                                            width: 20
                                            height: 32
                                            IconImage {
                                                id: appIcon
                                                anchors.centerIn: parent
                                                implicitSize: 18
                                                width: implicitSize
                                                height: implicitSize
                                                visible: appRow.iconSource !== "" && status !== Image.Error
                                                source: appRow.iconSource
                                                asynchronous: true
                                                mipmap: true
                                            }
                                            StatusText {
                                                visible: !appIcon.visible && appRow.mark !== ""
                                                anchors.centerIn: parent
                                                text: appRow.mark
                                                color: root.tokens.color.textMuted
                                            }
                                        }
                                        Column {
                                            width: parent.width - 20 - 48 - 32 - 24
                                            spacing: 0
                                            StatusText {
                                                width: parent.width
                                                height: 32
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                                text: appRow.title
                                            }
                                            StatusText {
                                                width: parent.width
                                                visible: appRow.detail !== ""
                                                elide: Text.ElideRight
                                                text: appRow.detail
                                                color: root.tokens.color.textMuted
                                                font.pixelSize: root.tokens.type.small.size
                                            }
                                        }
                                        StatusText {
                                            width: 48
                                            height: 32
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                            text: audio.nodesLabel(appRow.modelData.nodes)
                                            font.features: ({ "tnum": 1 })
                                        }
                                        StatusButton {
                                            tokens: root.tokens
                                            iconName: audio.nodesMuted(appRow.modelData.nodes)
                                                      ? "audio-volume-muted-symbolic"
                                                      : "audio-volume-high-symbolic"
                                            hint: (audio.nodesMuted(appRow.modelData.nodes) ? "Unmute " : "Mute ") + appRow.title
                                            onClicked: audio.setNodesMuted(appRow.modelData.nodes, !audio.nodesMuted(appRow.modelData.nodes))
                                        }
                                    }
                                    MixerSlider {
                                        source: audio.nodesLevel(appRow.modelData.nodes)
                                        Accessible.name: appRow.title + " volume"
                                        onMoved: audio.setNodesVolume(appRow.modelData.nodes, value)
                                    }
                                }
                            }
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
