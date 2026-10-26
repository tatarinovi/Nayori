import QtQuick
import QtTest
import Quickshell
import "tokens"
import "services/island"
import "surfaces/island"
ShellRoot {
    FloatingWindow {
    id: scene
    visible: true; implicitWidth: 712; implicitHeight: 522
    Tokens { id: theme }
    NotificationModel { id: testNotifications }
    MorphingIsland {
        id: island
        anchors.centerIn: parent
        tokens: theme; testMode: true; notifications: testNotifications
        expanded: true
    }
    Timer { interval: 400; running: true; onTriggered: tests.test_header_wheel() }
    TestCase {
        id: tests
        name: "IslandWheel"
        when: false
        function test_header_wheel() {
            for (let id = 1; id <= 20; id++) testNotifications.receive({id:id,appName:"Test " + id,summary:"Title",body:"Body",actions:[]})
            wait(350)
            const page = findChild(island, "islandDashboardLoader").item
            compare(page.currentPage, 0)
            mouseMove(island, 100, 58)
            mouseWheel(island, 100, 58, 0, -120)
            tryCompare(page, "currentPage", 1)
            wait(250)
            const list = findChild(page, "notificationList")
            verify(list.contentHeight > list.height)
            list.contentY = 100
            mouseWheel(list, 40, 80, 0, -120)
            wait(100)
            verify(list.contentY > 100)
            compare(page.currentPage, 1)
            list.positionViewAtBeginning()
            mouseWheel(list, 40, 80, 0, 120)
            wait(100)
            compare(page.currentPage, 1)
            mouseWheel(island, 100, 58, 0, 120)
            tryCompare(page, "currentPage", 0)
            wait(250)
            mouseWheel(island, 230, 58, -120, 0)
            tryCompare(page, "currentPage", 1)
            wait(250)
            for (let step = 0; step < 8; step++) mouseWheel(island, 230, 58, 0, 15)
            tryCompare(page, "currentPage", 0)
            console.log("ISLAND_WHEEL_PASS")
            Qt.quit()
        }
    }
}
}
