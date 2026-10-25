pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property var tokens
    property var lyrics: null
    property bool compact: false
    readonly property int textSize: compact ? 13 : 18
    readonly property bool reduced: tokens.motion.off
    readonly property real position: lyrics && typeof lyrics.position === "number" ? lyrics.position : 0
    readonly property string current: lyrics ? lyrics.currentLine || "♪" : "♪"
    readonly property var words: lyrics && Array.isArray(lyrics.currentWords) && lyrics.currentWords.length
        ? lyrics.currentWords : [{text: current, at: 0}]
    readonly property var rows: {
        const output = []; let row = [], used = 0
        for (const word of words) {
            const size = metrics.advanceWidth(word.text)
            if (row.length && used + size > width - 8) { output.push(row); row = []; used = 0 }
            row.push(word); used += size
        }
        if (row.length) output.push(row)
        return output
    }
    FontMetrics { id: metrics; font.family: root.tokens.type.display.family; font.pixelSize: root.textSize }
    IslandLabel {
        objectName: "previousLyricLine"
        visible: !root.compact
        tokens: root.tokens
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        width: parent.width
        text: root.lyrics ? root.lyrics.previousLine || "" : ""
        font.pixelSize: 12; opacity: 0.38
        horizontalAlignment: Text.AlignHCenter
        maximumLineCount: 1; elide: Text.ElideRight
    }
    Item {
        anchors { fill: parent; topMargin: root.compact ? 3 : 20; bottomMargin: root.compact ? 3 : 20 }
        clip: true
        Column {
            anchors.centerIn: parent
            spacing: 0
            Repeater {
                model: root.rows
                delegate: Row {
                    id: line
                    required property var modelData
                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    Repeater {
                        model: line.modelData
                        delegate: IslandLabel {
                            id: word
                            required property var modelData
                            tokens: root.tokens
                            text: modelData.text
                            font.family: root.tokens.type.display.family
                            font.pixelSize: root.textSize
                            wrapMode: Text.NoWrap
                            property bool ready: false
                            readonly property bool sung: root.reduced || root.position >= modelData.at
                            opacity: ready && sung ? 1 : 0.24
                            transform: Translate { y: root.reduced || (word.ready && word.sung) ? 0 : 3
                                Behavior on y { NumberAnimation { duration: root.reduced ? 0 : 160; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1] } }
                            }
                            Behavior on opacity { NumberAnimation { duration: root.reduced ? 0 : 160; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1] } }
                            Component.onCompleted: ready = true
                        }
                    }
                }
            }
        }
    }
    IslandLabel {
        objectName: "nextLyricLine"
        visible: !root.compact
        tokens: root.tokens
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: parent.width
        text: root.lyrics ? root.lyrics.nextLine || "" : ""
        font.pixelSize: 12; opacity: 0.38
        horizontalAlignment: Text.AlignHCenter
        maximumLineCount: 1; elide: Text.ElideRight
    }
}
