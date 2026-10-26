pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
PanelWindow {
    id: grabber
    property var host: null
    implicitWidth: 1; implicitHeight: 1
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nayori-notify-grab"
    mask: Region {}
    Image {
        id: picture
        source: grabber.host && grabber.host.job ? grabber.host.job.source : ""
        cache: false
        width: implicitWidth; height: implicitHeight
        onStatusChanged: {
            if (status === Image.Ready && width > 0 && height > 0) grab.restart()
            else if (status === Image.Error || (status === Image.Ready)) grabber.host.finishExport("")
        }
    }
    Timer {
        id: grab
        interval: 30
        onTriggered: {
            const path = grabber.host.imageDirectory + "/" + grabber.host.job.id + "-" + (++grabber.host.exportCounter) + ".png"
            picture.grabToImage(result => grabber.host.finishExport(result.saveToFile(path) ? path : ""))
        }
    }
}
