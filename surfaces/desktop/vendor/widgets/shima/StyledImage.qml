import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick





Image {
    readonly property var nayoriStyledImage: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    asynchronous: true
    retainWhileLoading: true
    visible: opacity > 0
    opacity: (status === Image.Ready) ? 1 : 0
    Behavior on opacity {
        animation: NumberAnimation { duration: nayoriStyledImage.appearance.animation.elementMoveEnter.duration; easing.type: nayoriStyledImage.appearance.animation.elementMoveEnter.type; easing.bezierCurve: nayoriStyledImage.appearance.animation.elementMoveEnter.bezierCurve }
    }

    property list<string> fallbacks: []
    property int currentFallbackIndex: 0

    onStatusChanged: {
        if (status === Image.Error && currentFallbackIndex < fallbacks.length) {
            source = fallbacks[currentFallbackIndex];
            currentFallbackIndex += 1;
        }
    }
}
