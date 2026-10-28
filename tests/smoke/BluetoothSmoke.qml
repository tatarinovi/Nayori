pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "services/system"
import "services/settings"
import "surfaces/settings"
import "islands/status"
import "tokens"

ShellRoot {
    id: test
    Tokens { id: theme }
    SettingsService { id: settings; storageDirectory: Quickshell.env("NAYORI_BT_SETTINGS") }
    BluetoothService { id: bluetooth }
    FloatingWindow {
        id: window
        visible: true
        width: 420; height: 720
        color: theme.color.background
        Item {
            id: preview
            anchors.fill: parent
        BluetoothPage { id: page; x: 12; y: 70; tokens: theme; bluetoothService: bluetooth; settingsService: settings; width: 400 }
        StatusIsland { id: status; menuWindow: window; x: 12; y: 12; tokens: theme; bluetoothService: bluetooth; settingsService: settings }
        }
    }
    Timer {
        id: previewDelay
        interval: 120
        onTriggered: {
            preview.grabToImage(result => result.saveToFile(Quickshell.env("NAYORI_BT_PREVIEW") + ".panel.png"))
            for (let i = 0; i < status.data.length; i++) {
                const popup = status.data[i]
                if (popup && popup.toString().indexOf("Popup") >= 0 && popup.contentItem) {
                    popup.contentItem.children[0].grabToImage(result => {
                        result.saveToFile(Quickshell.env("NAYORI_BT_PREVIEW"))
                        test.previewDone = true
                    })
                }
            }
        }
    }
    property bool previewStarted: false
    property bool previewDone: false
    property var restored: null
    property Component settingsFactory: Component { SettingsService { storageDirectory: settings.storageDirectory } }
    property int step: 0
    property int ticks: 0
    function check(ok, label) {
        if (!ok) { console.error("BLUETOOTH_FAIL " + label); Qt.exit(1) }
    }
    Timer {
        interval: 30; repeat: true; running: true
        onTriggered: {
            test.ticks++
            test.check(test.ticks < 500, "timeout step " + test.step + " " + bluetooth.error)
            if (test.step === 0 && bluetooth.adapter && settings.ready) {
                test.check(bluetooth.powered && !bluetooth.discovering, "initial adapter state")
                test.check(bluetooth.deviceList.length === 1, "native device model")
                test.check(bluetooth.batteryText(bluetooth.deviceList[0]) === "", "no disconnected battery")
                test.check(bluetooth.batteryText({connected: true, batteryAvailable: false, battery: 0.8}) === "", "no unavailable battery")
                test.check(bluetooth.batteryText({connected: true, batteryAvailable: true, battery: 42}) === "", "invalid battery rejected")
                bluetooth.act(bluetooth.deviceList[0], "connect")
                test.check(!bluetooth.act(bluetooth.deviceList[0], "connect"), "duplicate rejected")
                test.step++
            } else if (test.step === 1 && !bluetooth.busy && bluetooth.connectedCount === 1) {
                if (Quickshell.env("NAYORI_BT_PREVIEW") && !test.previewDone) {
                    if (!test.previewStarted) {
                        test.previewStarted = true
                        status.opened = "bluetooth"
                        previewDelay.start()
                    }
                    return
                }
                test.check(bluetooth.batteryText(bluetooth.deviceList[0]) === "42%", "real battery value")
                bluetooth.act(bluetooth.deviceList[0], "disconnect")
                test.step++
            } else if (test.step === 2 && !bluetooth.busy && bluetooth.connectedCount === 0) {
                status.opened = "bluetooth"
                bluetooth.setDiscovering(true)
                test.step++
            } else if (test.step === 3 && bluetooth.scanOwned && !bluetooth.busy) {
                test.check(bluetooth.discovering, "native discovery signal")
                test.check(bluetooth.deviceList.length === 2, "new device found through native model")
                status.opened = ""
                test.step++
            } else if (test.step === 4 && !bluetooth.busy && !bluetooth.discovering) {
                bluetooth.act(bluetooth.deviceList.find(d => !d.paired), "pair")
                test.step++
            } else if (test.step === 5 && bluetooth.agentRequest) {
                test.check(bluetooth.agentRequest.code === "123456", "pairing confirmation")
                bluetooth.answerAgent(true, "")
                test.step++
            } else if (test.step === 6 && !bluetooth.busy) {
                bluetooth.act(bluetooth.deviceList[0], "forget")
                test.step++
            } else if (test.step === 7 && !bluetooth.busy) {
                bluetooth.setPowered(false)
                test.step++
            } else if (test.step === 8 && !bluetooth.busy && !bluetooth.powered) {
                test.check(!bluetooth.setDiscovering(true), "cannot scan powered off")
                settings.update({bluetoothIconVisible: false})
                settings.flush(false)
                test.step++
            } else if (test.step === 9 && !settings.dirty && !settings.saving) {
                test.check(!settings.bluetoothIconVisible, "visibility persisted")
                bluetooth.setPowered(true)
                test.step++
            } else if (test.step === 10 && !bluetooth.busy && bluetooth.powered) {
                bluetooth.act(bluetooth.deviceList[0], "connect")
                test.step++
            } else if (test.step === 11 && !bluetooth.busy && bluetooth.error) {
                test.check(bluetooth.error.indexOf("TestFailure") >= 0, "DBus error reported")
                test.check(bluetooth.connectedCount === 0, "failed connect not fabricated")
                test.restored = test.settingsFactory.createObject(test)
                test.step++
            } else if (test.step === 12 && !bluetooth.adapter && test.restored.ready) {
                test.check(bluetooth.unavailableReason !== "", "adapter removal reported")
                test.check(!bluetooth.setPowered(true), "no adapter action rejected")
                test.check(!test.restored.bluetoothIconVisible, "visibility restored by fresh service")
                console.log("BLUETOOTH_PASS")
                Qt.quit()
            }
        }
    }
}
