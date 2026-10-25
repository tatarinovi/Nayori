import QtQuick

// One controller per island: no shared reveal state between screen edges.
QtObject {
    id: root
    property bool autoHide: false
    property bool available: true
    property bool obstructed: true
    property bool pointerInside: false
    property bool heldOpen: false
    property bool revealed: false
    readonly property bool shown: available && (!autoHide || !obstructed || pointerInside || heldOpen || revealed)

    onObstructedChanged: {
        if (!pointerInside && !heldOpen)
            revealed = false
    }
    onPointerInsideChanged: {
        if (pointerInside) {
            revealed = true
            hideDelay.stop()
        } else {
            hideDelay.restart()
        }
    }
    onHeldOpenChanged: {
        if (heldOpen)
            hideDelay.stop()
        else
            hideDelay.restart()
    }
    onAutoHideChanged: {
        revealed = pointerInside || heldOpen
        hideDelay.stop()
    }
    onAvailableChanged: {
        if (!available) {
            revealed = false
            hideDelay.stop()
        }
    }
    property Timer hideDelay: Timer {
        interval: 650
        onTriggered: {
            if (!root.pointerInside && !root.heldOpen)
                root.revealed = false
        }
    }
}
