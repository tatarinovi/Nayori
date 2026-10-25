pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../../services/status"
import "../../services/system"
import "../panel"

Column {
    id: root
    required property var tokens
    property string userName: ""
    property string avatarSource: ""
    property url wallpaperSource
    property var frequentSections: []
    signal sectionRequested(string key)
    signal revealRequested(var item)
    readonly property bool wide: width >= 780
    readonly property var battery: UPower.displayDevice
    readonly property bool batteryReady: battery && battery.ready && battery.isPresent
    readonly property string networkTitle: !network.available ? "Сеть недоступна"
        : network.label === "wifi" ? "Wi-Fi"
        : network.label === "lan" ? "Ethernet"
        : network.linked ? "Сеть" : "Нет подключения"
    readonly property string networkDetail: !network.available ? "Открыть настройки сети"
        : network.label === "portal" ? "Нужна авторизация"
        : network.label === "limited" ? "Подключение ограничено"
        : network.linked ? "Подключено" : "Выбрать подключение"
    readonly property string audioTitle: audio.available
        ? (audio.sink.description || audio.sink.name || "Звук") : "Звук недоступен"
    readonly property string audioDetail: !audio.available ? "Открыть настройки звука"
        : audio.muted ? "Без звука" : "Громкость " + Math.round(Math.max(0, Math.min(1, audio.level)) * 100) + "%"
    readonly property string powerTitle: batteryReady
        ? Math.round(Math.max(0, Math.min(1, battery.percentage)) * 100) + "%" : "Питание"
    readonly property string powerDetail: batteryReady
        ? (UPower.onBattery ? "От батареи" : "Подключено к сети") : battery && battery.ready ? "От сети · без батареи" : "Сведения о питании недоступны"
    spacing: 16
    component Label: SettingsLabel { tokens: root.tokens }
    Network { id: network }
    Audio { id: audio }
    SystemInfo { id: info }

    Item {
        width: parent.width
        height: 56
        UserAvatar {
            id: avatar
            width: 56; height: 56
            tokens: root.tokens
            source: root.avatarSource
            username: root.userName || "N"
        }
        Column {
            anchors { left: avatar.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 2
            Label {
                width: parent.width
                text: root.userName || "Nayori"
                font.family: root.tokens.type.display.family
                font.pixelSize: 22
                elide: Text.ElideRight; wrapMode: Text.NoWrap
            }
            Label { width: parent.width; text: info.osName || "Nayori"; color: root.tokens.color.textMuted; font.pixelSize: 12 }
        }
    }

    GridLayout {
        width: parent.width
        columns: root.wide ? 2 : 1
        columnSpacing: 18
        rowSpacing: 16
        Rectangle {
            id: quickArea
            objectName: "home-customization-banner"
            Layout.fillWidth: true
            Layout.preferredWidth: root.width * 0.65
            implicitHeight: Math.max(240, quickContent.implicitHeight + 32)
            radius: root.tokens.radius.medium
            color: root.tokens.material.sidebar
            HomeArtwork { anchors.fill: parent; source: root.wallpaperSource; cornerRadius: parent.radius; opacity: 0.65 }
            Rectangle {
                anchors.fill: parent; radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.tokens.color.background }
                    GradientStop { position: 1; color: Qt.alpha(root.tokens.color.background, 0.28) }
                }
            }
            Rectangle {
                anchors.fill: parent; radius: parent.radius; color: "transparent"
                border.width: 1; border.color: root.tokens.color.border
            }
            Column {
                id: quickContent
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 8
                Label {
                    width: parent.width
                    text: "Всё под рукой"
                    font.family: root.tokens.type.display.family
                    font.pixelSize: 24
                    color: root.tokens.color.accent
                }
                Label {
                    width: parent.width
                    text: "Настройте пространство под себя"
                    color: root.tokens.color.textMuted
                    font.pixelSize: 12
                }
                GridLayout {
                    width: parent.width
                    columns: 2
                    rowSpacing: 10; columnSpacing: 10
                    Repeater {
                        model: [
                            {key: "wallpapers", title: "Обои", glyph: "wallpapers"},
                            {key: "appearance", title: "Внешний вид", glyph: "appearance"},
                            {key: "panels", title: "Панель задач", glyph: "panels"},
                            {key: "island", title: "Dynamic Island", glyph: "island"}
                        ]
                        HomeLink {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            minimumHeight: 64
                            tokens: root.tokens
                            compact: true
                            objectName: "home-quick-" + modelData.key
                            title: modelData.title
                            glyph: modelData.glyph
                            onClicked: root.sectionRequested(modelData.key)
                            onRevealRequested: item => root.revealRequested(item)
                        }
                    }
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: root.width * 0.35
            columns: 1
            rowSpacing: 10
            HomeStatus {
                Layout.fillWidth: true
                implicitHeight: (quickArea.implicitHeight - 20) / 3
                tokens: root.tokens
                objectName: "home-status-network"
                title: root.networkTitle; detail: root.networkDetail
                glyph: "network"
                onClicked: root.sectionRequested("network")
                onRevealRequested: item => root.revealRequested(item)
            }
            HomeStatus {
                Layout.fillWidth: true
                implicitHeight: (quickArea.implicitHeight - 20) / 3
                tokens: root.tokens
                objectName: "home-status-sound"
                title: root.audioTitle; detail: root.audioDetail
                glyph: "sound"
                onClicked: root.sectionRequested("sound")
                onRevealRequested: item => root.revealRequested(item)
            }
            HomeStatus {
                Layout.fillWidth: true
                implicitHeight: (quickArea.implicitHeight - 20) / 3
                tokens: root.tokens
                objectName: "home-status-power"
                title: root.powerTitle; detail: root.powerDetail
                glyph: "power"
                onClicked: root.sectionRequested("power")
                onRevealRequested: item => root.revealRequested(item)
            }
        }
    }

    Column {
        width: parent.width
        spacing: 12
        Label {
            text: "Часто открываемые"
            font.family: root.tokens.type.display.family
            font.pixelSize: 22
        }
        Label {
            objectName: "home-history-empty"
            width: parent.width
            visible: root.frequentSections.length === 0
            text: "Здесь появятся разделы, которые вы открываете чаще всего."
            color: root.tokens.color.textMuted
            font.pixelSize: 13
        }
        GridLayout {
            width: parent.width
            columns: root.width >= 860 ? 4 : 2
            rowSpacing: 10; columnSpacing: 10
            Repeater {
                model: root.frequentSections
                HomeLink {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    tokens: root.tokens
                    minimumHeight: 76
                    padding: 14
                    objectName: "home-frequent-" + modelData.key
                    title: modelData.title
                    glyph: modelData.glyph
                    onClicked: root.sectionRequested(modelData.key)
                    onRevealRequested: item => root.revealRequested(item)
                }
            }
        }
    }
}
