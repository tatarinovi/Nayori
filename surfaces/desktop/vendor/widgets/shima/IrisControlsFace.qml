import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth







IrisWidgetFace {
    readonly property var nayoriIrisControlsFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    readonly property bool labelled: !root.small
    readonly property int columns: root.small ? 2 : 4
    readonly property real spacing: root.dp(root.small ? 14 : 12)
    readonly property real cell: (root.contentWidth - root.spacing * (root.columns - 1)) / root.columns
    readonly property real disc: Math.min(root.cell, root.dp(root.small ? 60 : root.medium ? 48 : 56))
    readonly property var monitor: nayoriIrisControlsFace.brightness.getMonitorForScreen(root.QsWindow?.window?.screen ?? null)

    component Toggle: Item {
        id: toggle
        property string glyph: ""
        property string label: ""
        property bool on: false
        property color tint: root.accent
        property bool available: true
        signal toggled()

        Layout.preferredWidth: root.cell
        Layout.preferredHeight: root.disc + (root.labelled ? root.dp(20) : 0)
        opacity: toggle.available ? 1 : 0.4

        Rectangle {
            id: disc
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.disc
            height: root.disc
            radius: height / 2
            color: toggle.on ? toggle.tint : tap.pressed ? root.fillActive : hover.hovered ? root.fillHover : root.fill
            scale: tap.pressed ? nayoriIrisControlsFace.irisStyle.pressScale(0.94) : 1
            Behavior on color { ColorAnimation { duration: nayoriIrisControlsFace.irisStyle.feedbackDuration; easing.type: nayoriIrisControlsFace.irisStyle.feedbackEasing } }
            Behavior on scale { NumberAnimation { duration: nayoriIrisControlsFace.irisStyle.feedbackDuration; easing.type: nayoriIrisControlsFace.irisStyle.feedbackEasing } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: toggle.glyph
                fill: toggle.on ? 1 : 0
                iconSize: Math.round(root.disc * 0.42)
                color: toggle.on ? root.onFill(toggle.tint) : root.ink
            }
            HoverHandler { id: hover; enabled: toggle.available; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: tap; enabled: toggle.available; gesturePolicy: TapHandler.WithinBounds; onTapped: toggle.toggled() }
        }
        FaceText {
            face: root
            visible: root.labelled
            anchors.top: disc.bottom
            anchors.topMargin: root.dp(5)
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: nayoriIrisControlsFace.i18n.tr(toggle.label)
            color: toggle.on ? root.ink : root.inkSecondary
            size: 11
        }
        Accessible.role: Accessible.CheckBox
        Accessible.name: toggle.label
        Accessible.checked: toggle.on
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.dp(root.large ? 14 : 12)

        Item { Layout.fillHeight: root.large; visible: root.large }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: root.small
            columns: root.columns
            columnSpacing: root.spacing
            rowSpacing: root.dp(root.small ? 14 : 10)

            Toggle {
                glyph: nayoriIrisControlsFace.network.ethernet ? "lan" : nayoriIrisControlsFace.network.wifiEnabled ? "wifi" : "wifi_off"
                label: nayoriIrisControlsFace.network.ethernet ? nayoriIrisControlsFace.translation.tr("Ethernet") : (nayoriIrisControlsFace.network.networkName || nayoriIrisControlsFace.translation.tr("Wi-Fi"))
                on: nayoriIrisControlsFace.network.ethernet || nayoriIrisControlsFace.network.wifiEnabled
                tint: nayoriIrisControlsFace.irisStyle.identity.blue
                onToggled: nayoriIrisControlsFace.network.toggleWifi()
            }
            Toggle {
                glyph: nayoriIrisControlsFace.bluetooth.enabled ? "bluetooth" : "bluetooth_disabled"
                label: nayoriIrisControlsFace.bluetooth.activeDeviceSummary() || nayoriIrisControlsFace.translation.tr("Bluetooth")
                on: nayoriIrisControlsFace.bluetooth.enabled
                available: nayoriIrisControlsFace.bluetooth.available
                tint: nayoriIrisControlsFace.irisStyle.identity.blue
                onToggled: nayoriIrisControlsFace.bluetooth.toggle()
            }
            Toggle {
                glyph: nayoriIrisControlsFace.notifications.manualDndActive ? "do_not_disturb_on" : "do_not_disturb_off"
                label: nayoriIrisControlsFace.translation.tr("Focus")
                on: nayoriIrisControlsFace.notifications.manualDndActive
                tint: nayoriIrisControlsFace.irisStyle.identity.indigo
                onToggled: nayoriIrisControlsFace.notifications.toggleSilent()
            }
            Toggle {
                glyph: "nightlight"
                label: nayoriIrisControlsFace.translation.tr("Night light")
                available: nayoriIrisControlsFace.nightlight.available
                on: nayoriIrisControlsFace.nightlight.active
                tint: nayoriIrisControlsFace.irisStyle.identity.orange
                onToggled: nayoriIrisControlsFace.nightlight.toggle()
            }
            Toggle {
                visible: root.large
                glyph: "coffee"
                label: nayoriIrisControlsFace.translation.tr("Keep awake")
                on: nayoriIrisControlsFace.idle.inhibit
                tint: nayoriIrisControlsFace.irisStyle.identity.yellow
                onToggled: nayoriIrisControlsFace.idle.toggleInhibit()
            }
            Toggle {
                visible: root.large
                glyph: "sports_esports"
                label: nayoriIrisControlsFace.translation.tr("Game mode")
                on: nayoriIrisControlsFace.gameMode.active
                tint: nayoriIrisControlsFace.irisStyle.identity.green
                onToggled: nayoriIrisControlsFace.gameMode.toggle()
            }
            Toggle {
                visible: root.large
                glyph: nayoriIrisControlsFace.audio.micMuted ? "mic_off" : "mic"
                label: nayoriIrisControlsFace.translation.tr("Microphone")
                on: nayoriIrisControlsFace.audio.source !== null && !nayoriIrisControlsFace.audio.micMuted
                available: nayoriIrisControlsFace.audio.source !== null
                tint: nayoriIrisControlsFace.irisStyle.identity.orange
                onToggled: nayoriIrisControlsFace.audio.toggleMicMute()
            }
            Toggle {
                visible: root.large
                glyph: nayoriIrisControlsFace.appearance.m3colors.darkmode ? "dark_mode" : "light_mode"
                label: nayoriIrisControlsFace.translation.tr("Dark mode")
                on: nayoriIrisControlsFace.appearance.m3colors.darkmode
                tint: nayoriIrisControlsFace.irisStyle.identity.indigo
                onToggled: nayoriIrisControlsFace.appearance.toggleDarkMode()
            }
        }

        IrisCapsuleSlider {
            visible: !root.small
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            muted: nayoriIrisControlsFace.audio.sink?.audio?.muted ?? false
            icon: muted ? "volume_off" : (nayoriIrisControlsFace.audio.value ?? 0) < 0.34 ? "volume_mute" : (nayoriIrisControlsFace.audio.value ?? 0) < 0.67 ? "volume_down" : "volume_up"
            value: Math.min(1, nayoriIrisControlsFace.audio.value ?? 0)
            Accessible.name: nayoriIrisControlsFace.translation.tr("Volume")
            onMoved: next => nayoriIrisControlsFace.audio.setSinkVolume(next)
            onIconClicked: nayoriIrisControlsFace.audio.toggleMute()
        }
        IrisCapsuleSlider {
            visible: root.large && root.monitor !== null
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            icon: "light_mode"
            value: root.monitor?.brightness ?? 0
            Accessible.name: nayoriIrisControlsFace.translation.tr("Brightness")
            onMoved: next => root.monitor?.setBrightness(next)
        }

        Item { Layout.fillHeight: root.large; visible: root.large }
    }
}
