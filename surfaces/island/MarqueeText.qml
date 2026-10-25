pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property var tokens
    property string text: ""
    property bool animateLines: false
    property string shownText: text
    property string previousText: ""
    property real previousOffset: 0
    property real lineBlend: 1
    property bool active: true
    property bool centered: false
    property var words: []
    property real position: 0
    property real lineEnd: 0
    readonly property bool wordProgress: words.length > 0
    readonly property real sungWidth: {
        if (!wordProgress) return label.implicitWidth
        let width = 0
        for (let i = 0; i < words.length; i++) {
            const word = words[i]
            const end = i + 1 < words.length ? words[i + 1].at : lineEnd
            const fraction = end > word.at ? Math.max(0, Math.min(1, (position - word.at) / (end - word.at))) : (position >= word.at ? 1 : 0)
            width += metrics.advanceWidth(word.text) * fraction
        }
        return width
    }
    FontMetrics { id: metrics; font: label.font }
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
    onTextChanged: {
        previousText = shownText
        previousOffset = offset
        shownText = text
        if (animateLines && active && !tokens.motion.off && previousText) {
            lineBlend = 0
            lineFade.restart()
        } else { lineFade.stop(); lineBlend = 1 }
        Qt.callLater(reset)
    }
    onActiveChanged: if (!active) { lineFade.stop(); lineBlend = 1 }
    NumberAnimation {
        id: lineFade
        target: root; property: "lineBlend"; to: 1
        duration: root.tokens.motion.base
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
    }
    onWidthChanged: Qt.callLater(reset)
    onScrollingChanged: reset()

    Text {
        text: root.previousText
        textFormat: Text.PlainText
        wrapMode: Text.NoWrap
        font: label.font
        color: root.tokens.color.text
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        opacity: 1 - root.lineBlend
        visible: opacity > 0
        x: root.centered && implicitWidth <= root.width ? (root.width - implicitWidth) / 2 : -root.previousOffset
        transform: Translate { y: root.tokens.motion.off ? 0 : -5 * root.lineBlend }
    }
    Item {
        opacity: root.lineBlend
        x: root.centered && !root.overflowing ? (root.width - label.implicitWidth) / 2 : 0
        width: parent.width
        height: parent.height
        transform: Translate { x: -root.offset; y: root.tokens.motion.off ? 0 : 5 * (1 - root.lineBlend) }
        Text {
            id: label
            height: parent.height
            width: implicitWidth
            verticalAlignment: Text.AlignVCenter
            text: root.shownText
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
            elide: Text.ElideNone
            color: root.wordProgress ? Qt.alpha(root.tokens.color.text, 0.32) : root.tokens.color.textMuted
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            font.weight: root.tokens.type.body.weight
        }
        Repeater {
            model: root.wordProgress ? 2 : 0
            delegate: Item {
                required property int index
                x: index * root.stride
                height: parent.height
                width: root.sungWidth
                visible: index === 0 || root.scrolling
                clip: true
                Behavior on width { enabled: !root.tokens.motion.off; NumberAnimation { duration: root.tokens.motion.fast; easing.type: Easing.Linear } }
                Text {
                    height: parent.height
                    text: root.shownText
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    verticalAlignment: Text.AlignVCenter
                    font: label.font
                    color: root.tokens.color.text
                }
            }
        }
        Text {
            x: root.stride
            height: parent.height
            visible: root.scrolling
            verticalAlignment: Text.AlignVCenter
            text: root.shownText
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
