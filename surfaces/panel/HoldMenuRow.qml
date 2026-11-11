pragma ComponentBehavior: Bound

import QtQuick

MenuRow {
    id: root

    property bool holdEnabled: true
    property real holdProgress: 0
    backgroundProgress: tile ? holdProgress : 0
    signal held()

    Accessible.description: "Удерживайте 500 миллисекунд"

    function cancelHold() {
        holdTimer.stop()
        progressAnimation.stop()
        resetAnimation.restart()
    }

    onDownChanged: {
        if (down && holdEnabled && enabled) {
            resetAnimation.stop()
            holdProgress = 0
            progressAnimation.restart()
            holdTimer.restart()
        } else {
            cancelHold()
        }
    }
    onHoldEnabledChanged: if (!holdEnabled) cancelHold()
    onEnabledChanged: if (!enabled) cancelHold()
    onVisibleChanged: if (!visible) cancelHold()
    onActiveFocusChanged: if (!activeFocus) cancelHold()

    Timer {
        id: holdTimer
        interval: 500
        onTriggered: {
            if (root.down && root.enabled && root.holdEnabled)
                root.held()
        }
    }
    NumberAnimation {
        id: progressAnimation
        target: root
        property: "holdProgress"
        from: 0; to: 1; duration: root.tokens.motion.off ? 0 : 500
    }
    NumberAnimation {
        id: resetAnimation
        target: root; property: "holdProgress"; to: 0
        duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
        easing.type: Easing.OutCubic
    }
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        width: (parent.width - 20) * root.holdProgress
        height: 2
        radius: 1
        color: root.tokens.color.accent
        visible: !root.tile && root.holdProgress > 0
    }
}
