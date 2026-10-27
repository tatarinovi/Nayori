pragma ComponentBehavior: Bound

import QtQuick

MenuRow {
    id: root

    property bool holdEnabled: true
    property real holdProgress: 0
    signal held()

    Accessible.description: "Удерживайте 500 миллисекунд"

    function cancelHold() {
        holdTimer.stop()
        progressAnimation.stop()
        holdProgress = 0
    }

    onDownChanged: {
        if (down && holdEnabled && enabled) {
            holdProgress = 0
            progressAnimation.restart()
            holdTimer.restart()
        } else {
            cancelHold()
        }
    }
    onHoldEnabledChanged: if (!holdEnabled) cancelHold()
    onEnabledChanged: if (!enabled) cancelHold()

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
        from: 0; to: 1; duration: 500
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
        visible: root.holdProgress > 0
    }
}
