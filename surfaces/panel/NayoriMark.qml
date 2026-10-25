import QtQuick

Image {
    required property color ink
    property string variant: "current"
    width: 30
    height: 30
    source: variant === "fox" ? "../../assets/branding/nayori-fox-logo.png" : "../../assets/branding/nayori-start.png"
    sourceSize.width: variant === "fox" ? 256 : 120
    sourceSize.height: variant === "fox" ? 256 : 120
    sourceClipRect: variant === "fox" ? Qt.rect(48, 42, 163, 184) : Qt.rect(0, 0, 0, 0)
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
}
