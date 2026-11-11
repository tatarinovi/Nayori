import QtQuick

Rectangle {
    id: root
    required property url source
    required property string mode
    required property color backgroundColor
    // Preview uses this ratio to keep Center at native desktop size.
    property real nativeScale: 1
    property var blurFrame: null
    property real blurOpacity: 0
    property bool reduceMotion: false
    property int effectDuration: 300
    onReduceMotionChanged: if (reduceMotion) readinessAnimation.complete()
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
    Image {
        id: blurred
        objectName: "wallpaper-blur-image"
        anchors.centerIn: parent
        readonly property var nativeSize: root.blurFrame ? root.blurFrame.originalSize : null
        width: root.mode === "center" && nativeSize ? nativeSize[0] * root.nativeScale : root.width
        height: root.mode === "center" && nativeSize ? nativeSize[1] * root.nativeScale : root.height
        source: root.blurFrame && root.blurFrame.path
            ? "file://" + encodeURI(root.blurFrame.path).replace(/#/g, "%23").replace(/\?/g, "%3F") : ""
        asynchronous: true
        fillMode: root.mode === "fill" ? Image.PreserveAspectCrop
            : root.mode === "fit" ? Image.PreserveAspectFit : Image.Stretch
        // A missing/corrupt cache never covers a valid sharp wallpaper.
        property real readiness: status === Image.Ready && picture.status === Image.Ready ? 1 : 0
        opacity: readiness * root.blurOpacity
        Behavior on readiness {
            NumberAnimation { id: readinessAnimation; duration: root.reduceMotion ? 0 : root.effectDuration; easing.type: Easing.OutCubic }
        }
        visible: opacity > 0
    }
}
