pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

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
    signal closeRequested()

    implicitWidth: 700
    implicitHeight: currentPage === 4 ? 740 : 420
    width: implicitWidth
    height: implicitHeight

    function focusInput() { homeButton.forceActiveFocus(Qt.TabFocusReason) }
    Keys.onEscapePressed: function(event) {
        event.accepted = true
        root.closeRequested()
    }







    RectangularShadow {
        anchors.fill: chrome
        radius: chrome.radius
        blur: 16
        offset: Qt.vector2d(0, 6)
        color: root.tokens.color.shadow
    }
    Rectangle {
        id: chrome
        anchors.fill: parent
        radius: root.tokens.radius.medium
        color: root.tokens.color.background
        border.width: 1
        border.color: root.tokens.color.border
    }

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 24 }
        height: 36
        Label {
            text: "Настройки"
            anchors.verticalCenter: parent.verticalCenter
            font.family: root.tokens.type.display.family
            font.pixelSize: 24
            font.letterSpacing: root.tokens.type.display.letterSpacing
        }
        Action {
            text: "×"
            anchors.right: parent.right
            width: 36
            height: 36
            implicitWidth: 36
            Accessible.name: "Закрыть настройки"
            onClicked: root.closeRequested()
        }
    }

    Column {
        id: navigation
        anchors { left: parent.left; top: header.bottom; topMargin: 24; leftMargin: 24 }
        width: root.width < 600 ? 132 : 158
        spacing: 4
        Action { id: homeButton; width: parent.width; text: "Главная"; selected: root.currentPage === 0; onClicked: root.currentPage = 0 }
        Action { width: parent.width; text: "Панели"; selected: root.currentPage === 1; onClicked: root.currentPage = 1 }
        Action { width: parent.width; text: "Внешний вид"; selected: root.currentPage === 2; onClicked: root.currentPage = 2 }
        Action { width: parent.width; text: "Обои"; selected: root.currentPage === 4; onClicked: root.currentPage = 4 }
        Action { width: parent.width; text: "Погода"; selected: root.currentPage === 3; onClicked: root.currentPage = 3 }
    }

    Rectangle {
        anchors { left: navigation.right; leftMargin: 16; top: navigation.top; bottom: footer.top; bottomMargin: 20 }
        width: 1
        color: root.tokens.color.surfaceAlt
    }

    StackLayout {
        id: pages
        anchors { left: navigation.right; leftMargin: 36; top: navigation.top; right: parent.right; rightMargin: 24; bottom: footer.top; bottomMargin: 24 }
        currentIndex: root.currentPage

        HomePage {
            tokens: root.tokens
            userName: root.userName
            avatarSource: root.avatarSource
            onPanelsRequested: root.currentPage = 1
        }
        PanelsPage {
            tokens: root.tokens
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
        AppearancePage {
            tokens: root.tokens
            animationsEnabled: root.animationsEnabled
            onAnimationsChangedRequested: enabled => root.animationsChangedRequested(enabled)
        }
        WeatherPage {
            tokens: root.tokens
            weatherCity: root.weatherCity
            onWeatherCityChangedRequested: city => root.weatherCityChangedRequested(city)
        }
        WallpaperPage {
            tokens: root.tokens
            manager: root.wallpaperManager
        }
    }

    Label {
        id: footer
        anchors { left: pages.left; right: pages.right; bottom: parent.bottom; bottomMargin: 24 }
        text: root.currentPage === 4 ? "Обои сохраняются после применения." : root.settingsMessage || "Изменения сохраняются автоматически."
        maximumLineCount: 1
        elide: Text.ElideRight
        Accessible.description: text
        ToolTip.visible: footerHover.hovered && truncated
        ToolTip.text: text
        HoverHandler { id: footerHover }
        rightPadding: recovery.visible ? recovery.width + 8 : 0
        Action {
            id: recovery
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.currentPage !== 4 && (root.canRecover || root.canRetry)
            text: root.canRecover ? "Восстановить настройки" : "Повторить запись"
            onClicked: root.canRecover ? root.recoverRequested() : root.retryRequested()
        }
        color: root.tokens.color.textMuted
        font.pixelSize: 12
    }
}
