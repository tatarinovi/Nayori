pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import "../../services/system"

Column {
    id: root
    required property var tokens
    spacing: 16
    property string pending: ""
    property string notice: ""
    property string actionError: ""

    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    function percentText(value) {
        if (typeof value !== "number" || !isFinite(value) || value < 0)
            return ""
        const pct = value <= 1 ? Math.round(value * 100) : Math.round(value)
        return pct + "%"
    }

    function durationText(seconds) {
        if (typeof seconds !== "number" || !isFinite(seconds) || seconds <= 0)
            return ""
        const total = Math.round(seconds)
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        if (hours > 0)
            return hours + "\u00A0ч " + minutes + "\u00A0мин"
        return minutes + "\u00A0мин"
    }

    function profileName(profile) {
        if (profile === PowerProfile.PowerSaver)
            return "Экономия"
        if (profile === PowerProfile.Balanced)
            return "Сбалансированный"
        if (profile === PowerProfile.Performance)
            return "Производительность"
        return ""
    }

    function confirmTitle() {
        if (pending === "lock")
            return "Заблокировать сеанс?"
        if (pending === "logout")
            return "Завершить сеанс?"
        if (pending === "reboot")
            return "Перезагрузить компьютер?"
        if (pending === "powerOff")
            return "Выключить компьютер?"
        return ""
    }

    function confirmBody() {
        if (pending === "lock")
            return "Экран заблокируется. Сеанс и приложения останутся открытыми"
        if (pending === "logout")
            return "Открытые приложения закроются"
        if (pending === "reboot" || pending === "powerOff")
            return "Несохранённые данные пропадут"
        return ""
    }

    function confirmButton() {
        if (pending === "lock")
            return "Заблокировать"
        if (pending === "logout")
            return "Да, завершить сеанс"
        if (pending === "reboot")
            return "Да, перезагрузить"
        if (pending === "powerOff")
            return "Да, выключить"
        return ""
    }

    function runPending() {
        actionError = ""
        notice = ""
        let started = false
        if (pending === "lock")
            started = session.lock()
        else if (pending === "logout")
            started = session.logout()
        else if (pending === "reboot")
            started = session.reboot()
        else if (pending === "powerOff")
            started = session.powerOff()
        if (started)
            pending = ""
    }

    function chooseProfile(profile) {
        profileError = ""
        try {
            PowerProfiles.profile = profile
        } catch (error) {
            profileError = "Не удалось сменить профиль питания"
        }
    }

    property string profileError: ""
    readonly property var battery: UPower.displayDevice
    readonly property bool batteryReady: battery && battery.ready && battery.isPresent

    Keys.onEscapePressed: function(event) {
        if (pending !== "") {
            pending = ""
            event.accepted = true
        }
    }

    SessionActions {
        id: session
        onFailed: function(action, message) {
            root.actionError = message
            root.notice = ""
        }
        onStarted: function(action) {
            root.actionError = ""
            root.notice = action === "lock" ? "Блокировка запущена"
                    : action === "logout" ? "Завершение сеанса запущено"
                    : action === "reboot" ? "Перезагрузка запущена"
                    : action === "powerOff" ? "Выключение запущено" : ""
        }
    }

    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: session.unavailableReason !== ""
        text: session.unavailableReason
    
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: root.actionError !== ""
        text: root.actionError
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: root.notice !== ""
        text: root.notice
    }

    Column {
        visible: root.pending === ""
        width: parent.width
        spacing: 8
        Action { text: "Заблокировать"; enabled: !session.busy; onClicked: root.pending = "lock" }
        Action { text: "Завершить сеанс"; enabled: !session.busy; onClicked: root.pending = "logout" }
        Action { text: "Перезагрузить"; enabled: !session.busy; onClicked: root.pending = "reboot" }
        Action { text: "Выключить"; enabled: !session.busy; onClicked: root.pending = "powerOff" }
    }
    Column {
        visible: root.pending !== ""
        width: parent.width
        spacing: 8
        Label { width: parent.width; text: root.confirmTitle(); font.family: root.tokens.type.display.family; font.pixelSize: 18 }
        Label {
            width: parent.width
            color: root.tokens.color.textMuted
            font.pixelSize: 13
             text: root.confirmBody() 
        }
        Action { text: root.confirmButton(); selected: true; enabled: !session.busy; onClicked: root.runPending() }
        Action { text: "Отмена"; enabled: !session.busy; onClicked: root.pending = "" }
    }

    Label { text: "Батарея"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: !root.batteryReady ? "UPower не передал состояние батареи"
             : (UPower.onBattery ? "От батареи" : "От сети") + " · " + root.percentText(root.battery.percentage)
               + (root.durationText(root.battery.timeToEmpty) !== "" ? " · осталось " + root.durationText(root.battery.timeToEmpty) : "")
               + (root.durationText(root.battery.timeToFull) !== "" ? " · до полной зарядки " + root.durationText(root.battery.timeToFull) : "")
    
    }
    Label { text: "Профиль питания"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: "Сейчас: " + (root.profileName(PowerProfiles.profile) || "не прочитан") + ". Значение пишется в power-profiles-daemon. Если демон не запущен, профиль не изменится" 
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: root.profileError !== ""
        text: root.profileError
    }
    Action { text: "Экономия"; enabled: PowerProfiles.profile !== PowerProfile.PowerSaver; onClicked: root.chooseProfile(PowerProfile.PowerSaver) }
    Action { text: "Сбалансированный"; enabled: PowerProfiles.profile !== PowerProfile.Balanced; onClicked: root.chooseProfile(PowerProfile.Balanced) }
    Action {
        text: "Производительность"
        visible: PowerProfiles.hasPerformanceProfile
        enabled: PowerProfiles.profile !== PowerProfile.Performance
        onClicked: root.chooseProfile(PowerProfile.Performance)
    }
}
