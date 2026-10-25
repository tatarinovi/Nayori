import QtQuick

Rectangle {
    id: root
    required property url source
    required property string mode
    required property color backgroundColor
    // Preview uses this ratio to keep Center at native desktop size.
    property real nativeScale: 1
    readonly property bool failed: picture.status === Image.Error
    readonly property bool loaded: picture.status === Image.Ready
    color: backgroundColor
    clip: true
    Image {
        id: picture
        anchors.centerIn: parent
        width: root.mode === "center" ? implicitWidth * root.nativeScale : root.width
        height: root.mode === "center" ? implicitHeight * root.nativeScale : root.height
        source: root.source
        asynchronous: true
        autoTransform: true
        cache: false
        fillMode: root.mode === "fill" ? Image.PreserveAspectCrop
            : root.mode === "fit" ? Image.PreserveAspectFit
            : Image.Stretch
        visible: status === Image.Ready
    }
}
