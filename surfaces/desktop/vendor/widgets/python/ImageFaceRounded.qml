import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects



Item {
    readonly property var nayoriImageFaceRounded: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent

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
        id: bgRect
        anchors.fill: parent
        color: (!root.ryokuBare && (root.imagePath === "" || srcImage.status !== Image.Ready)) ? nayoriImageFaceRounded.pythonTheme.surface0 : "transparent"
        radius: nayoriImageFaceRounded.pythonTheme.borderRadius !== undefined ? nayoriImageFaceRounded.pythonTheme.borderRadius : 12
        antialiasing: true

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
            visible: false
        }

        Item {
            id: maskContainer
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true

            Rectangle {
                x: Math.round((parent.width - (srcImage.paintedWidth > 0 ? srcImage.paintedWidth : parent.width)) / 2)
                y: Math.round((parent.height - (srcImage.paintedHeight > 0 ? srcImage.paintedHeight : parent.height)) / 2)
                width: Math.round(srcImage.paintedWidth > 0 ? srcImage.paintedWidth : parent.width)
                height: Math.round(srcImage.paintedHeight > 0 ? srcImage.paintedHeight : parent.height)
                radius: nayoriImageFaceRounded.pythonTheme.borderRadius !== undefined ? nayoriImageFaceRounded.pythonTheme.borderRadius : 12
                color: "white"
                antialiasing: true
            }
        }

        MultiEffect {
            id: effect
            anchors.fill: parent
            source: srcImage
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: maskContainer
            visible: root.imagePath !== "" && srcImage.status === Image.Ready
        }

        Item {
            anchors.fill: parent
            visible: root.imagePath === "" || srcImage.status !== Image.Ready

            Text {
                anchors.centerIn: parent
                text: "󰋩"
                font.family: nayoriImageFaceRounded.pythonTheme.iconFont
                font.pixelSize: Math.round(Math.max(16, Math.min(root.width, root.height) * 0.35))
                color: nayoriImageFaceRounded.pythonTheme.subtext0
            }
        }
    }
}
