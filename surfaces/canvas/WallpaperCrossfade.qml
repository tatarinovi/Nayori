import QtQuick

// Source changes dissolve after the first settled frame. Startup stays a hard
// cut: the configured wallpaper often arrives only once the manager is ready.
// Two renderers stay for the life of the item. cache: false would blank the
// picture if the decoded image were moved to a new Image.
Item {
    id: root
    required property string source
    required property string mode
    required property color backgroundColor
    required property bool reduceMotion
    required property int duration
    property bool managerReady: false
    property string outputName: ""
    signal renderFailed(bool failed)

    property int front: 0
    property bool live: false
    property bool settled: false
    property bool releasing: false
    property string frontRequest: ""
    property string backRequest: ""
    property real incomingOpacity: 0
    property bool fading: false
    property int fadeSerial: 0
    property int finishSerial: -1

    function slot(index) { return index === 0 ? layer0 : layer1 }
    function fore() { return slot(front) }
    function back() { return slot(1 - front) }

    function schedule() {
        if (live) coalesce.restart()
    }
    function publish(view) {
        if (releasing) return
        const request = view === fore() ? frontRequest : backRequest
        if (request === "" || request !== root.source) return
        renderFailed(view.failed)
    }
    function markSettled() {
        const current = fore()
        if (!managerReady || !current.loaded || frontRequest !== root.source) return
        settled = true
    }
    function cancelFade() {
        finishSerial = -1
        fading = false
        if (fade.running) fade.stop()
        incomingOpacity = 0
    }
    function beginFade() {
        fadeSerial += 1
        finishSerial = fadeSerial
        incomingOpacity = 0
        fading = true
        fade.start()
    }
    function releaseBack() {
        const incoming = back()
        backRequest = ""
        if (String(incoming.source) === "") return
        releasing = true
        incoming.source = ""
        releasing = false
    }
    function placeFirst() {
        cancelFade()
        releaseBack()
        const current = fore()
        current.mode = root.mode
        const changed = frontRequest !== root.source
        if (changed) {
            frontRequest = root.source
            current.source = root.source
        }
        if (!changed) markSettled()
    }
    function finishFade() {
        // A stale finish must not keep a half-shown frame over the settled image.
        if (backRequest !== root.source || !back().loaded) {
            fading = false
            incomingOpacity = 0
            return
        }
        const old = fore()
        const kept = backRequest
        front = 1 - front
        frontRequest = kept
        backRequest = ""
        fading = false
        incomingOpacity = 0
        releasing = true
        old.source = ""
        releasing = false
        settled = true
    }
    function failBack() {
        // Clear on the next turn. Dropping source inside the Image status
        // binding makes Qt report a loop on StaticRenderer.failed.
        cancelFade()
        const failedSource = backRequest
        if (failedSource === "") return
        Qt.callLater(function () {
            if (backRequest === failedSource) releaseBack()
        })
    }
    function revealBack() {
        const incoming = back()
        if (!settled || !incoming.loaded || backRequest !== root.source) return
        if (reduceMotion) {
            cancelFade()
            finishFade()
            return
        }
        if (fade.running && finishSerial === fadeSerial) return
        beginFade()
    }
    function armBack() {
        const incoming = back()
        incoming.mode = root.mode
        if (backRequest === root.source) {
            if (incoming.loaded) revealBack()
            else if (incoming.failed) failBack()
            return
        }
        cancelFade()
        backRequest = root.source
        incoming.source = root.source
    }
    function sync() {
        if (!live) return
        if (!settled) {
            placeFirst()
            return
        }
        if (frontRequest === root.source) {
            fore().mode = root.mode
            publish(fore())
            cancelFade()
            releaseBack()
            return
        }
        armBack()
    }
    function observe(view) {
        if (releasing) return
        publish(view)
        if (view === fore()) {
            markSettled()
            return
        }
        if (!settled || backRequest !== root.source) return
        if (view.failed) failBack()
        else if (view.loaded) revealBack()
    }
    function cutIncoming() {
        if (!live || !reduceMotion || !settled) return
        const incoming = back()
        if (backRequest === root.source && incoming.loaded) {
            cancelFade()
            finishFade()
        } else
            cancelFade()
    }

    Component.onCompleted: {
        live = true
        sync()
    }
    onSourceChanged: schedule()
    onModeChanged: schedule()
    onManagerReadyChanged: schedule()
    onOutputNameChanged: {
        if (!live) return
        settled = false
        cancelFade()
        schedule()
    }
    onReduceMotionChanged: cutIncoming()

    Timer {
        id: coalesce
        interval: 0
        repeat: false
        onTriggered: root.sync()
    }
    // tokens.motion has durations but no curve. This is the shell's opacity ease-out.
    NumberAnimation {
        id: fade
        target: root
        property: "incomingOpacity"
        from: 0
        to: 1
        duration: root.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        onFinished: {
            if (root.finishSerial < 0 || root.finishSerial !== root.fadeSerial) return
            root.finishSerial = -1
            root.finishFade()
        }
    }
    // Opacity stays bound to front / fading / incomingOpacity. Writing it would drop the binding.
    StaticRenderer {
        id: layer0
        anchors.fill: parent
        z: root.front === 0 ? 0 : 1
        opacity: root.front === 0 ? 1 : (root.fading ? root.incomingOpacity : 0)
        source: ""
        mode: "fill"
        backgroundColor: root.backgroundColor
        onLoadedChanged: root.observe(layer0)
        onFailedChanged: root.observe(layer0)
    }
    StaticRenderer {
        id: layer1
        anchors.fill: parent
        z: root.front === 1 ? 0 : 1
        opacity: root.front === 1 ? 1 : (root.fading ? root.incomingOpacity : 0)
        source: ""
        mode: "fill"
        backgroundColor: root.backgroundColor
        onLoadedChanged: root.observe(layer1)
        onFailedChanged: root.observe(layer1)
    }
}
