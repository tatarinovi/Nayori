pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

FocusScope {
    id: root
    property var wallpaperManager: null
    required property var tokens
    property int topReserved: 0
    property int bottomReserved: 0
    property bool hideSecondaryIsland: false
    signal hideSecondaryIslandChangedRequested(bool hidden)
    property bool autoHideTop: false
    property bool autoHideApps: false
    property bool autoHideWorkspaces: false
    property bool autoHideStatus: false
    property string userName: ""
    property string avatarSource: ""
    property string weatherCity: ""
    property int weatherRefreshMinutes: 15
    property bool animationsEnabled: true
    signal animationsChangedRequested(bool enabled)
    property string settingsMessage: ""
    property bool canRecover: false
    property bool canRetry: false
    signal recoverRequested()
    signal retryRequested()
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }
    property int currentPage: 0
    signal reservationChanged(int top, int bottom)
    signal autoHideChangedRequested(bool top, bool apps, bool workspaces, bool status)
    signal weatherCityChangedRequested(string city)
    signal weatherRefreshMinutesChangedRequested(int minutes)
    signal closeRequested()

    implicitWidth: 1100
    implicitHeight: 760
    readonly property bool compact: width < 960
    readonly property int inset: compact ? 24 : 32
    readonly property int sidebarWidth: compact ? 184 : 232
    // Stable IDs support future sections without exposing page indexes over IPC.
    readonly property var sections: [
        {key: "home", page: 0, title: "Главная", group: "Рабочее пространство", description: "Ваше пространство Nayori и быстрый доступ к настройкам."},
        {key: "panels", page: 1, title: "Панели", group: "Рабочее пространство", description: "Поведение островов и место для окон у краёв экрана."},
        {key: "appearance", page: 2, title: "Внешний вид", group: "Оформление", description: "Движение интерфейса и характер рабочего пространства."},
        {key: "wallpapers", page: 4, title: "Обои", group: "Оформление", description: "Фон рабочего стола — общий или отдельный для каждого монитора."},
        {key: "weather", page: 3, title: "Погода", group: "Информация", description: "Город для прогноза в Dynamic Island."}
    ]
    readonly property var section: sections.find(item => item.page === currentPage) || sections[0]
    function revealNavigation(item) {
        const flick = navigationScroll.contentItem
        const top = item.mapToItem(navigationColumn, 0, 0).y
        if (top < flick.contentY) flick.contentY = top
        else if (top + item.height > flick.contentY + flick.height)
            flick.contentY = top + item.height - flick.height
    }
    function focusInput() {
        const index = sections.findIndex(item => item.page === currentPage)
        const item = navigation.itemAt(Math.max(0, index))
        if (item) item.focusButton()
    }
    Keys.onEscapePressed: function(event) {
        event.accepted = true
        root.closeRequested()
    }

    Rectangle { anchors.fill: parent; color: root.tokens.color.background }
    Rectangle {
        id: sidebar
        width: root.sidebarWidth
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        color: Qt.tint(root.tokens.color.background, "#0CFFFFFF")
        Rectangle { anchors.right: parent.right; height: parent.height; width: 1; color: root.tokens.color.border }
        Column {
            id: identity
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 24 }
            spacing: 8
            Label {
                text: "Nayori"
                font.family: root.tokens.type.display.family
                font.pixelSize: 30
                color: root.tokens.color.text
            }
            Label { text: "НАСТРОЙКИ / 設定"; font.pixelSize: 11; font.letterSpacing: 1.3; color: root.tokens.color.accent }
        }
        ScrollView {
            id: navigationScroll
            anchors { top: identity.bottom; topMargin: 36; bottom: sidebarFooter.top; bottomMargin: 24; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16 }
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.active: true
            Column {
                id: navigationColumn
                width: navigationScroll.availableWidth
                spacing: 4
                Repeater {
                    id: navigation
                    model: root.sections
                    delegate: Column {
                        id: entry
                        required property var modelData
                        required property int index
                        width: parent.width
                        spacing: 8
                        function focusButton() { navButton.forceActiveFocus(Qt.TabFocusReason) }
                        Label {
                            visible: entry.index === 0 || root.sections[entry.index - 1].group !== entry.modelData.group
                            width: parent.width
                            topPadding: entry.index === 0 ? 0 : 24
                            leftPadding: 12
                            bottomPadding: 4
                            text: entry.modelData.group
                            color: root.tokens.color.textMuted
                            font.pixelSize: 12
                        }
                        Action {
                            id: navButton
                            objectName: "settings-nav-" + entry.modelData.key
                            width: parent.width
                            text: entry.modelData.title
                            selected: root.currentPage === entry.modelData.page
                            Accessible.selected: selected
                            onClicked: root.currentPage = entry.modelData.page
                            onActiveFocusChanged: if (activeFocus) root.revealNavigation(entry)
                            Keys.onDownPressed: navigation.itemAt((entry.index + 1) % root.sections.length).focusButton()
                            Keys.onUpPressed: navigation.itemAt((entry.index + root.sections.length - 1) % root.sections.length).focusButton()
                        }
                    }
                }
            }
        }
        Label {
            id: sidebarFooter
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 24 }
            visible: !root.compact
            height: root.compact ? 0 : implicitHeight
            text: "Ваше рабочее\nпространство"
            color: root.tokens.color.textMuted
            font.family: root.tokens.type.display.family
            font.pixelSize: 15
        }
    }

    Item {
        id: main
        anchors { top: parent.top; bottom: parent.bottom; left: sidebar.right; right: parent.right; margins: root.inset }
        Column {
            id: header
            width: parent.width
            spacing: 10
            Label { text: root.section.group.toUpperCase(); font.pixelSize: 11; font.letterSpacing: 1.4; color: root.tokens.color.accent }
            Label { width: parent.width; text: root.section.title; font.family: root.tokens.type.display.family; font.pixelSize: root.tokens.settings.heading }
            Label { width: parent.width; text: root.section.description; color: root.tokens.color.textMuted }
        }
        StackLayout {
            id: pages
            anchors { top: header.bottom; topMargin: 28; bottom: footer.top; bottomMargin: 20; left: parent.left; right: parent.right }
            currentIndex: root.currentPage
            ScrollView {
                id: homeScroll
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                HomePage {
                    width: Math.min(960, homeScroll.availableWidth - 12)
                    tokens: root.tokens
                    userName: root.userName
                    avatarSource: root.avatarSource
                    onPanelsRequested: root.currentPage = 1
                }
            }
            PanelsPage {
                Layout.maximumWidth: 960
                tokens: root.tokens
                showHeading: false
                topReserved: root.topReserved
                bottomReserved: root.bottomReserved
                hideSecondaryIsland: root.hideSecondaryIsland
                autoHideTop: root.autoHideTop
                autoHideApps: root.autoHideApps
                autoHideWorkspaces: root.autoHideWorkspaces
                autoHideStatus: root.autoHideStatus
                onReservationChanged: (top, bottom) => root.reservationChanged(top, bottom)
                onAutoHideChangedRequested: (top, apps, workspaces, status) => root.autoHideChangedRequested(top, apps, workspaces, status)
                onHideSecondaryIslandChangedRequested: hidden => root.hideSecondaryIslandChangedRequested(hidden)
            }
            ScrollView {
                id: appearanceScroll
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                AppearancePage {
                    width: Math.min(960, appearanceScroll.availableWidth - 12)
                    tokens: root.tokens
                    showHeading: false
                    animationsEnabled: root.animationsEnabled
                    onAnimationsChangedRequested: enabled => root.animationsChangedRequested(enabled)
                }
            }
            ScrollView {
                id: weatherScroll
                function reveal(item) {
                    const flick = contentItem
                    const point = item.mapToItem(flick.contentItem, 0, 0)
                    if (point.y < flick.contentY) flick.contentY = point.y
                    else if (point.y + item.height > flick.contentY + flick.height)
                        flick.contentY = point.y + item.height - flick.height
                }
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                WeatherPage {
                    width: Math.min(960, weatherScroll.availableWidth - 12)
                    tokens: root.tokens
                    showHeading: false
                    onRevealRequested: item => weatherScroll.reveal(item)
                    weatherCity: root.weatherCity
                    weatherRefreshMinutes: root.weatherRefreshMinutes
                    onWeatherCityChangedRequested: city => root.weatherCityChangedRequested(city)
                    onWeatherRefreshMinutesChangedRequested: minutes => root.weatherRefreshMinutesChangedRequested(minutes)
                }
            }
            WallpaperPage {
                Layout.maximumWidth: 960
                tokens: root.tokens
                showHeading: false
                manager: root.wallpaperManager
            }
        }
        Rectangle {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: statusRow.implicitHeight + 24
            color: "transparent"
            Rectangle { width: parent.width; height: 1; color: root.tokens.color.border }
            RowLayout {
                id: statusRow
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 16 }
                spacing: 12
                Label {
                    Layout.fillWidth: true
                    text: root.currentPage === 4 ? "Обои сохраняются после применения." : root.settingsMessage || "Изменения сохраняются автоматически."
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                    Accessible.role: Accessible.StaticText
                }
                Action {
                    visible: root.currentPage !== 4 && (root.canRecover || root.canRetry)
                    text: root.canRecover ? "Восстановить настройки" : "Повторить запись"
                    onClicked: root.canRecover ? root.recoverRequested() : root.retryRequested()
                }
            }
        }
    }
}
