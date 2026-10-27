import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// No Quickshell/SDDM dependencies: both authentication backends use this view.
Rectangle {
    id: root
    required property var colors
    property bool primary: true
    property bool loginMode: false
    property url wallpaper
    property string wallpaperMode: "fill"
    property string username: ""
    property url avatar
    property string status: ""
    property bool busy: false
    property string passwordLabel: "Пароль"
    property bool responseVisible: false
    property bool capsLock: false
    property string layoutName: ""
    property bool canSwitchLayout: false
    property bool canSuspend: false
    property bool canReboot: false
    property bool canPowerOff: false
    property bool preview: false
    property bool animationsEnabled: true
    property bool exiting: false
    property int enterDuration: 220
    property int exitDuration: 140
    property var motionCurve: [0.23, 1, 0.32, 1, 1, 1]
    property real reveal: 0
    onExitingChanged: reveal = exiting ? 0 : 1
    onAnimationsEnabledChanged: if (!animationsEnabled) reveal = exiting ? 0 : 1
    Behavior on reveal {
        enabled: root.animationsEnabled
        NumberAnimation {
            duration: root.exiting ? root.exitDuration : root.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.motionCurve
        }
    }
    property var usersModel: []
    property var sessionsModel: []
    property int userIndex: 0
    property int sessionIndex: 0
    readonly property string selectedLogin: userChoice.currentText
    readonly property url selectedAvatar: userChoice.currentValue || ""
    property Component mediaComponent: null
    property bool mediaAvailable: true
    property date now: new Date()
    readonly property real uiScale: Math.min(1, height / 850)
    readonly property real sidebarWidth: Math.min(width, Math.max(320, Math.min(400, width * 0.29)))
    signal submitted(string secret)
    signal userSelected(int index)
    signal sessionSelected(int index)
    signal powerRequested(string action)
    signal previewClosed
    signal layoutRequested

    function focusPassword() { if (primary) password.forceActiveFocus() }
    function clearPassword() { password.clear() }
    function submit() {
        if (busy || !primary || password.text.length === 0 || (loginMode && (!selectedLogin || sessionChoice.count === 0))) return
        const secret = password.text
        password.clear()
        submitted(secret)
    }
    function relayKey(text, key) {
        if (!primary || busy) return
        if (key === Qt.Key_Return || key === Qt.Key_Enter) submit()
        else if (key === Qt.Key_Backspace) password.remove(Math.max(0, password.cursorPosition - 1), password.cursorPosition)
        else if (text && text.charCodeAt(0) >= 32) password.insert(password.cursorPosition, text)
    }
    color: colors.background
    clip: true
    onPrimaryChanged: { powerMenu.close(); clearPassword(); if (primary) focusPassword() }
    onUsernameChanged: clearPassword()
    Component.onCompleted: { reveal = 1; if (primary) focusLater.start() }
    Timer { id: focusLater; interval: 150; onTriggered: root.focusPassword() }
    Timer { interval: 1000; running: root.visible; repeat: true; onTriggered: root.now = new Date() }

    Image {
        id: wallpaperImage
        anchors.centerIn: parent
        width: root.wallpaperMode === "center" ? implicitWidth : root.width
        height: root.wallpaperMode === "center" ? implicitHeight : root.height
        source: root.wallpaper
        opacity: root.exiting ? 1 : root.reveal
        asynchronous: true
        autoTransform: true
        fillMode: root.wallpaperMode === "fill" ? Image.PreserveAspectCrop
            : root.wallpaperMode === "fit" ? Image.PreserveAspectFit : Image.Stretch
    }
    Rectangle {
        id: sidebar
        objectName: "authSidebar"
        visible: root.primary
        opacity: root.reveal
        transform: Translate { x: root.animationsEnabled ? -16 * (1 - root.reveal) : 0 }
        width: root.sidebarWidth
        height: root.height
        color: Qt.alpha(root.colors.background, 0.97)
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: root.colors.border; opacity: 0.4 }
        ScrollView {
            id: scroll
            anchors.fill: parent
            anchors.margins: 28 * root.uiScale
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ColumnLayout {
                width: parent.width
                height: Math.max(implicitHeight, scroll.availableHeight)
                spacing: 18 * root.uiScale
                Text {
                    text: "NAYORI"
                    color: root.colors.text
                    font.family: "Literata"
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.colors.border; opacity: 0.4 }
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: Qt.formatTime(root.now, "HH:mm")
                        color: root.colors.text
                        font.family: "Literata"
                        font.pixelSize: 76 * Math.max(0.72, root.uiScale)
                        font.letterSpacing: -3
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        text: root.now.toLocaleDateString(Qt.locale("ru_RU"), "d MMMM, dddd")
                        color: root.colors.textMuted
                        font.family: "Inter"
                        font.pixelSize: 13
                    }
                }
                Item { implicitHeight: 14 * root.uiScale }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    AuthAvatar {
                        objectName: "authAvatar"
                        implicitWidth: 48; implicitHeight: 48
                        colors: root.colors
                        source: root.avatar
                        username: root.username
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text {
                            visible: !root.loginMode
                            Layout.fillWidth: true
                            text: root.username
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.family: "Literata"; font.pixelSize: 20; color: root.colors.text
                        }
                        AuthSelect {
                            id: userChoice
                            objectName: "authUser"
                            visible: root.loginMode
                            Layout.fillWidth: true
                            colors: root.colors
                            model: root.usersModel
                            textRole: "name"
                            valueRole: "icon"
                            currentIndex: root.userIndex
                            enabled: !root.busy
                            Accessible.name: "Пользователь"
                            onActivated: index => root.userSelected(index)
                        }
                        Text {
                            visible: !root.loginMode
                            text: "Текущая сессия"
                            font.family: "Inter"; font.pixelSize: 12; color: root.colors.textMuted
                        }
                    }
                }
                TextField {
                    id: password
                    objectName: "authPassword"
                    Layout.fillWidth: true
                    implicitHeight: 46
                    enabled: !root.busy
                    placeholderText: root.passwordLabel
                    echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
                    passwordMaskDelay: 0
                    selectByMouse: true
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    color: root.colors.text
                    placeholderTextColor: root.colors.textMuted
                    selectionColor: root.colors.accent
                    selectedTextColor: root.colors.accentText
                    font.family: "Inter"; font.pixelSize: 14
                    leftPadding: 14; rightPadding: 14
                    Accessible.name: root.passwordLabel
                    onAccepted: root.submit()
                    background: Rectangle {
                        radius: 10
                        color: root.colors.background
                        border.width: password.activeFocus ? 2 : 1
                        border.color: password.activeFocus ? root.colors.accent : root.colors.border
                    }
                }
                Text {
                    visible: root.loginMode
                    text: "Сессия"
                    font.family: "Inter"; font.pixelSize: 12; color: root.colors.textMuted
                }
                AuthSelect {
                    id: sessionChoice
                    objectName: "authSession"
                    visible: root.loginMode
                    Layout.fillWidth: true
                    colors: root.colors
                    model: root.sessionsModel
                    textRole: "name"
                    currentIndex: root.sessionIndex
                    enabled: !root.busy
                    Accessible.name: "Сессия"
                    onActivated: index => root.sessionSelected(index)
                }
                AuthButton {
                    objectName: "authSubmit"
                    Layout.fillWidth: true
                    colors: root.colors
                    filled: true
                    text: root.busy ? "Проверка…" : root.loginMode ? "Войти" : "Разблокировать"
                    enabled: !root.busy && password.length > 0 && (!root.loginMode || (root.selectedLogin !== "" && sessionChoice.count > 0))
                    onClicked: root.submit()
                }
                RowLayout {
                    spacing: 12
                    AuthButton {
                        colors: root.colors
                        text: root.layoutName
                        visible: text !== ""
                        enabled: root.canSwitchLayout && !root.busy
                        implicitHeight: 32
                        implicitWidth: Math.min(180, Math.max(56, implicitContentWidth + 24))
                        Accessible.name: "Раскладка клавиатуры: " + root.layoutName
                        onClicked: root.layoutRequested()
                    }
                    Text { text: "Caps Lock"; font.family: "Inter"; font.pixelSize: 12; color: root.colors.accent; visible: root.capsLock }
                }
                Text {
                    objectName: "authStatus"
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.status
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: root.colors.text
                    font.family: "Inter"; font.pixelSize: 13
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Item { Layout.fillHeight: true; implicitHeight: 8 }
                Loader { Layout.fillWidth: true; sourceComponent: root.mediaComponent; visible: active; active: !root.loginMode && root.mediaAvailable && root.mediaComponent !== null }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.colors.border; opacity: 0.4 }
                AuthButton {
                    id: powerButton
                    objectName: "authPowerButton"
                    colors: root.colors
                    text: "Питание"
                    Layout.fillWidth: true
                    visible: root.canSuspend || root.canReboot || root.canPowerOff
                    enabled: !root.busy
                    onClicked: powerMenu.open()
                    AuthPowerMenu {
                        id: powerMenu
                        objectName: "authPowerMenu"
                        parent: powerButton
                        width: powerButton.width
                        y: -height - 8
                        colors: root.colors
                        canSuspend: root.canSuspend
                        canReboot: root.canReboot
                        canPowerOff: root.canPowerOff
                        onRequested: action => root.powerRequested(action)
                        onClosed: root.focusPassword()
                    }
                }
                AuthButton { colors: root.colors; text: "Закрыть предпросмотр"; Layout.fillWidth: true; visible: root.preview; onClicked: root.previewClosed() }
            }
        }
    }
}
