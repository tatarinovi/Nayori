import QtQuick

Item {
    id: root
    required property var startup
    required property var tokens
    required property string outputName
    property color splashAccent: tokens.color.accent
    property bool dynamicAccent: true
    property int fadeDuration: 220
    property string waitingFor: "компоненты оболочки"
    property real reveal: startup.releasing ? 0 : 1
    onRevealChanged: if (reveal === 0) startup.exited(outputName)
    Connections {
        target: root.tokens.motion
        function onOffChanged() { if (root.tokens.motion.off) fade.complete() }
    }
    Behavior on reveal {
        NumberAnimation {
            id: fade
            duration: root.tokens.motion.off ? 0 : root.fadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.tokens.motion.easeOut
        }
    }
    Component.onCompleted: {
        if (startup.releasing && reveal === 0) Qt.callLater(function() { startup.exited(outputName) })
    }
    FirstFrame {
        armed: root.visible && !root.startup.releasing
        onSeenChanged: if (seen) root.startup.report(root.outputName, "cover", true)
    }
    StartupArtwork {
        anchors.fill: parent
        opacity: root.reveal
        tokens: root.tokens
        splashAccent: root.splashAccent
        dynamicAccent: root.dynamicAccent
        stalled: root.startup.stalled
        waitingFor: root.waitingFor
        failureMessage: root.startup.error
        onContinueRequested: root.startup.dismiss()
    }
}
