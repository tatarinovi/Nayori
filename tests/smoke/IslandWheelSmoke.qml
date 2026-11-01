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
    Component {
        id: dashboardComponent
        IslandDashboard { testMode: true; width: 680; height: 450 }
    }
    Timer { interval: 400; running: true; onTriggered: tests.test_header_wheel() }
    TestCase {
        id: tests
        name: "IslandWheel"
        when: false
        function test_header_wheel() {
            for (let motion of [true, false]) {
                theme.animationsEnabled = motion
                const initialPage = dashboardComponent.createObject(scene.contentItem, {currentPage: 1, tokens: theme})
                verify(initialPage !== null)
                wait(350)
                const initialTab = findChild(initialPage, "islandPageTab1")
                const initialIndicator = findChild(initialPage, "islandPageIndicator")
                const center = initialIndicator.mapToItem(initialTab, initialIndicator.width / 2, 0).x
                fuzzyCompare(center, initialTab.width / 2, 0.5)
                initialPage.destroy()
            }
            theme.animationsEnabled = true
            for (let id = 1; id <= 20; id++) testNotifications.receive({id:id,appName:"Test " + id,summary:"Title",body:"Body",actions:[]})
            wait(350)
            const page = findChild(island, "islandDashboardLoader").item
            compare(page.currentPage, 0)
            function checkTabs(selected) {
                const tabs = [findChild(page, "islandPageTab0"), findChild(page, "islandPageTab1"), findChild(page, "islandPageTab2")]
                const indicator = findChild(page, "islandPageIndicator")
                for (let i = 0; i < tabs.length - 1; i++)
                    fuzzyCompare(tabs[i + 1].x - tabs[i].x - tabs[i].width, 16, 0.1)
                const center = indicator.mapToItem(tabs[selected], indicator.width / 2, 0).x
                fuzzyCompare(center, tabs[selected].width / 2, 0.5)
            }
            checkTabs(0)
            mouseMove(island, 100, 58)
            mouseWheel(island, 100, 58, 0, -120)
            tryCompare(page, "currentPage", 1)
            wait(250)
            checkTabs(1)
            const historyButton = findChild(page, "notificationHistoryButton")
            const historyContent = findChild(page, "notificationHistoryContent")
            const historyLabel = findChild(page, "notificationHistoryLabel")
            const historyCenter = historyContent.mapToItem(historyButton, historyContent.width / 2, historyContent.height / 2)
            fuzzyCompare(historyCenter.x, historyButton.width / 2, 1)
            fuzzyCompare(historyCenter.y, historyButton.height / 2, 0.5)
            fuzzyCompare(historyLabel.width, historyLabel.implicitWidth, 0.5)
            compare(historyLabel.lineCount, 1)
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
            wait(250)
            checkTabs(0)
            theme.animationsEnabled = false
            page.currentPage = 2
            compare(page.pagePosition, 2)
            checkTabs(2)
            testNotifications.clear()
            wait(50)
            checkTabs(2)
            console.log("ISLAND_WHEEL_PASS")
            Qt.quit()
        }
    }
}
}
