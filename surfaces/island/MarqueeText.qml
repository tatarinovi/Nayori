pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property var tokens
    property string text: ""
    property bool active: true
    property bool centered: false
    readonly property bool overflowing: label.implicitWidth > width && width > 0
    readonly property bool scrolling: active && visible && !tokens.motion.off && overflowing
    readonly property real stride: label.implicitWidth + 32
    property real offset: 0
    clip: true
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    function reset() {
        movement.stop()
        offset = 0
        if (scrolling) movement.start()
    }
    onTextChanged: Qt.callLater(reset)
    onWidthChanged: Qt.callLater(reset)
    onScrollingChanged: reset()

    Item {
        x: root.centered && !root.overflowing ? (root.width - label.implicitWidth) / 2 : 0
        width: parent.width
        height: parent.height
        transform: Translate { x: -root.offset }
        Text {
            id: label
            height: parent.height
            width: implicitWidth
            verticalAlignment: Text.AlignVCenter
            text: root.text
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
            elide: Text.ElideNone
            color: root.tokens.color.textMuted
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            font.weight: root.tokens.type.body.weight
        }
        Text {
            x: root.stride
            height: parent.height
            visible: root.scrolling
            verticalAlignment: Text.AlignVCenter
            text: root.text
            textFormat: Text.PlainText
            font: label.font
            color: label.color
        }
    }
    SequentialAnimation {
        id: movement
        loops: Animation.Infinite
        PauseAnimation { duration: 1000 }
        NumberAnimation {
            target: root
            property: "offset"
            from: 0
            to: root.stride
            duration: Math.round(root.stride / 28 * 1000)
            easing.type: Easing.Linear
        }
        PropertyAction { target: root; property: "offset"; value: 0 }
    }
}
