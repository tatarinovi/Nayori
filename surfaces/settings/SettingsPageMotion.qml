import QtQuick

// Retarget from the current opacity. Content swaps only while fully faded out.
QtObject {
    id: root
    property bool enabled: true
    property int duration: 220
    property real progress: 1
    readonly property bool running: transition.running
    signal swapRequested()
    function reveal() {
        transition.stop()
        if (!enabled) { finish(); return }
        transition.start()
    }
    function finish() {
        transition.stop()
        swapRequested()
        progress = 1
    }
    onEnabledChanged: if (!enabled) finish()
    property SequentialAnimation transition: SequentialAnimation {
        NumberAnimation {
            target: root
            property: "progress"
            to: 0
            duration: root.duration * 0.35
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        }
        ScriptAction { script: root.swapRequested() }
        NumberAnimation {
            target: root
            property: "progress"
            to: 1
            duration: root.duration * 0.65
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        }
    }
}
