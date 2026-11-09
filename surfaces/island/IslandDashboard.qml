pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris

FocusScope {
    id: root
    required property var tokens
    property bool testMode: false
    property var testPlayers: []
    property var musicService: null
    property var systemUpdateService: null
    readonly property bool popupOpen: musicCard.popupOpen
    function closePopups() { musicCard.closePopups() }
    property var selectedPlayer: null
    property var notifications: null
    property var shelfService: null
    readonly property bool shelfInteracting: shelfView.interacting
    property int currentPage: 0
    readonly property int pageCount: 3
    property real pagePosition: currentPage
    property real wheelDelta: 0
    property double lastPageWheel: 0
    function navigateWheel(delta, now) {
        if (!delta || now - lastPageWheel < tokens.motion.base) return
        if (wheelDelta * delta < 0) wheelDelta = 0
        wheelDelta += delta
        if (Math.abs(wheelDelta) < 120) return
        const next = Math.max(0, Math.min(pageCount - 1, currentPage + (wheelDelta < 0 ? 1 : -1)))
        wheelDelta = 0
        if (next !== currentPage) { currentPage = next; lastPageWheel = now }
    }
    Behavior on pagePosition {
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.base
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.77, 0, 0.175, 1, 1, 1]
        }
    }
    function wheelAmount(event) {
        return event.angleDelta.y || event.pixelDelta.y * 3
    }
    property bool drawChrome: true
    property bool showDate: true
    property int topInset: 16
    signal closeRequested()
    signal settingsRequested()
    implicitWidth: 680
    implicitHeight: 450
    property date now: new Date()
    property var calendarService: null
    readonly property var players: musicService ? musicService.players : testMode ? testPlayers : Mpris.players.values
    readonly property var player: {
        if (musicService) return musicService.player
        if (selectedPlayer && players.indexOf(selectedPlayer) >= 0) return selectedPlayer
        for (let i = 0; i < players.length; i++) if (players[i].isPlaying) return players[i]
        return players.length ? players[0] : null
    }
    property var weather: null
    property string weatherError: ""
    property string weatherCity: ""
    property bool weatherLoading: false
    signal weatherRefreshRequested()
    readonly property var ru: Qt.locale("ru_RU")
    readonly property string weatherScene: {
        if (!weather) return "cloudy"
        const code = Number(weather.weatherCode)
        if ([200, 386, 389, 392, 395].indexOf(code) >= 0) return "storm"
        if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].indexOf(code) >= 0) return "snow"
        if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].indexOf(code) >= 0) return "rain"
        if ([143, 248, 260].indexOf(code) >= 0) return "fog"
        return code === 113 ? "clear" : "cloudy"
    }
    readonly property url weatherArtwork: Qt.resolvedUrl("../../assets/weather/" + weatherScene + ".png")
    readonly property string weatherDescription: {
        if (!weather) return ""
        return ({clear: "Ясно", cloudy: "Облачно", rain: "Дождь", snow: "Снег", storm: "Гроза", fog: "Туман"})[weatherScene]
    }
    Keys.onEscapePressed: function(event) { event.accepted = true; if (root.currentPage !== 0 || !calendarPane.back()) root.closeRequested() }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = new Date() }
    component Label: IslandLabel { tokens: root.tokens }
    component Caption: Label {
        font.pixelSize: 12
        color: root.tokens.color.textMuted
    }
    component Heading: Label {
        font.family: root.tokens.type.display.family
        font.pixelSize: 22
        font.weight: Font.Medium
        font.letterSpacing: -0.35
    }
    component Action: IslandAction { tokens: root.tokens }
    component Card: IslandCard { tokens: root.tokens }
    Rectangle {
        visible: root.drawChrome
        anchors.fill: parent
        radius: 28
        color: root.tokens.material.islandExpanded
        border.width: 1
        border.color: root.tokens.color.border
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.tokens.spacing.medium
        anchors.topMargin: root.topInset
        spacing: 12
        RowLayout {
            id: pageNavigation
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                orientation: Qt.Horizontal
                target: null
                onWheel: event => {
                    root.navigateWheel(event.angleDelta.x || event.pixelDelta.x * 3, Date.now())
                    event.accepted = true
                }
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                target: null
                onWheel: event => {
                    root.navigateWheel(root.wheelAmount(event), Date.now())
                    event.accepted = true
                }
            }
            Layout.fillWidth: true
            spacing: 16
            Repeater {
                id: pageTabs
                property int layoutRevision: 0
                onItemAdded: layoutRevision++
                model: ["Главная", "Уведомления", "Полка"]
                delegate: AbstractButton {
                    id: pageTab
                    objectName: "islandPageTab" + index
                    required property int index
                    required property string modelData
                    text: modelData + (index === 1 && root.notifications && root.notifications.unreadCount ? " · " + root.notifications.unreadCount : "")
                    implicitWidth: contentItem.implicitWidth
                    implicitHeight: 36
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: text
                    Accessible.role: Accessible.PageTab
                    Accessible.selected: root.currentPage === index
                    onClicked: root.currentPage = index
                    Keys.onLeftPressed: root.currentPage = Math.max(0, root.currentPage - 1)
                    Keys.onRightPressed: root.currentPage = Math.min(root.pageCount - 1, root.currentPage + 1)
                    background: Rectangle {
                        color: "transparent"
                        border.width: pageTab.visualFocus ? 1 : 0
                        border.color: root.tokens.color.accent
                        radius: root.tokens.radius.small
                    }
                    contentItem: Heading {
                        text: pageTab.text
                        font.pixelSize: 20
                        color: root.tokens.color.text
                        opacity: root.currentPage === pageTab.index ? 1 : 0.5
                        Behavior on opacity {
                            NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast }
                        }
                        verticalAlignment: Text.AlignVCenter
                    }
                    Rectangle {
                        id: pageIndicator
                        objectName: pageTab.index === 0 ? "islandPageIndicator" : ""
                        visible: pageTab.index === 0
                        width: 24; height: 2; radius: 1
                        y: pageTab.height - height
                        color: root.tokens.color.accent
                        transform: Translate {
                            x: {
                                if (pageTabs.layoutRevision < root.pageCount) return 0
                                const position = Math.max(0, Math.min(root.pageCount - 1, root.pagePosition))
                                if (position === 0 && pageTab.index === 0) return (pageTab.width - pageIndicator.width) / 2
                                const first = pageTabs.itemAt(Math.floor(position))
                                const second = pageTabs.itemAt(Math.ceil(position))
                                if (!first || !second) return 0
                                const start = first.x - pageTab.x + (first.width - pageIndicator.width) / 2
                                const end = second.x - pageTab.x + (second.width - pageIndicator.width) / 2
                                return start + (end - start) * (position - Math.floor(position))
                            }
                        }
                    }
                }
            }
            Item { Layout.fillWidth: true }
            Caption { visible: root.showDate; text: root.ru.toString(root.now, "dddd, d MMMM") }
        }
        Caption {
            objectName: "islandExpandedUpdateStatus"
            Layout.fillWidth: true
            visible: !!root.systemUpdateService && root.systemUpdateService.busy
            text: root.systemUpdateService ? root.systemUpdateService.status : ""
            elide: Text.ElideRight
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(root.tokens.color.border, 0.5) }
        Item {
            id: pageViewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Item {
                x: -root.pagePosition * pageViewport.width
                width: pageViewport.width; height: pageViewport.height
                visible: root.pagePosition < 1
                enabled: root.currentPage === 0
                RowLayout {
                    anchors.fill: parent
                    spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                MusicCard {
                    id: musicCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 180
                    tokens: root.tokens
                    player: root.player
                    players: root.players
                    lyrics: root.musicService ? root.musicService.lyrics : null
                    onPlayerSelected: selected => {
                        if (root.musicService) root.musicService.selectPlayer(selected)
                        else root.selectedPlayer = selected
                    }
                }
                Card {
                    id: weatherCard
                    objectName: "weatherCard"
                    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    Item {
                        id: weatherBackdrop
                        objectName: "weatherBackdrop"
                        anchors.fill: parent
                        layer.enabled: !weatherCard.softwareRendering
                        layer.effect: MultiEffect { maskEnabled: true; maskSource: weatherMask }
                        Image {
                            id: weatherIllustration
                            objectName: "weatherIllustration"
                            anchors.fill: parent
                            source: root.weather && !root.weatherError ? root.weatherArtwork : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: 0.9
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.alpha(root.tokens.color.background, 0.72)
                        }
                    }
                    Rectangle {
                        id: weatherMask
                        anchors.fill: parent
                        radius: weatherCard.radius
                        color: "white"
                        layer.enabled: true
                        visible: false
                    }
                    // Shader effects are unavailable in the software renderer.
                    Repeater {
                        model: weatherCard.softwareRendering ? 4 : 0
                        Canvas {
                            required property int index
                            width: weatherCard.radius
                            height: width
                            x: index === 1 || index === 2 ? weatherCard.width - width : 0
                            y: index >= 2 ? weatherCard.height - height : 0
                            rotation: index * 90
                            property color cornerColor: root.tokens.color.background
                            onCornerColorChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.fillStyle = cornerColor
                                ctx.beginPath()
                                ctx.moveTo(0, 0)
                                ctx.lineTo(width, 0)
                                ctx.arc(width, height, width, -Math.PI / 2, -Math.PI, true)
                                ctx.closePath()
                                ctx.fill()
                            }
                        }
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Caption { text: "Погода"; Layout.fillWidth: true }
                            Caption { text: root.weather && !root.weatherError ? root.weatherDescription : "" }
                        }
                        RowLayout {
                            visible: root.weather !== null && !root.weatherError
                            Layout.fillWidth: true
                            Heading { text: root.weather ? root.weather.temp_C + "°" : ""; font.pixelSize: 38 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label { text: root.weatherCity; Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight }
                                Caption { text: root.weather ? "Ощущается как " + root.weather.FeelsLikeC + "°" : ""; Layout.fillWidth: true }
                            }
                        }
                        Caption {
                            visible: !root.weather || !!root.weatherError
                            Layout.fillWidth: true
                            text: root.weatherError || (root.weatherLoading ? "Обновляем погоду…" : root.weatherCity.trim() ? root.weatherCity : "Укажите город в настройках")
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Action { visible: root.weatherCity.trim().length === 0; Layout.fillWidth: true; text: "Выбрать город"; onClicked: root.settingsRequested() }
                            Item { visible: root.weatherCity.trim().length > 0; Layout.fillWidth: true }
                            Action { visible: root.weatherCity.trim().length > 0; text: "↻"; Accessible.name: "Обновить погоду"; enabled: !root.weatherLoading; onClicked: root.weatherRefreshRequested() }
                        }
                        Caption { text: "wttr.in · запрос по названию города"; font.pixelSize: 11 }
                    }
                }
            }
            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Qt.alpha(root.tokens.color.border, 0.4) }
            CalendarPane {
                id: calendarPane
                Layout.preferredWidth: 278
                Layout.fillHeight: true
                tokens: root.tokens
                service: root.calendarService
                now: root.now
            }
                }
            }
            NotificationPage {
                id: notificationsView
                x: (1 - root.pagePosition) * pageViewport.width
                width: pageViewport.width; height: pageViewport.height
                visible: root.pagePosition > 0 && root.pagePosition < 2
                enabled: root.currentPage === 1
                tokens: root.tokens
                notifications: root.notifications
                onCloseRequested: root.closeRequested()
            }
            ShelfPage {
                id: shelfView
                objectName: "shelfPage"
                x: (2 - root.pagePosition) * pageViewport.width
                width: pageViewport.width; height: pageViewport.height
                visible: root.pagePosition > 1
                enabled: root.currentPage === 2
                tokens: root.tokens
                store: root.shelfService
            }
        }
    }
}
