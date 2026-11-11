import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick

// Plain Photo (2x1): just the picture. See PlainPhoto.
PlainPhoto {
    readonly property var nayoriPlainPhoto2x1Widget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    configEntryName: "photo_plain_2x1"
    designWidth: 492
    designHeight: 240
}
