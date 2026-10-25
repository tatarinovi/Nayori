pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

ScrollView {
    required property var tokens
    property int topReserved: 0
    property int bottomReserved: 0
    property bool hideSecondaryIsland: false
    property bool autoHideTop: false
    property bool autoHideApps: false
    property bool autoHideWorkspaces: false
    property bool autoHideStatus: false
    signal reservationChanged(int top, int bottom)
    signal autoHideChangedRequested(bool top, bool apps, bool workspaces, bool status)
    signal hideSecondaryIslandChangedRequested(bool hidden)
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }
    component ReservationControl: SettingsReservationControl { tokens: root.tokens }
            id: root
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 6
                x: root.width - width
                y: 0
                height: root.height
                active: true
                contentItem: Rectangle {
                    implicitWidth: 4
                    implicitHeight: 32
                    radius: 2
                    color: root.tokens.color.accentSoft
                }
            }
            function reveal(item) {
                const point = item.mapToItem(panelsColumn, 0, 0)
                const view = panelsFlick
                if (point.y < view.contentY)
                    view.contentY = point.y
                else if (point.y + item.height > view.contentY + view.height)
                    view.contentY = point.y + item.height - view.height
            }
            Flickable {
                id: panelsFlick
                contentWidth: width
                contentHeight: panelsColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
            Column {
                id: panelsColumn
                width: root.availableWidth - 12
                spacing: 12
                Label { text: "Панели"; font.family: root.tokens.type.display.family; font.pixelSize: 20 }
                Label { width: parent.width; text: "Остров скрывается при пересечении с окном. Наведите указатель на край экрана, чтобы показать его. Если Niri не передаёт положение окна, действует обычное автоскрытие."; color: root.tokens.color.textMuted; font.pixelSize: 13 }
                SettingsToggle {
                    tokens: root.tokens
                    text: "Скрывать верхний остров"
                    checked: root.autoHideTop
                    onClicked: root.autoHideChangedRequested(checked, root.autoHideApps, root.autoHideWorkspaces, root.autoHideStatus)
                    onFocusReceived: root.reveal(this)
                }
                SettingsToggle {
                    tokens: root.tokens
                    text: "Скрывать док приложений"
                    checked: root.autoHideApps
                    onClicked: root.autoHideChangedRequested(root.autoHideTop, checked, root.autoHideWorkspaces, root.autoHideStatus)
                    onFocusReceived: root.reveal(this)
                }
                SettingsToggle {
                    tokens: root.tokens
                    text: "Скрывать рабочие столы"
                    checked: root.autoHideWorkspaces
                    onClicked: root.autoHideChangedRequested(root.autoHideTop, root.autoHideApps, checked, root.autoHideStatus)
                    onFocusReceived: root.reveal(this)
                }
                SettingsToggle {
                    tokens: root.tokens
                    text: "Скрывать системный остров"
                    checked: root.autoHideStatus
                    onClicked: root.autoHideChangedRequested(root.autoHideTop, root.autoHideApps, root.autoHideWorkspaces, checked)
                    onFocusReceived: root.reveal(this)
                }
                SettingsToggle {
                    tokens: root.tokens
                    text: "Скрыть Dynamic Island на втором мониторе"
                    checked: root.hideSecondaryIsland
                    onClicked: root.hideSecondaryIslandChangedRequested(checked)
                    onFocusReceived: root.reveal(this)
                }
                Rectangle { width: parent.width; height: 1; color: root.tokens.color.surfaceAlt }
                Label { width: parent.width; text: "Оставьте место у краёв экрана, чтобы окна не перекрывали панели."; color: root.tokens.color.textMuted; font.pixelSize: 13 }
                ReservationControl { width: parent.width; label: "Сверху"; reserved: root.topReserved; onFocusReceived: root.reveal(this); onAdjusted: function(amount) { root.reservationChanged(amount, root.bottomReserved) } }
                ReservationControl { width: parent.width; label: "Снизу"; reserved: root.bottomReserved; onFocusReceived: root.reveal(this); onAdjusted: function(amount) { root.reservationChanged(root.topReserved, amount) } }
                Flow {
                    width: parent.width
                    spacing: 4
                    Action { text: "По размеру панелей"; selected: true; onClicked: root.reservationChanged(64, 72); onActiveFocusChanged: if (activeFocus) root.reveal(this) }
                    Action { text: "Сбросить"; onClicked: root.reservationChanged(0, 0); onActiveFocusChanged: if (activeFocus) root.reveal(this) }
                }
            }
            }
        }
