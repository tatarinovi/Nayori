import QtQuick
import "../BridgeContext.js" as BridgeContext
Item {
    property var targetScreen: null
    signal lyricsSelected(string filePath,string fileName)
    function openPicker() { BridgeContext.find(parent).requestSettings() }
}
