import QtQuick

// Keep the last decoded frame until the replacement is ready. A brief empty
// MPRIS art URL between tracks must not clear an otherwise valid image.
Image {
    id: root
    property url requestedSource
    property bool retained: false
    readonly property bool ready: retained && (status === Image.Ready || status === Image.Loading)
    asynchronous: true
    retainWhileLoading: true
    fillMode: Image.PreserveAspectCrop
    sourceSize: Qt.size(512, 512)

    function updateSource() {
        if (String(requestedSource)) {
            clearDelay.stop()
            source = requestedSource
        } else {
            clearDelay.restart()
        }
    }
    onRequestedSourceChanged: updateSource()
    Component.onCompleted: updateSource()
    onStatusChanged: {
        if (status === Image.Ready) retained = true
        else if (status === Image.Error || status === Image.Null) retained = false
    }
    Timer {
        id: clearDelay
        interval: 300
        onTriggered: root.source = ""
    }
}
