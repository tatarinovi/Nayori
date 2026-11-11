import QtQuick

// Shared by the body and all neighbours. Behaviors retarget from the current
// value, so mode changes never queue or restart an independent surface morph.
QtObject {
    id: root
    required property var tokens
    property bool attached: false
    property bool ready: false
    property real progress: attached ? 1 : 0
    readonly property real topOffset: tokens.spacing.small * (1 - progress)
    readonly property real gap: tokens.spacing.small + 24 * progress
    Component.onCompleted: Qt.callLater(function() { root.ready = true })
    Behavior on progress {
        enabled: root.ready
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.77, 0, 0.175, 1, 1, 1]
        }
    }
}
