pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "tokens"
import "surfaces/settings"
import "services/ui/PanelGeometry.js" as PanelGeometry

ShellRoot {
    id: test
    property int fitTop: -1
    property int fitBottom: -1
    property int step: 0
    property int waits: 0

    function check(ok, message) {
        if (!ok) {
            console.error("COPY_FAIL " + message)
            Qt.exit(1)
        }
    }

    function find(item, name, seen) {
        if (!item)
            return null
        const visited = seen || []
        if (visited.indexOf(item) >= 0)
            return null
        visited.push(item)
        if (item.objectName === name)
            return item
        const kids = item.children || []
        for (let i = 0; i < kids.length; i++) {
            const found = test.find(kids[i], name, visited)
            if (found)
                return found
        }
        if (item.item)
            return test.find(item.item, name, visited)
        return null
    }

    Tokens { id: theme }

    NotificationsPage {
        id: notes
        tokens: theme
        width: 480
    }
    IslandPage {
        id: island
        tokens: theme
        width: 480
        islandRotationEnabled: true
    }
    IntegrationsPage {
        id: integrations
        tokens: theme
        width: 480
    }
    NaomiPage {
        id: naomi
        tokens: theme
        width: 480
        section: "overview"
        animationsEnabled: false
        companionReactToPointer: true
        previewActive: false
    }
    Item {
        width: 480
        height: 720
        PanelsMonitorCard {
            id: card
            tokens: theme
            outputName: "DP-1"
            onReservationRequested: function(top, bottom) {
                test.fitTop = top
                test.fitBottom = bottom
            }
        }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 1100
        implicitHeight: 760
        Settings {
            id: settingsView
            width: 1100
            height: 760
            tokens: theme
            accentStatus: "На обоях нет выразительного цвета, акцент Nayori остаётся"
            niriAccentError: "Не удалось записать цвет акцента niri"
        }
    }

    Timer {
        interval: 80
        running: true
        repeat: true
        onTriggered: test.advance()
    }

    function advance() {
        if (test.step === 0) {
            if (!test.find(settingsView, "settings-search-toggle") || !test.find(naomi, "settingsNaomiMotionNote")) {
                test.waits++
                test.check(test.waits < 40, "settings pages did not load")
                return
            }
            const toggle = test.find(notes, "notificationEnabledToggle")
            test.check(!!toggle, "notification toggle")
            notes.notificationsEnabled = true
            test.check(toggle.description.indexOf("сохраняются") >= 0, "notifications on keeps history")
            test.check(toggle.description.indexOf("свёрнутом") >= 0, "notifications on names the collapsed island")
            test.check(toggle.description.indexOf("не попадают") < 0, "notifications on is not the off copy")
            notes.notificationsEnabled = false
            test.check(toggle.description.indexOf("не попадают") >= 0, "notifications off drops new ones")
            test.check(toggle.description.indexOf("Уже сохранённые остаются") >= 0, "notifications off keeps existing")

            const rotation = test.find(island, "islandRotationToggle")
            test.check(!!rotation && rotation.text === "Чередовать часы и погоду", "island name")
            test.check(rotation.description.indexOf("часы и погода") >= 0, "island on names both faces")
            test.check(rotation.description.indexOf("без ошибки") >= 0, "island on needs a successful city")
            test.check(rotation.description.indexOf("лаунчер") >= 0 && rotation.description.indexOf("раскрытый") >= 0, "island on names the pauses")
            island.islandRotationEnabled = false
            test.check(rotation.description.indexOf("остаются часы") >= 0, "island off stays on the clock")
            test.check(rotation.description.indexOf("Чередуются") < 0, "island off does not promise rotation")

            const error = test.find(integrations, "niriAccentError")
            test.check(!!error && !error.visible, "niri error hidden when empty")
            integrations.niriAccentError = "Не удалось записать цвет акцента niri"
            test.check(error.visible && error.text === integrations.niriAccentError, "niri error shown beside the switch")

            settingsView.displayedPage = 24
            const passed = test.find(settingsView, "niriAccentError")
            test.check(!!passed && passed.text === settingsView.niriAccentError && passed.visible, "settings passes the niri error")
            const accent = test.find(settingsView, "accentStatus")
            test.check(!!accent && accent.text === settingsView.accentStatus, "appearance keeps the wallpaper status")
            test.check(accent.text.indexOf("записать цвет") < 0, "appearance status is not the niri write error")

            const searchButton = test.find(settingsView, "settings-search-toggle")
            const searchField = test.find(settingsView, "settings-search")
            test.check(searchButton.Accessible.name === "Найти раздел", "search button name")
            test.check(!!searchField && searchField.Accessible.name === "Найти раздел", "search field name")
            test.check(searchField.Accessible.description.indexOf("названию") >= 0
                && searchField.Accessible.description.indexOf("пути") >= 0
                && searchField.Accessible.description.indexOf("описанию") >= 0, "search names title, path and description")
            const lock = settingsView.sections.find(function(item) { return item.key === "lockscreen" })
            test.check(lock.description.indexOf("нет своего") < 0 && lock.description.indexOf("Предпросмотр") >= 0, "lock section describes the preview")
            const islandSection = settingsView.sections.find(function(item) { return item.key === "island" })
            test.check(islandSection.description.indexOf("Чередование") >= 0 && islandSection.description.indexOf("Смена страниц") < 0, "island section description")

            const fit = PanelGeometry.fit(theme)
            test.check(theme.spacing.small === 8 && theme.panel.height === 48 && theme.panel.control === 32, "shared token sizes")
            test.check(fit.top === theme.spacing.small * 2 + theme.panel.height, "top band is margin, capsule and the same gap")
            test.check(fit.bottom === Math.max(
                theme.panel.height + theme.spacing.small,
                theme.panel.control + theme.spacing.small * 3,
                PanelGeometry.appsIconSlot() + theme.spacing.small * 3), "bottom band is the tallest dock window")
            test.check(fit.top === 64 && fit.bottom === 64, "current panels reserve 64 and 64")
            const button = test.find(card, "panelsFitReservation")
            test.check(!!button, "fit button")
            button.clicked()
            test.check(test.fitTop === fit.top && test.fitBottom === fit.bottom, "fit button requests the shared sizes")

            const motion = test.find(naomi, "settingsNaomiMotionNote")
            test.check(!!motion && motion.visible, "motion note visible while animations are off")
            test.check(motion.text.indexOf("поглаживание") >= 0, "petting mentioned while pointer reaction is on")
            naomi.companionReactToPointer = false
            test.step = 1
            return
        }
        if (test.step === 1) {
            const motion = test.find(naomi, "settingsNaomiMotionNote")
            test.check(motion.text.indexOf("поглаживание") < 0, "petting omitted while pointer reaction is off")
            test.check(motion.text.indexOf("говорит") >= 0, "speech remains without pointer reaction")
            naomi.section = "place"
            naomi.companionDesktopOnly = false
            test.step = 2
            return
        }
        if (test.step === 2) {
            const place = test.find(naomi, "settingsCompanionDesktopOnlyToggle")
            test.check(!!place, "desktop-only toggle")
            test.check(place.description.indexOf("Отключите") < 0, "off copy does not say to turn the switch off")
            test.check(place.description.indexOf("поверх окон приложений") >= 0, "off copy is above application windows")
            test.check(place.description.indexOf("Включение") >= 0, "off copy points at turning the switch on")
            naomi.companionDesktopOnly = true
            test.step = 3
            return
        }
        const place = test.find(naomi, "settingsCompanionDesktopOnlyToggle")
        test.check(place.description.indexOf("скрыта за окнами") >= 0, "on copy is behind application windows")
        test.check(place.description.indexOf("Отключите") < 0, "on copy does not say to turn the switch off")
        console.log("COPY_PASS")
        Qt.quit()
    }
}
