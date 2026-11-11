import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects



Item {
    readonly property var nayoriImageFaceRound: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent

    property real minWidth: 40
    property real minHeight: 40
    property real maxWidth: 3000
    property real maxHeight: 3000
    property real minAspect: 1.0
    property real maxAspect: 1.0
    property bool isRound: true
    // The Stage slot can own the backing without covering this face.
    property bool ryokuBare: false


    property string imagePath: ""

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: (!root.ryokuBare && (root.imagePath === "" || srcImage.status !== Image.Ready)) ? nayoriImageFaceRound.pythonTheme.surface0 : "transparent"
        radius: width / 2
        antialiasing: true

        Item {
            id: maskContainer
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.samples: 4
            layer.textureSize: Qt.size(
                Math.max(1, Math.ceil(width * (Screen.devicePixelRatio ? Screen.devicePixelRatio : 1) * 2)),
                Math.max(1, Math.ceil(height * (Screen.devicePixelRatio ? Screen.devicePixelRatio : 1) * 2))
            )

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "white"
                antialiasing: true
            }
        }

        Item {
            id: imageContainer
            anchors.fill: parent
            visible: root.imagePath !== "" && srcImage.status === Image.Ready
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.samples: 4
            layer.textureSize: Qt.size(
                Math.max(1, Math.ceil(width * (Screen.devicePixelRatio ? Screen.devicePixelRatio : 1) * 2)),
                Math.max(1, Math.ceil(height * (Screen.devicePixelRatio ? Screen.devicePixelRatio : 1) * 2))
            )
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskContainer
                autoPaddingEnabled: false
            }

            BoundedImage {
                id: srcImage
                anchors.fill: parent
                source: root.imagePath !== "" ? (root.imagePath.startsWith("file://") ? root.imagePath : "file://" + root.imagePath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                antialiasing: true
                playing: root.visible
            }
        }

        Item {
            anchors.fill: parent
            visible: root.imagePath === "" || srcImage.status !== Image.Ready

            Text {
                anchors.centerIn: parent
                text: "󰋩"
                font.family: nayoriImageFaceRound.pythonTheme.iconFont
                font.pixelSize: Math.round(Math.max(16, Math.min(root.width, root.height) * 0.35))
                color: nayoriImageFaceRound.pythonTheme.subtext0
            }
        }
    }
}
