import QtQuick
import QtTest
import Quickshell
import "tokens"
import "services/island"
import "surfaces/island"

ShellRoot {
    FloatingWindow {
        id: scene
        visible: true
        implicitWidth: 900; implicitHeight: 522
        Tokens { id: theme }
        NotificationModel { id: records }
        QtObject {
            id: testPlayer
            property bool isPlaying: true
            property string identity: "Тестовый плеер"
            property url trackArtUrl: ""
            property string trackArtist: "Исполнитель"
            property real length: 100
            property string trackTitle: "Тестовый трек"
            property bool canGoPrevious: true
            property bool canGoNext: true
            property bool canTogglePlaying: true
            property int previousCount: 0
            property int nextCount: 0
            function previous() { previousCount++ }
            function next() { nextCount++ }
            function togglePlaying() { isPlaying = !isPlaying }
        }
        QtObject {
            id: lyricFixture
            property string status: "synced"
            property var lines: [{t: 0, text: "Строка песни в свёрнутом острове"}]
            property string currentLine: "Строка песни в свёрнутом острове"
            property var currentWords: []
            property int currentIndex: 0
            property real position: 0
        }
        QtObject {
            id: music
            property var player: testPlayer
            property var lyrics: null
            property var players: [testPlayer]
            function consumer(key, value) {}
        }
        Item {
            id: stage
            anchors.fill: parent
        MorphingIsland {
            id: island
            anchors.centerIn: parent
            tokens: theme; testMode: true; notifications: records; musicService: music
        }
        CompactClock {
            id: sideClock
            tokens: theme; showing: island.lyricsClock
            anchors.right: island.left; anchors.rightMargin: theme.spacing.small
            anchors.verticalCenter: island.verticalCenter
        }
        CompactMediaControls {
            id: mediaControls
            tokens: theme; player: island.compactPlayer; showing: island.compactControls
            anchors.left: island.right; anchors.leftMargin: theme.spacing.small
            anchors.verticalCenter: island.verticalCenter
        }
        }
        Timer { interval: 300; running: true; onTriggered: tests.run() }
        TestCase {
            id: tests
            name: "NotificationUi"
            when: false
            function run() {
                music.lyrics = lyricFixture
                wait(750)
                verify(sideClock.visible && mediaControls.visible)
                verify(sideClock.x + sideClock.width < island.x)
                verify(mediaControls.x > island.x + island.width)
                stage.grabToImage(function(result) { result.saveToFile("/tmp/nayori-notifications-lyrics.png") })
                wait(100)
                music.lyrics = null
                for (let id = 1; id <= 5; id++) records.receive({id:id, appName: id < 4 ? "Telegram" : "Система", appIcon: Quickshell.shellDir + "/assets/branding/nayori-fox-logo.png", summary:"Сообщение " + id, body:"Текст уведомления", actions:[]})
                wait(300)
                compare(records.pending.length, 1)
                compare(records.pending[0].appName, "Система")
                const sourceLabel = findChild(island, "compactNotificationSource")
                verify(sourceLabel.visible)
                verify(sourceLabel.text.indexOf("Telegram") >= 0)
                compare(findChild(island, "compactNotificationText").text, "Текст уведомления")
                const tail = findChild(island, "compactTail")
                verify(tail.visible)
                verify(island.width <= 640)
                const previous = findChild(mediaControls, "compactMedia_prev")
                const toggle = findChild(mediaControls, "compactMedia_toggle")
                const next = findChild(mediaControls, "compactMedia_next")
                mouseClick(previous); compare(testPlayer.previousCount, 1)
                mouseClick(next); compare(testPlayer.nextCount, 1)
                mouseClick(toggle); compare(testPlayer.isPlaying, false)
                verify(toggle.visible && toggle.enabled)
                mouseClick(toggle); compare(testPlayer.isPlaying, true)
                stage.grabToImage(function(result) { result.saveToFile("/tmp/nayori-notifications-row.png") })
                wait(100)
                const notificationText = findChild(island, "compactNotificationText")
                const shortWidth = island.closedWidth
                verify(!notificationText.overflowing)
                records.receive({id:1, body:"Длинное уведомление\nсо всеми\r\nподробностями. ".repeat(12)})
                wait(400)
                verify(island.closedWidth > shortWidth)
                verify(Math.abs(island.closedWidth - 520) < 1)
                verify(notificationText.overflowing && notificationText.scrolling)
                verify(notificationText.text.indexOf("\n") === -1 && notificationText.text.indexOf("\r") === -1)
                stage.grabToImage(function(result) { result.saveToFile("/tmp/nayori-notifications-long.png") })
                wait(100)
                records.receive({id:1, body:"Текст уведомления"})
                island.expanded = true
                verify(!notificationText.scrolling)
                verify(!mediaControls.visible)
                verify(!sideClock.visible)
                verify(!island.lyricsClock)
                wait(350)
                verify(island.notificationPage)
                compare(records.unreadCount, 5)
                compare(records.current, null)
                verify(!tail.visible)
                verify(!mediaControls.showing)
                const page = findChild(island, "notificationPage")
                compare(page.groups.length, 2)
                page.filterMode = "system"
                compare(page.groups.length, 1)
                compare(page.groups[0].appName, "Система")
                page.filterMode = "all"
                const group = findChild(page, "notificationGroup_telegram")
                verify(!group.expanded)
                compare(group.height, 56)
                stage.grabToImage(function(result) { result.saveToFile("/tmp/nayori-notifications-collapsed-groups.png") })
                wait(100)
                mouseClick(group, 100, 25)
                wait(250)
                verify(findChild(page, "notificationGroup_telegram").expanded)
                compare(records.unreadCount, 2)
                stage.grabToImage(function(result) { result.saveToFile("/tmp/nayori-notifications-groups.png") })
                wait(100)
                mouseClick(findChild(page, "notificationGroupClose_telegram"))
                compare(records.records.length, 2)
                compare(records.unreadCount, 2)
                records.receive({id:6, appName:"Система", summary:"Прочитанное", body:"Скрыто фильтром", actions:[]})
                records.markRead(6)
                page.filterMode = "unread"
                compare(page.groups.length, 1)
                compare(page.groups[0].count, 2)
                mouseClick(findChild(page, "notificationGroupClose_система"))
                compare(records.records.length, 0)
                compare(page.groups.length, 0)
                compare(records.unreadCount, 0)
                island.expanded = false
                island.expanded = true
                verify(!island.notificationPage)
                console.log("NOTIFICATION_UI_PASS")
                Qt.quit()
            }
        }
    }
}
