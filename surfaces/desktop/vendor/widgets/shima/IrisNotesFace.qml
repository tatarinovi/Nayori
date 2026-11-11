import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick



IrisWidgetFace {
    readonly property var nayoriIrisNotesFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    readonly property int words: String(root.widget.noteText ?? "").trim().split(/\s+/).filter(word => word.length > 0).length

    FaceHeader {
        face: root
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.dp(20)
        glyph: "edit_note"
        text: nayoriIrisNotesFace.translation.tr("Notes")
        tint: nayoriIrisNotesFace.irisStyle.identity.yellow
        trailing: root.words > 0 && !root.small ? nayoriIrisNotesFace.translation.tr("%1 words").arg(root.words) : ""
    }
}
