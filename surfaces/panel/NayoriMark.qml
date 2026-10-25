pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects

// The fox file is one lavender silhouette. ColorOverlay keeps that alpha and
// paints it with ink, which the brand mark already binds to the accent.
// The start glyph is cream plus a second purple, so it stays as drawn.
Item {
    id: root

    required property color ink
    property string variant: "current"
    width: 30
    height: 30

    Image {
        id: artwork
        anchors.fill: parent
        source: root.variant === "fox" ? "../../assets/branding/nayori-fox-logo.png" : "../../assets/branding/nayori-start.png"
        sourceSize.width: root.variant === "fox" ? 256 : 120
        sourceSize.height: root.variant === "fox" ? 256 : 120
        sourceClipRect: root.variant === "fox" ? Qt.rect(48, 42, 163, 184) : Qt.rect(0, 0, 0, 0)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        layer.enabled: root.variant === "fox"
        layer.smooth: true
        layer.effect: ColorOverlay {
            color: root.ink
        }
    }
}
