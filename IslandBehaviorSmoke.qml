pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "tokens"
import "services/island"
import "surfaces/island"
ShellRoot {
    id: root
    property int nextId: 0
    Tokens { id: theme }
    NotificationModel { id: notifications; automatic: false }
    QtObject {
        id: fakeAudio
        property bool playing: false
        property bool available: true
        property real energy: 0
        signal beat(real strength)
        function consumer(key, value) {}
    }
    FloatingWindow {
        id: window
        visible: true; implicitWidth: 760; implicitHeight: 800
        color: theme.color.background
        ColumnLayout {
            id: stage
            anchors.fill: parent; anchors.margins: 24
            Fox { id: fox; tokens: theme; testMode: true; audioReaction: fakeAudio; cpuInput: cpu.value; unread: notifications.unreadCount > 0; Layout.alignment: Qt.AlignHCenter; width: 104; height: 60 }
            Label { text: "CPU"; color: theme.color.text }
            Slider { id: cpu; Layout.fillWidth: true; from: 0; to: 1 }
            Label { text: "Energy"; color: theme.color.text }
            Slider { Layout.fillWidth: true; from: 0; to: 1; onValueChanged: fakeAudio.energy = value }
            RowLayout {
                CheckBox { palette.windowText: theme.color.text; text: "Playing"; onToggled: fakeAudio.playing = checked }
                CheckBox { palette.windowText: theme.color.text; text: "Reduced motion"; onToggled: fox.reducedMotion = checked }
                Button { text: "Beat"; onClicked: fakeAudio.beat(1) }
                Button { text: "Hover ↗"; onClicked: { fox.controller.hovered = !fox.controller.hovered; fox.controller.pointerX = 1; fox.controller.pointerY = -1 } }
            }
            RowLayout {
                Button { text: "+ уведомление"; onClicked: notifications.receive({id:++root.nextId,appName:"Тест",summary:"Уведомление " + root.nextId,body:"Искусственное уведомление без D-Bus",actions:[]}) }
                Button { text: "+5 секунд"; onClicked: notifications.advance(5) }
                CheckBox { palette.windowText: theme.color.text; text: "Раскрыть"; onToggled: island.expanded = checked }
            }
            Item {
                Layout.fillWidth: true; Layout.preferredHeight: island.height
                MorphingIsland { id: island; anchors.horizontalCenter: parent.horizontalCenter; tokens: theme; testMode: true; audioReaction: fakeAudio; notifications: notifications }
            }
            Item { Layout.fillHeight: true }
        }
    }
    Timer {
        id: screenshot; interval: 500
        onTriggered: stage.grabToImage(function(result) {
            result.saveToFile("/tmp/nayori-island-preview.png")
            island.expanded = false
            notifications.receive({id:4,appName:"Музыка",summary:"Новый выпуск",body:"Уведомление в компактном острове",actions:[]})
            compactScreenshot.start()
        })
    }
    Timer {
        id: compactScreenshot; interval: 500
        onTriggered: stage.grabToImage(function(result) {
            result.saveToFile("/tmp/nayori-island-compact.png")
            island.notificationPage = false; island.expanded = true
            homeScreenshot.start()
        })
    }
    Timer {
        id: homeScreenshot; interval: 500
        onTriggered: stage.grabToImage(function(result) {
            result.saveToFile("/tmp/nayori-island-home.png")
            console.log("ISLAND_BEHAVIOR_PASS"); Qt.quit()
        })
    }
    function check(value, message) { if (!value) throw new Error(message) }
    Timer {
        running: Quickshell.env("NAYORI_ISLAND_AUTOTEST") === "1"; interval: 200
        onTriggered: {
            fox.controller.automatic = false
            fox.controller.cpu = 1; fox.controller.advance(1)
            root.check(fox.controller.state.cpu > 0.6, "CPU smoothing")
            fakeAudio.playing = true; fakeAudio.energy = 1
            fox.controller.hovered = true; fox.controller.pointerX = 1
            fakeAudio.beat(1); fox.controller.advance(0.03)
            root.check(fox.controller.pose.head > 0 && fox.controller.pose.x > 0, "independent channels")
            for (let id = 1; id <= 3; id++) notifications.receive({id:id,appName:"Test",summary:"Title",body:"Body",actions:[]})
            root.check(notifications.current.id === 1, "first notification")
            notifications.advance(5); notifications.advance(0)
            root.check(notifications.current.id === 2, "queue timing")
            island.expanded = true; island.notificationPage = true
            root.check(notifications.unreadCount === 0 && notifications.current === null, "page marks read")
            island.expanded = false; notifications.advance(10)
            root.check(notifications.current === null, "no replay")
            island.expanded = true
            const page = island.children.find(c => c.objectName === "islandDashboardLoader").item
            root.check(page.currentPage === 0 && !island.notificationPage, "reopening defaults to home")
            island.notificationPage = true
            page.navigateWheel(120, 1000)
            root.check(page.currentPage === 0 && !island.notificationPage, "wheel previous page")
            page.navigateWheel(-120, 1300)
            root.check(page.currentPage === 1 && island.notificationPage, "wheel next page")
            page.navigateWheel(120, 1350)
            root.check(page.currentPage === 1, "wheel cooldown")
            page.navigateWheel(60, 1600); page.navigateWheel(60, 1601)
            root.check(page.currentPage === 0, "high resolution wheel accumulation")
            island.notificationPage = true
            root.check(page.currentPage === 1, "external page synchronization")
            notifications.receive({id:5,appName:"Nayori",summary:"Все страницы в одном стиле",body:"Плавное переключение, спокойная типографика и общий ритм карточек.\nПолный текст уведомления остаётся доступным на этой странице.",actions:[{id:"open",text:"Открыть"}]})
            screenshot.start()
        }
    }
}
