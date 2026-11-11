import QtQuick
import Quickshell
import "../BridgeContext.js" as BridgeContext
// Shared-MPRIS seam for the unchanged IrisNowPlayingFace.
Item {
    id: root
    readonly property var bridge: BridgeContext.find(parent)
    required property var player
    property bool positionUpdatesActive: true
    readonly property bool effectiveIsPlaying: !!player && player.isPlaying
    readonly property string displayedArtFilePath: player ? player.trackArtUrl || "" : ""
    readonly property string effectiveTitle: player ? player.trackTitle || "" : ""
    readonly property string effectiveArtist: player ? player.trackArtist || "" : ""
    readonly property real effectiveLength: player ? player.length || 0 : 0
    readonly property real effectivePosition: bridge.music ? bridge.music.position : 0
    readonly property bool effectiveCanGoPrevious: !!player && player.canGoPrevious
    readonly property bool effectiveCanGoNext: !!player && player.canGoNext
    readonly property var colorQuantizer: quantizer
    ColorQuantizer { id: quantizer; source: root.displayedArtFilePath; depth:0; rescaleSize:1 }
    function previous() { if (effectiveCanGoPrevious) player.previous() }
    function next() { if (effectiveCanGoNext) player.next() }
    function togglePlaying() { if (player) player.togglePlaying() }
    function seek(value) { if (player && player.canSeek) player.position = value }
}
