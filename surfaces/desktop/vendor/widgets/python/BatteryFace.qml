import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower



Item {
    readonly property var nayoriBatteryFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 160
    property real minHeight: 60
    property real maxWidth: 600
    property real maxHeight: 200
    property real minAspect: 1.5
    property real maxAspect: 4.5
    property bool isRound: false
    // The Stage slot can own the backing without covering this face.
    property bool ryokuBare: false


    readonly property bool hasBattery: UPower.displayDevice.ready ? UPower.displayDevice.isLaptopBattery : !nayoriBatteryFace.systemInfo.isDesktop
    readonly property int batCapacity: (UPower.displayDevice.ready && hasBattery) ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool isCharging: hasBattery && UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)
    readonly property bool isActivelyCharging: isCharging && UPower.displayDevice.changeRate > 0.5

    readonly property color batColorFlat: {
        if (!hasBattery) return nayoriBatteryFace.pythonTheme.subtext0;
        if (isCharging) return nayoriBatteryFace.pythonTheme.green;
        if (batCapacity <= 20) return nayoriBatteryFace.pythonTheme.red;
        return nayoriBatteryFace.pythonTheme.blue;
    }

    property real animCapacity: 0
    property bool waveActive: false
    property bool waveReady: false

    function stirWave() {
        if (!root.waveReady || !root.visible || !root.hasBattery
                || root.fillLevel <= 0.0 || root.fillLevel >= 1.0)
            return;
        root.waveActive = true;
        waveSettleTimer.restart();
    }

    Behavior on animCapacity {
        enabled: root.visible
        NumberAnimation { duration: (nayoriBatteryFace && nayoriBatteryFace.reducedMotion ? 0 : 1200); easing.type: Easing.OutQuint }
    }

    onBatCapacityChanged: {
        if (root.visible && hasBattery)
            animCapacity = batCapacity;
        root.stirWave();
    }
    onIsChargingChanged: root.stirWave()
    onVisibleChanged: {
        if (visible && hasBattery) {
            animCapacity = batCapacity;
        } else {
            waveActive = false;
            waveSettleTimer.stop();
        }
    }

    Component.onCompleted: {
        if (hasBattery)
            animCapacity = batCapacity;
        waveReady = true;
    }

    readonly property real fillLevel: hasBattery ? animCapacity / 100 : 0
    readonly property real maxWaveAmp: isCharging ? nayoriBatteryFace.scaler.s(10) : nayoriBatteryFace.scaler.s(6.5)
    readonly property real waveAmp: (fillLevel < 0.99 && fillLevel > 0.01) ? maxWaveAmp * Math.sin(fillLevel * Math.PI) : 0

    property real wavePhase: waveClock.phase
    WaveClock {
        motionEnabled: !!nayoriBatteryFace && !nayoriBatteryFace.reducedMotion
        id: waveClock
        running: root.visible && root.waveActive
        duration: root.isCharging ? 1200 : 3400
    }
    Timer {
        id: waveSettleTimer
        interval: root.isCharging ? 1200 : 3400
        repeat: false
        onTriggered: root.waveActive = false
    }

    readonly property string timeString: {
        if (!hasBattery) return "No battery found";
        if (!UPower.displayDevice.ready) return "Unknown";
        if (UPower.displayDevice.state === UPowerDeviceState.FullyCharged) return nayoriBatteryFace.i18n.t("syspanel.battery.fully_charged");
        let secs = isCharging ? UPower.displayDevice.timeToFull : UPower.displayDevice.timeToEmpty;
        let h = Math.floor(secs / 3600);
        let m = Math.round((secs % 3600) / 60);
        if (UPower.displayDevice.state === UPowerDeviceState.Charging) {
            if (h === 0 && m === 0) return nayoriBatteryFace.i18n.t("syspanel.battery.charging");
            return nayoriBatteryFace.i18n.t("syspanel.battery.charging_time", { hours: h, mins: m });
        }
        if (h === 0 && m === 0) return nayoriBatteryFace.i18n.t("syspanel.battery.discharging");
        return nayoriBatteryFace.i18n.t("syspanel.battery.left_time", { hours: h, mins: m });
    }

    Rectangle {
        id: bgContainer
        anchors.fill: parent
        color: root.ryokuBare ? "transparent" : Qt.alpha(nayoriBatteryFace.pythonTheme.surface0, nayoriBatteryFace.pythonTheme.elementOpacity)
        radius: nayoriBatteryFace.pythonTheme.borderRadius
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            visible: !root.ryokuBare
        }

        WaveSurface {
            anchors.fill: parent
            visible: root.visible && root.hasBattery && root.fillLevel > 0.001
            fill: root.fillLevel
            horizontal: 1
            amp: Math.min(root.waveAmp, Math.min(width * root.fillLevel, width * (1.0 - root.fillLevel)))
            phase: root.wavePhase
            radius: bgContainer.radius
            alpha: 1
            colorTop: root.batColorFlat
            colorBottom: root.batColorFlat
        }

        component BatteryContent : Item {
            id: bRoot
            property color contentTextColor: nayoriBatteryFace.pythonTheme.text
            property color iconColor: root.batColorFlat

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: nayoriBatteryFace.scaler.s(16)
                anchors.rightMargin: nayoriBatteryFace.scaler.s(16)
                spacing: nayoriBatteryFace.scaler.s(14)

                Text {
                    font.family: nayoriBatteryFace.pythonTheme.iconFont
                    font.pixelSize: Math.round(Math.max(nayoriBatteryFace.scaler.s(22), Math.min(nayoriBatteryFace.scaler.s(36), root.height * 0.36)))
                    color: bRoot.iconColor
                    text: {
                        if (!root.hasBattery) return "󰂎";
                        if (root.isCharging) return "󰂄";
                        if (root.batCapacity > 80) return "󰁹";
                        if (root.batCapacity > 60) return "󰂀";
                        if (root.batCapacity > 40) return "󰁾";
                        if (root.batCapacity > 20) return "󰁼";
                        return "󰂃";
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    spacing: nayoriBatteryFace.scaler.s(2)
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        font.family: nayoriBatteryFace.pythonTheme.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: Math.round(Math.max(nayoriBatteryFace.scaler.s(14), Math.min(nayoriBatteryFace.scaler.s(24), root.height * 0.26)))
                        color: bRoot.contentTextColor
                        text: root.hasBattery ? (Math.round(root.animCapacity) + "%") : "No battery found"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        font.family: nayoriBatteryFace.pythonTheme.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: Math.round(Math.max(nayoriBatteryFace.scaler.s(9), Math.min(nayoriBatteryFace.scaler.s(12), root.height * 0.13)))
                        color: bRoot.contentTextColor === nayoriBatteryFace.pythonTheme.crust ? Qt.alpha(nayoriBatteryFace.pythonTheme.crust, 0.85) : (root.isCharging ? nayoriBatteryFace.pythonTheme.green : nayoriBatteryFace.pythonTheme.subtext0)
                        text: root.hasBattery ? root.timeString : "AC power connected"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        BatteryContent {
            anchors.fill: parent
            contentTextColor: nayoriBatteryFace.pythonTheme.text
            iconColor: root.batColorFlat
        }

        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: root.hasBattery && root.fillLevel > 0.001

            property real phaseOffset: Math.sin(root.wavePhase) - Math.cos(root.wavePhase)
            property real centerOffset: root.fillLevel > 0.01 && root.fillLevel < 0.99 ? 0.375 * root.waveAmp * phaseOffset : 0

            width: Math.max(0, Math.min(parent.width, (parent.width * root.fillLevel) + centerOffset))
            clip: true

            BatteryContent {
                width: bgContainer.width
                height: bgContainer.height
                contentTextColor: nayoriBatteryFace.pythonTheme.crust
                iconColor: nayoriBatteryFace.pythonTheme.crust
            }
        }
    }
}
