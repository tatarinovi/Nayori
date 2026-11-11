import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick

// Plain Photo (1x2): just the picture. See PlainPhoto.
PlainPhoto {
    readonly property var nayoriPlainPhoto1x2Widget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    configEntryName: "photo_plain_1x2"
    designWidth: 240
    designHeight: 492
}
