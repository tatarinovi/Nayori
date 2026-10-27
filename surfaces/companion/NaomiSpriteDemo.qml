import QtQuick
import QtQuick.Controls
import Quickshell

// Launch through the repository-root entrypoint: qs -p naomi-sprite-demo.qml
ShellRoot {
    FloatingWindow {
        visible: true
        title: "Naomi v3 — idle"
        implicitWidth: 360
        implicitHeight: 700
        color: "transparent"
        NaomiSprite {
            id: sprite
            anchors { top: parent.top; topMargin: 12; horizontalCenter: parent.horizontalCenter }
            width: 280
            height: 610
        }
        Button {
            anchors { bottom: parent.bottom; bottomMargin: 20; horizontalCenter: parent.horizontalCenter }
            text: sprite.running ? "Остановить idle" : "Запустить idle"
            onClicked: sprite.running = !sprite.running
        }
    }
}
