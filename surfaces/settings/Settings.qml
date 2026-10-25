pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services/system"

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
    property bool islandRotationEnabled: true
    property int islandRotationSeconds: 15
    property string preferredTerminal: "kitty"
    property string preferredFileManager: "org.gnome.Nautilus"
    property var niri: null
    property bool animationsEnabled: true
    signal animationsChangedRequested(bool enabled)
    signal islandRotationEnabledChangedRequested(bool enabled)
    signal islandRotationSecondsChangedRequested(int seconds)
    signal preferredTerminalChangedRequested(string terminalId)
    signal preferredFileManagerChangedRequested(string fileManagerId)
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
        {key: "home", page: 0, title: "Главная", group: "Обзор", description: "Состояние сети, звука и быстрый переход к разделам"},
        {key: "display", page: 5, title: "Экран", group: "Система", description: "Подключённые мониторы. Режимы вывода niri отсюда не меняются"},
        {key: "sound", page: 6, title: "Звук", group: "Система", description: "Устройства вывода и ввода PipeWire и их громкость"},
        {key: "power", page: 7, title: "Питание", group: "Система", description: "Блокировка, завершение сеанса, перезагрузка и выключение"},
        {key: "network", page: 8, title: "Сеть", group: "Система", description: "Wi\u2011Fi, Ethernet и подключения NetworkManager"},
        {key: "localsend", page: 9, title: "LocalSend", group: "Система", description: "Запуск LocalSend, если приложение установлено"},
        {key: "bluetooth", page: 10, title: "Bluetooth", group: "Устройства", description: "Питание адаптера, поиск и подключение устройств"},
        {key: "mouse", page: 11, title: "Мышь", group: "Устройства", description: "Что можно прочитать о мыши в этой сессии niri"},
        {key: "keyboard", page: 12, title: "Клавиатура", group: "Устройства", description: "Раскладка и повтор, которые задаёт niri"},
        {key: "shortcuts", page: 13, title: "Сочетания клавиш", group: "Устройства", description: "Сочетания из конфигурации niri. Запись файла выключена"},
        {key: "wallpapers", page: 4, title: "Обои", group: "Персонализация", description: "Фон рабочего стола — общий или отдельный для каждого монитора"},
        {key: "panels", page: 1, title: "Панель задач", group: "Персонализация", description: "Автоскрытие островов и место для окон у краёв экрана"},
        {key: "start", page: 14, title: "Пуск", group: "Персонализация", description: "Терминал и файловый менеджер для кнопки «Пуск»"},
        {key: "island", page: 15, title: "Dynamic Island", group: "Персонализация", description: "Смена страниц острова, город и интервал погоды"},
        {key: "lockscreen", page: 16, title: "Экран блокировки", group: "Персонализация", description: "В Nayori нет своего экрана блокировки"},
        {key: "weather", page: 3, title: "Погода", group: "Персонализация", description: "Город для прогноза в Dynamic Island", sidebar: false},
        {key: "windows", page: 17, title: "Окна", group: "Окна и столы", description: "Фокус окон и ограничения конфигурации niri"},
        {key: "appearance", page: 2, title: "Анимации", group: "Окна и столы", description: "Движение лисы и переходы интерфейса"},
        {key: "alttab", page: 18, title: "Alt+Tab", group: "Окна и столы", description: "Переключение окон в этой сессии niri"},
        {key: "workspaces", page: 19, title: "Рабочие столы", group: "Окна и столы", description: "Столы, которые сейчас сообщает niri"},
        {key: "defaults", page: 20, title: "По умолчанию", group: "Приложения", description: "Приложения по умолчанию через xdg-mime"},
        {key: "autostart", page: 21, title: "Автозапуск", group: "Приложения", description: "Записи автозапуска пользователя и системы"},
        {key: "updates", page: 22, title: "Обновления", group: "NayoriOS", description: "Обновление пакетов в терминале, только по кнопке"},
        {key: "about", page: 23, title: "О системе", group: "NayoriOS", description: "Версии Nayori, niri, Quickshell и системы"}
    ]
    readonly property var navigationSections: sections.filter(item => item.sidebar !== false)
    readonly property var section: sections.find(item => item.page === currentPage) || sections[0]
    readonly property bool persistsSettings: {
        const key = section.key
        return key === "home" || key === "panels" || key === "appearance" || key === "weather" || key === "start" || key === "island"
    }
    property string navQuery: ""
    property var openGroupList: []
    property string navigatedGroup: ""
    readonly property string navQueryFolded: navQuery.trim().toLowerCase()
    readonly property bool navSearching: navQueryFolded !== ""
    readonly property bool navHasMatches: {
        if (!navSearching)
            return true
        const seen = []
        for (let i = 0; i < navigationSections.length; i++) {
            const group = navigationSections[i].group
            if (seen.indexOf(group) >= 0)
                continue
            seen.push(group)
            if (groupShown(group))
                return true
        }
        return false
    }
    function openKey(key) {
        const match = sections.find(item => item.key === key)
        if (!match)
            return
        currentPage = match.page
        expandForPage(match.page)
    }
    function expandForPage(page) {
        const item = sections.find(entry => entry.page === page)
        if (!item || item.sidebar === false)
            return
        navigatedGroup = item.group
        setGroupOpen(item.group, true)
    }
    function groupIsOpen(name) {
        return openGroupList.indexOf(name) >= 0
    }
    function setGroupOpen(name, open) {
        if (groupIsOpen(name) === open)
            return
        const next = []
        for (let i = 0; i < openGroupList.length; i++) {
            if (openGroupList[i] !== name)
                next.push(openGroupList[i])
        }
        if (open)
            next.push(name)
        openGroupList = next
    }
    function toggleGroup(name) {
        if (navSearching)
            return
        setGroupOpen(name, !groupIsOpen(name))
    }
    function collapseToNavigation() {
        const item = sections.find(entry => entry.page === currentPage && entry.sidebar !== false)
        openGroupList = item && item.group === navigatedGroup ? [navigatedGroup] : []
    }
    function queryHit(text) {
        return navQueryFolded !== "" && String(text || "").toLowerCase().indexOf(navQueryFolded) >= 0
    }
    function groupShown(group) {
        if (!navSearching)
            return true
        if (queryHit(group))
            return true
        return navigationSections.some(item => item.group === group && (queryHit(item.title) || queryHit(item.description)))
    }
    function pageVisible(item) {
        if (!item)
            return false
        if (!navSearching)
            return groupIsOpen(item.group)
        if (queryHit(item.group))
            return true
        return queryHit(item.title) || queryHit(item.description)
    }
    function isFirstShownGroup(index) {
        const group = navigationSections[index].group
        for (let i = 0; i < index; i++) {
            if (navigationSections[i].group !== group && groupShown(navigationSections[i].group))
                return false
        }
        return true
    }
    function revealNavigation(item) {
        const flick = navigationScroll.contentItem
        const top = item.mapToItem(navigationColumn, 0, 0).y
        if (top < flick.contentY) flick.contentY = top
        else if (top + item.height > flick.contentY + flick.height)
            flick.contentY = top + item.height - flick.height
    }
    function focusNav(index) {
        const data = navigationSections[index]
        if (!data)
            return
        if (!pageVisible(data))
            setGroupOpen(data.group, true)
        const item = navigation.itemAt(index)
        if (item)
            item.focusButton()
    }
    function focusInput() {
        const index = navigationSections.findIndex(item => item.page === currentPage)
        if (index < 0)
            return
        const item = navigation.itemAt(index)
        if (item && item.shownPage)
            item.focusButton()
    }
    function adjacentNav(from, direction) {
        const count = navigationSections.length
        if (count === 0)
            return from
        if (!navSearching)
            return (from + direction + count) % count
        for (let step = 1; step <= count; step++) {
            const index = (from + direction * step + count) % count
            if (pageVisible(navigationSections[index]))
                return index
        }
        return from
    }
    onCurrentPageChanged: expandForPage(currentPage)
    onNavQueryChanged: {
        if (navQuery.trim() === "")
            collapseToNavigation()
    }
    Keys.onEscapePressed: function(event) {
        event.accepted = true
        root.closeRequested()
    }

    NiriConfigView { id: niriConfig }

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
        SettingsField {
            id: navSearch
            objectName: "settings-search"
            anchors { top: identity.bottom; topMargin: 16; left: parent.left; leftMargin: 16 }
            width: sidebar.width - 32
            tokens: root.tokens
            placeholderText: "Поиск"
            Accessible.name: "Поиск"
            onTextEdited: root.navQuery = text
            Keys.onEscapePressed: function(event) {
                if (text !== "") {
                    text = ""
                    root.navQuery = ""
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }
        }
        ScrollView {
            id: navigationScroll
            anchors { top: navSearch.bottom; topMargin: 12; bottom: sidebarFooter.top; bottomMargin: 24; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16 }
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.active: true
            Column {
                id: navigationColumn
                width: navigationScroll.availableWidth
                spacing: 0
                Label {
                    visible: root.navSearching && !root.navHasMatches
                    width: parent.width
                    leftPadding: 12
                    text: "Ничего не найдено"
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                }
                Repeater {
                    id: navigation
                    model: root.navigationSections
                    delegate: Column {
                        id: entry
                        required property var modelData
                        required property int index
                        readonly property bool groupStart: index === 0 || root.navigationSections[index - 1].group !== modelData.group
                        readonly property bool shownGroup: root.groupShown(modelData.group)
                        readonly property bool shownPage: root.pageVisible(modelData)
                        readonly property bool currentGroup: root.section.group === modelData.group
                        width: parent.width
                        spacing: 0
                        visible: shownGroup
                        function focusButton() { navButton.forceActiveFocus(Qt.TabFocusReason) }
                        Item {
                            visible: entry.groupStart
                            width: parent.width
                            height: entry.groupStart ? leadingSpace + groupButton.height : 0
                            readonly property int leadingSpace: entry.groupStart && !root.isFirstShownGroup(entry.index) ? 18 : 0
                            AbstractButton {
                                id: groupButton
                                y: parent.leadingSpace
                                width: parent.width
                                height: 32
                                hoverEnabled: true
                                Accessible.name: entry.modelData.group
                                onClicked: root.toggleGroup(entry.modelData.group)
                                background: Rectangle {
                                    radius: root.tokens.radius.small
                                    color: groupButton.down || groupButton.hovered ? root.tokens.color.surfaceAlt : "transparent"
                                    border.width: groupButton.visualFocus ? 1 : 0
                                    border.color: root.tokens.color.accent
                                }
                                contentItem: Label {
                                    text: entry.modelData.group
                                    color: entry.currentGroup ? root.tokens.color.accent : root.tokens.color.textMuted
                                    font.pixelSize: 12
                                    leftPadding: 12
                                    rightPadding: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }
                            }
                        }
                        Item {
                            width: parent.width
                            height: entry.shownPage ? navButton.implicitHeight + 4 : 0
                            clip: true
                            Action {
                                id: navButton
                                objectName: "settings-nav-" + entry.modelData.key
                                width: parent.width
                                text: entry.modelData.title
                                focusPolicy: entry.shownPage ? Qt.StrongFocus : Qt.NoFocus
                                selected: root.currentPage === entry.modelData.page
                                Accessible.selected: selected
                                Accessible.ignored: !entry.shownPage
                                onClicked: root.openKey(entry.modelData.key)
                                onActiveFocusChanged: if (activeFocus) root.revealNavigation(entry)
                                Keys.onDownPressed: function(event) {
                                    event.accepted = true
                                    root.focusNav(root.adjacentNav(entry.index, 1))
                                }
                                Keys.onUpPressed: function(event) {
                                    event.accepted = true
                                    root.focusNav(root.adjacentNav(entry.index, -1))
                                }
                            }
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
                    onPanelsRequested: root.openKey("panels")
                    onNetworkRequested: root.openKey("network")
                    onBluetoothRequested: root.openKey("bluetooth")
                    onUpdatesRequested: root.openKey("updates")
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
            SettingsScroll { DisplayPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll { SoundPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll { PowerPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll { NetworkPage { width: parent.width; tokens: root.tokens; scanning: root.currentPage === 8 } }
            SettingsScroll { LocalSendPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll { BluetoothPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll { MousePage { width: parent.width; tokens: root.tokens; niriConfig: niriConfig } }
            SettingsScroll { KeyboardPage { width: parent.width; tokens: root.tokens; niriConfig: niriConfig } }
            SettingsScroll { ShortcutsPage { width: parent.width; tokens: root.tokens; niriConfig: niriConfig } }
            SettingsScroll {
                StartPage {
                    width: parent.width
                    tokens: root.tokens
                    preferredTerminal: root.preferredTerminal
                    preferredFileManager: root.preferredFileManager
                    onPreferredTerminalChangedRequested: terminalId => root.preferredTerminalChangedRequested(terminalId)
                    onPreferredFileManagerChangedRequested: fileManagerId => root.preferredFileManagerChangedRequested(fileManagerId)
                }
            }
            SettingsScroll {
                IslandPage {
                    width: parent.width
                    tokens: root.tokens
                    islandRotationEnabled: root.islandRotationEnabled
                    islandRotationSeconds: root.islandRotationSeconds
                    weatherCity: root.weatherCity
                    weatherRefreshMinutes: root.weatherRefreshMinutes
                    onIslandRotationEnabledChangedRequested: enabled => root.islandRotationEnabledChangedRequested(enabled)
                    onIslandRotationSecondsChangedRequested: seconds => root.islandRotationSecondsChangedRequested(seconds)
                    onWeatherCityChangedRequested: city => root.weatherCityChangedRequested(city)
                    onWeatherRefreshMinutesChangedRequested: minutes => root.weatherRefreshMinutesChangedRequested(minutes)
                }
            }
            SettingsScroll { LockScreenPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll {
                WindowsPage {
                    width: parent.width
                    tokens: root.tokens
                    niri: root.niri
                    niriConfig: niriConfig
                    animationsEnabled: root.animationsEnabled
                    onAnimationsRequested: root.openKey("appearance")
                    onAnimationsChangedRequested: enabled => root.animationsChangedRequested(enabled)
                }
            }
            SettingsScroll { AltTabPage { width: parent.width; tokens: root.tokens; niriConfig: niriConfig } }
            SettingsScroll { WorkspacesPage { width: parent.width; tokens: root.tokens; niri: root.niri } }
            SettingsScroll { DefaultsPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll { AutostartPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll { UpdatesPage { width: parent.width; tokens: root.tokens; preferredTerminal: root.preferredTerminal } }
            SettingsScroll { AboutPage { width: parent.width; tokens: root.tokens } }
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
                    text: root.currentPage === 4 ? "Обои сохраняются после применения."
                          : root.settingsMessage ? root.settingsMessage
                          : root.persistsSettings ? "Изменения сохраняются автоматически." : ""
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
