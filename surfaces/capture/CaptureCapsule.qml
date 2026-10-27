pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../island"

Rectangle {
    id: root
    required property var tokens
    required property var service
    visible: !!service && service.controlsVisible
    width: row.implicitWidth + 20
    height: 48; radius: 24
    color: tokens.material.island
    border.width: 1; border.color: tokens.color.border
    antialiasing: true
    Accessible.role: Accessible.Grouping
    Accessible.name: service && service.paused ? "Запись на паузе" : "Запись экрана"
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 6; radius: 3
            color: root.tokens.color.secondary
            opacity: root.service && root.service.paused ? 0.4 : 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.service ? root.service.timeText : "00:00"
            color: root.tokens.color.text
            font.family: root.tokens.type.body.family; font.pixelSize: 13
            font.features: ({tnum: 1, lnum: 1})
            textFormat: Text.PlainText
        }
        AbstractButton {
            id: pause
            width: 28; height: 32
            enabled: root.service && root.service.state === "recording"
            hoverEnabled: true
            Accessible.name: root.service && root.service.paused ? "Продолжить запись" : "Приостановить запись"
            onClicked: root.service.pause()
            background: Rectangle { radius: 14; color: pause.hovered || pause.visualFocus ? root.tokens.color.surface : "transparent" }
            contentItem: Glyph { width: 14; height: 14; name: root.service && root.service.paused ? "play" : "pause"; ink: root.tokens.color.text; opacity: pause.enabled ? 1 : .4 }
        }
        AbstractButton {
            id: stop
            width: 28; height: 32
            enabled: root.service && root.service.state === "recording"
            hoverEnabled: true
            Accessible.name: "Завершить запись"
            onClicked: root.service.stop()
            background: Rectangle { radius: 14; color: stop.hovered || stop.visualFocus ? root.tokens.color.surface : "transparent" }
            contentItem: Glyph { width: 14; height: 14; name: "stop"; ink: root.tokens.color.secondary; opacity: stop.enabled ? 1 : .4 }
        }
    }
}
