import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick
import Quickshell.Widgets






ClippingRectangle {
    readonly property var nayoriFaceAvatar: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property int sourceIndex: 0
    readonly property string primarySource: nayoriFaceAvatar.directories.userAvatarSourcePrimary
    onPrimarySourceChanged: root.sourceIndex = 0

    radius: width / 2
    color: nayoriFaceAvatar.irisStyle.fill

    IrisImage {
        id: picture
        anchors.fill: parent
        source: nayoriFaceAvatar.directories.avatarSourceAt(root.sourceIndex)
        onStatusChanged: {
            if (status === Image.Error && root.sourceIndex + 1 < nayoriFaceAvatar.directories.userAvatarPaths.length)
                Qt.callLater(() => root.sourceIndex++)
        }
    }
    StyledText {
        anchors.centerIn: parent
        visible: picture.status !== Image.Ready
        text: (nayoriFaceAvatar.systemInfo.displayName || nayoriFaceAvatar.systemInfo.username || "?").charAt(0).toUpperCase()
        color: nayoriFaceAvatar.irisStyle.text
        font.family: nayoriFaceAvatar.irisStyle.fontTitle
        font.pixelSize: root.height * 0.42
        font.weight: nayoriFaceAvatar.irisStyle.weight(Font.DemiBold)
    }
}
