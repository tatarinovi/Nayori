import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts
import Quickshell






IrisWidgetFace {
    readonly property var nayoriIrisProfileFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    readonly property string name: nayoriIrisProfileFace.systemInfo.displayName || nayoriIrisProfileFace.systemInfo.username || "user"
    readonly property string host: {
        const distro = String(nayoriIrisProfileFace.systemInfo.distroId ?? "").trim()
        const hostName = root.widget.showHostname ? String(nayoriIrisProfileFace.systemInfo.hostname ?? "") : ""
        return hostName.length > 0 ? hostName : distro.length > 0 && distro !== "unknown" ? distro : ""
    }
    readonly property string greeting: {
        const hour = nayoriIrisProfileFace.dateTime.clock.date.getHours()
        return hour < 5 ? nayoriIrisProfileFace.translation.tr("Good night")
            : hour < 12 ? nayoriIrisProfileFace.translation.tr("Good morning")
            : hour < 19 ? nayoriIrisProfileFace.translation.tr("Good afternoon") : nayoriIrisProfileFace.translation.tr("Good evening")
    }
    readonly property string uptime: nayoriIrisProfileFace.translation.tr("On for %1").arg(nayoriIrisProfileFace.dateTime.uptime || "--")

    component Actions: RowLayout {
        spacing: root.dp(6)
        FaceAction {
            face: root
            glyph: "lock"
            name: nayoriIrisProfileFace.translation.tr("Lock")
            onActivated: root.widget.lockScreen()
        }
        FaceAction {
            face: root
            glyph: "settings"
            name: nayoriIrisProfileFace.translation.tr("Settings")
            onActivated: nayoriIrisProfileFace.globalStates.openSettings()
        }
        FaceAction {
            face: root
            glyph: "power_settings_new"
            name: nayoriIrisProfileFace.translation.tr("Session")
            danger: true
            onActivated: nayoriIrisProfileFace.globalStates.sessionOpen = true
        }
    }

    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: root.dp(2)

        FaceAvatar {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.dp(64)
            Layout.preferredHeight: root.dp(64)
            visible: root.widget.showAvatar
        }
        Item { Layout.fillHeight: true }
        FaceText {
            face: root
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.name
            size: 15
            weight: Font.DemiBold
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.host.length > 0 ? root.host : root.uptime
            color: root.inkSecondary
            size: 12
        }
    }

    RowLayout {
        visible: !root.small
        anchors.fill: parent
        spacing: root.dp(16)

        FaceAvatar {
            visible: root.widget.showAvatar
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.dp(84)
            Layout.preferredHeight: root.dp(84)
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.greeting
                color: root.highlight
                size: 13
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.name
                size: 22
                weight: root.figureWeight
                font.family: nayoriIrisProfileFace.irisStyle.fontTitle
                font.letterSpacing: 0
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.host.length > 0 ? root.host + " · " + root.uptime : root.uptime
                color: root.inkSecondary
                size: 12
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.dp(6)
                MaterialSymbol {
                    visible: root.widget.showWeather && nayoriIrisProfileFace.weather.enabled
                    text: nayoriIrisProfileFace.icons.getWeatherIcon(nayoriIrisProfileFace.weather.data?.wCode, nayoriIrisProfileFace.weather.isNightNow()) ?? "cloud"
                    fill: 1
                    iconSize: root.px(16)
                    color: nayoriIrisProfileFace.irisStyle.skyLight(text)
                }
                FaceText {
                    face: root
                    visible: root.widget.showWeather && nayoriIrisProfileFace.weather.enabled
                    Layout.fillWidth: true
                    text: String(nayoriIrisProfileFace.weather.data?.temp ?? "")
                    color: root.inkSecondary
                    size: 12
                }
                Item { Layout.fillWidth: !(root.widget.showWeather && nayoriIrisProfileFace.weather.enabled) }
                Actions {}
            }
        }
    }
}
