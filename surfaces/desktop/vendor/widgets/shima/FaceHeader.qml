import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts


RowLayout {
    readonly property var nayoriFaceHeader: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    required property var face
    property string glyph: ""
    property string text: ""
    property string trailing: ""
    property color tint: root.face.accent

    spacing: root.face.dp(5)

    MaterialSymbol {
        visible: root.glyph.length > 0
        text: root.glyph
        fill: 1
        iconSize: root.face.px(15)
        color: root.tint
    }
    FaceText {
        face: root.face
        Layout.fillWidth: true
        text: root.text
        color: root.tint
        size: 12.5
        weight: Font.DemiBold
    }
    FaceText {
        face: root.face
        visible: root.trailing.length > 0
        text: root.trailing
        color: root.face.inkTertiary
        size: 11.5
    }
}
