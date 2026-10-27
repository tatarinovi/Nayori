import QtQuick
import QtTest
import "../surfaces/panel"

TestCase {
    id: test
    name: "HoldMenuRow"
    visible: true
    when: windowShown
    width: 300; height: 100
    property int count: 0
    HoldMenuRow {
        id: button
        width: 280; height: 64
        text: "Test"
        tokens: ({panel:{control:44}, motion:{off:true,fast:0}, radius:{small:4,medium:8}, color:{menuIcon:"red",accent:"red",accentSoft:"red",surface:"white",surfaceAlt:"white",text:"black",textMuted:"gray",accentSoftText:"white"}, type:{body:{family:"sans",size:14,weight:400},small:{family:"sans",size:12}}})
        onHeld: test.count++
    }
    function init() { count = 0; button.holdEnabled = true }
    function test_short() {
        mousePress(button, 20, 20); wait(200); mouseRelease(button, 20, 20); wait(400)
        compare(count, 0)
    }
    function test_hold() {
        mousePress(button, 20, 20); wait(600); compare(count, 1); wait(550); compare(count, 1); mouseRelease(button, 20, 20)
    }
    function test_cancel() {
        mousePress(button, 20, 20); wait(200); button.holdEnabled = false; wait(400); compare(count, 0); mouseRelease(button, 20, 20)
    }
    function test_keyboard() {
        button.forceActiveFocus(); keyPress(Qt.Key_Space); wait(600); compare(count, 1); keyRelease(Qt.Key_Space)
    }
}
