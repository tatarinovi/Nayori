import QtQuick

// A shared curve keeps all four edge surfaces equally soft in both directions.
QtObject {
    id: root
    required property var tokens
    property int appearDuration: 360
    property int disappearDuration: 420
    property bool shown: true
    property bool enabled: true
    property bool ready: false
    property real progress: shown ? 1 : 0
    Component.onCompleted: Qt.callLater(function() { root.ready = true })
    Behavior on progress {
        enabled: root.ready && root.enabled
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.shown ? root.appearDuration : root.disappearDuration
            easing.type: Easing.InOutCubic
        }
    }
}
