import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Effects



Item {
    readonly property var nayoriClockFaceDigital: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 120
    property real minHeight: 60
    property real maxWidth: 1400
    property real maxHeight: 700
    property real minAspect: 1.2
    property real maxAspect: 5.0
    property bool isRound: false
    property bool ryokuBare: false

    Text {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.06
        text: nayoriClockFaceDigital.dateTime.hour + nayoriClockFaceDigital.dateTime.minute
        font.family: nayoriClockFaceDigital.pythonTheme.fontFamily
        font.pixelSize: Math.round(height)
        fontSizeMode: Text.Fit
        minimumPixelSize: 12
        font.weight: Font.Black
        font.letterSpacing: height * 0.01
        color: Qt.tint(nayoriClockFaceDigital.pythonTheme.text, Qt.alpha(nayoriClockFaceDigital.pythonTheme.mauve, 0.14))
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: nayoriClockFaceDigital.scaler.s(3)
            shadowBlur: 0.55
            shadowOpacity: 0.5
        }
    }
}
