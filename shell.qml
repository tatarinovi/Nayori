import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    // Цвета ниже — временная нейтральная заглушка, пока нет референса оформления.
    readonly property color probeBg: "#d91e1e22"
    readonly property color probeFg: "#f3f3f4"

    // У ShellScreen есть геометрия и имя. Отдельного свойства фокуса нет, поэтому берём первый экран.
    readonly property var probeScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    SystemClock {
        id: clock
        enabled: true
        precision: SystemClock.Minutes
    }

    PanelWindow {
        screen: root.probeScreen
        visible: root.probeScreen !== null
        color: "transparent"
        anchors.top: true
        anchors.bottom: false
        anchors.left: false
        anchors.right: false
        margins.top: 8
        implicitWidth: 140
        implicitHeight: 36
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nayori-probe-island"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Маска ввода совпадает с капсулой. Прозрачные углы остаются вне области нажатий.
        mask: Region {
            item: capsule
            radius: Math.round(capsule.height / 2)
        }

        Rectangle {
            id: capsule
            anchors.fill: parent
            radius: height / 2
            color: root.probeBg

            Text {
                anchors.centerIn: parent
                text: "Nayori"
                color: root.probeFg
                font.pixelSize: 14
            }
        }
    }

    PanelWindow {
        screen: root.probeScreen
        visible: root.probeScreen !== null
        color: root.probeBg
        anchors.left: true
        anchors.right: true
        anchors.bottom: true
        anchors.top: false
        implicitHeight: 40
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nayori-probe-bar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 20

            Text {
                text: "Приложения"
                color: root.probeFg
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: "Рабочие столы"
                color: root.probeFg
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "Лоток"
                color: root.probeFg
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: Qt.formatTime(clock.date, "HH:mm")
                color: root.probeFg
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
