import QtQuick
import QtQuick.Controls
import "../panel"

Rectangle {
    id: root
    required property var tokens
    property color splashAccent: tokens.color.accent
    property bool dynamicAccent: true
    property bool stalled: false
    property string waitingFor: ""
    property string failureMessage: ""
    signal continueRequested()
    readonly property color accent: dynamicAccent ? splashAccent : "#C0AFD1"
    // Keep the splash dark in both themes, while tinting its entire background.
    readonly property color ground: Qt.rgba(accent.r * 0.085, accent.g * 0.085, accent.b * 0.11, 1)
    readonly property real unit: Math.min(1.25, width / 1100, height / (stalled ? 1000 : 760))
    color: ground
    clip: true
    Rectangle {
        width: parent.width * 1.2; height: parent.height * 0.8
        x: -width * 0.35; y: -height * 0.55
        radius: width / 2
        rotation: -24
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.36) }
            GradientStop { position: 1; color: root.ground }
        }
    }
    Rectangle {
        width: parent.width; height: parent.height * 0.7
        x: parent.width * 0.45; y: parent.height * 0.77
        radius: width / 2
        rotation: -24
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) }
            GradientStop { position: 1; color: root.ground }
        }
    }
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.stalled ? -Math.min(root.height * 0.12, 90) : 0
        spacing: 28 * root.unit
        NayoriMark {
            anchors.horizontalCenter: parent.horizontalCenter
            variant: "fox"
            ink: root.accent
            width: 244 * root.unit; height: 276 * root.unit
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nayori"
            color: "#F0E9DB"
            font.family: root.tokens.type.body.family
            font.pixelSize: Math.max(24, 64 * root.unit)
            font.weight: Font.Light
        }
        Item {
            width: 300 * root.unit; height: 32 * root.unit
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                anchors.centerIn: parent
                width: parent.width; height: 4
                radius: 2
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                clip: true
                Rectangle {
                    id: runner
                    width: parent.width * 0.28; height: parent.height
                    radius: 2
                    color: root.accent
                    property real travel: 0
                    x: root.tokens.motion.off || root.stalled ? (parent.width - width) / 2
                        : -width + (parent.width + width) * travel
                    NumberAnimation on travel {
                        running: !root.tokens.motion.off && !root.stalled && root.visible
                        loops: Animation.Infinite
                        from: 0; to: 1; duration: 1400
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }
    Column {
        visible: root.stalled
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(20, parent.height * 0.065)
        width: Math.min(parent.width - 32, 520)
        spacing: 10
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.failureMessage ? "Не удалось запустить Nayori" : "Запуск занимает больше времени"
            color: "#F0E9DB"
            font.family: root.tokens.type.body.family
            font.pixelSize: 16
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.failureMessage || ("Ожидаем: " + root.waitingFor + ". Можно открыть рабочий стол сейчас.")
            color: "#D5CEC4"
            font.family: root.tokens.type.body.family
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Открыть рабочий стол"
            focus: root.stalled
            onClicked: root.continueRequested()
        }
    }
}
