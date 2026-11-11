import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts



Item {
    readonly property var nayoriImageFaceRect: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 30
    property real minHeight: 30
    property real maxWidth: 4000
    property real maxHeight: 4000
    property real minAspect: 0.02
    property real maxAspect: 50.0
    property bool isRound: false
    // The Stage slot can own the backing without covering this face.
    property bool ryokuBare: false


    property string imagePath: ""
    property bool fitCrop: false

    Rectangle {
        anchors.fill: parent
        color: (root.ryokuBare || root.imagePath !== "") ? "transparent" : nayoriImageFaceRect.pythonTheme.surface0
        clip: true

        BoundedImage {
            id: srcImage
            anchors.fill: parent
            source: root.imagePath !== "" ? (root.imagePath.startsWith("file://") ? root.imagePath : "file://" + root.imagePath) : ""
            fillMode: root.fitCrop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            cache: true
            smooth: true
            antialiasing: true
            playing: root.visible
            visible: status === Image.Ready
        }

        Item {
            anchors.fill: parent
            visible: root.imagePath === "" || srcImage.status !== Image.Ready

            Text {
                anchors.centerIn: parent
                text: "󰋩"
                font.family: nayoriImageFaceRect.pythonTheme.iconFont
                font.pixelSize: Math.round(Math.max(16, Math.min(root.width, root.height) * 0.35))
                color: nayoriImageFaceRect.pythonTheme.subtext0
            }
        }
    }
}
