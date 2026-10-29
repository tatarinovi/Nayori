pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking as QsNet
import "islands/status"
import "tokens"

ShellRoot {
    id: test
    property int step: 0
    property int ticks: 0
    property int settingsRequests: 0
    property bool mainPreview: false
    property bool morePreview: false
    property bool previewPending: false
    property string previewSuffix: ""
    Tokens { id: theme }
    component Entry: QtObject {
        property string name: ""
        property real signalStrength: 0.8
        property bool connected: false
        property bool known: true
        property bool stateChanging: false
        property int state: QsNet.ConnectionState.Disconnected
        property int security: QsNet.WifiSecurityType.Wpa2Psk
        signal connectionFailed(int reason)
    }
    Entry { id: home; name: "Nayori Home"; signalStrength: 0.95; connected: true }
    Entry { id: studio; name: "Studio"; signalStrength: 0.8 }
    Entry { id: guest; name: "Guest"; signalStrength: 0.7; security: QsNet.WifiSecurityType.Open }
    Entry { id: cafe; name: "Cafe"; signalStrength: 0.55; known: false }
    Entry { id: weak; name: "Distant network"; signalStrength: 0.3 }
    Entry { id: wired; name: "Ethernet"; connected: true }
    QtObject {
        id: ethernet
        property int type: QsNet.DeviceType.Wired
        property string name: "enp4s0"
        property string address: "192.168.1.24"
        property bool hasLink: true
        property bool connected: wired.connected
        property int linkSpeed: 1000
        property var network: wired
    }
    QtObject {
        id: wlan
        property int type: QsNet.DeviceType.Wifi
        property var networks: ({values: [weak, cafe, guest, home, studio]})
    }
    QtObject {
        id: fake
        property bool managerPresent: true
        property bool wifiHardwareEnabled: true
        property bool wifiEnabled: true
        property int connectivity: QsNet.NetworkConnectivity.Full
        property var devices: ({values: [ethernet, wlan]})
        property int connects: 0
        property int disconnects: 0
        property string secret: ""
        function setWifiEnabled(value) { wifiEnabled = value }
        function needsPsk(entry) { return !entry.known && entry.security !== QsNet.WifiSecurityType.Open }
        function pskSupported(entry) { return entry.security === QsNet.WifiSecurityType.Wpa2Psk }
        function connectEntry(entry) { connects++; entry.connected = true }
        function disconnectEntry(entry) { disconnects++; entry.connected = false }
        function connectWithPsk(entry, value) { secret = value; connects++; entry.connected = true }
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 360; implicitHeight: panel.implicitHeight + 32
        color: theme.color.background
        Rectangle {
            id: preview
            anchors.fill: parent
            color: theme.material.dense
            radius: 12
            border { width: 1; color: theme.color.accentSoft }
            NetworkPanel {
                id: panel
                x: 16; y: 16; width: 328
                tokens: theme
                active: window.visible
                control: fake
                onSettingsRequested: test.settingsRequests++
            }
        }
    }
    function check(ok, label) {
        if (!ok) { console.error("NETWORK_PANEL_FAIL " + label); Qt.exit(1) }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    function capture(suffix) {
        test.previewPending = true
        test.previewSuffix = suffix
        previewDelay.start()
    }
    Timer {
        id: previewDelay
        interval: 120
        onTriggered: preview.grabToImage(result => {
            result.saveToFile(Quickshell.env("NAYORI_NETWORK_PREVIEW") + test.previewSuffix + ".png")
            test.previewPending = false
        })
    }
    Timer {
        interval: 20; repeat: true; running: true
        onTriggered: {
            test.ticks++
            test.check(test.ticks < 700, "timeout step " + test.step)
            if (test.previewPending) return
            if (test.step === 0 && panel.wireguardControl.ready) {
                test.check(panel.nearestNetworks.length === 3 && panel.otherNetworks.length === 2, "three plus remaining")
                test.check(panel.nearestNetworks[0] === home && panel.otherNetworks[0] === cafe, "signal order")
                test.check(panel.wiredDevices[0] === ethernet, "Ethernet separate from VPN")
                test.check(test.find(panel, "network-ethernet").detail.indexOf("1 Гбит/с") >= 0, "wired speed")
                if (Quickshell.env("NAYORI_NETWORK_PREVIEW") && !test.mainPreview) {
                    test.mainPreview = true
                    test.capture("-main")
                    return
                }
                panel.navigate(1, false)
                test.check(panel.motionRunning, "pointer navigation animates")
                test.step++
            } else if (test.step === 1 && panel.slide > 0.1 && panel.slide < 0.95) {
                panel.navigate(0, false)
                test.step++
            } else if (test.step === 2 && !panel.motionRunning && panel.slide === 0) {
                panel.navigate(1, true)
                test.check(panel.slide === 1 && !panel.motionRunning, "keyboard navigation is instant")
                test.step++
            } else if (test.step === 3) {
                if (Quickshell.env("NAYORI_NETWORK_PREVIEW") && !test.morePreview) {
                    test.morePreview = true
                    test.capture("-more")
                    return
                }
                test.check(test.find(panel, "network-back").activeFocus, "detail focus")
                theme.animationsEnabled = false
                panel.navigate(0, false)
                test.check(panel.slide === 0 && !panel.motionRunning, "reduced motion")
                weak.signalStrength = 0.99
                test.step++
            } else if (test.step === 4) {
                test.check(panel.nearestNetworks[0] === weak && panel.otherNetworks.length === 2, "live signal reorders")
                theme.animationsEnabled = true
                panel.useNetwork(cafe, true)
                test.check(panel.page === 2 && panel.pending === cafe, "secure unknown network prompts")
                test.step++
            } else if (test.step === 5) {
                const password = test.find(panel, "network-password")
                test.check(password.activeFocus, "password focus")
                password.text = "  password with spaces  "
                panel.submitPassword()
                test.check(fake.secret === "  password with spaces  " && password.text === "" && !panel.pending, "PSK exact and cleared")
                panel.useNetwork(cafe, true)
                test.check(fake.disconnects === 1, "connected network disconnects")
                panel.useNetwork(studio, true)
                test.check(studio.connected, "saved network connects")
                home.connectionFailed(QsNet.ConnectionFailReason.NoSecrets)
                test.check(panel.error.indexOf("пароль") >= 0, "failure surfaced")
                panel.navigate(1, true)
                fake.wifiEnabled = false
                test.step++
            } else if (test.step === 6) {
                test.check(panel.page === 0, "Wi-Fi off returns to summary")
                ethernet.hasLink = false
                wired.connected = false
                fake.wifiHardwareEnabled = false
                test.step++
            } else if (test.step === 7) {
                test.check(test.find(panel, "network-ethernet").detail === "Кабель не подключён", "unplugged cable")
                test.check(!test.find(panel, "network-wifi-switch").enabled, "hardware block")
                panel.settingsRequested()
                test.check(test.settingsRequests === 1, "full settings action")
                fake.wifiEnabled = true
                fake.wifiHardwareEnabled = true
                cafe.connected = false
                panel.useNetwork(cafe, true)
                test.find(panel, "network-password").text = "discard me"
                window.visible = false
                test.step++
            } else if (test.step === 8) {
                test.check(panel.page === 0 && !panel.pending && test.find(panel, "network-password").text === "", "close resets private input")
                console.log("NETWORK_PANEL_PASS")
                Qt.quit()
            }
        }
    }
}
