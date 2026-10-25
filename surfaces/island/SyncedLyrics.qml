pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property var tokens
    property var lyrics: null
    property bool compact: false
    readonly property int textSize: {
        if (compact) return 13
        for (const measure of [size18, size16, size14, size12]) {
            let count = 1, used = 0
            for (const word of words) {
                const advance = measure.advanceWidth(word.text)
                if (used > 0 && used + advance > width - 8) { count++; used = 0 }
                used += advance
            }
            if (count * measure.height * 1.25 <= Math.max(1, height - 23)) return measure.font.pixelSize
        }
        return 12
    }
    FontMetrics { id: size18; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    FontMetrics { id: size16; font.family: root.tokens.type.display.family; font.pixelSize: 16 }
    FontMetrics { id: size14; font.family: root.tokens.type.display.family; font.pixelSize: 14 }
    FontMetrics { id: size12; font.family: root.tokens.type.display.family; font.pixelSize: 12 }
    readonly property int activeRow: {
        if (!lyrics || !lyrics.currentWords || !lyrics.currentWords.length) return 0
        let active = 0
        for (let i = 0; i < rows.length; i++)
            if (rows[i].some(word => word.at <= position)) active = i
        return active
    }
    readonly property bool reduced: tokens.motion.off
    property string lastLine: current
    property string leavingLine: ""
    property real lineBlend: 1
    onCurrentChanged: {
        leavingLine = lastLine
        lastLine = current
        if (visible && !reduced && leavingLine) { lineBlend = 0; lineFade.restart() }
        else { lineFade.stop(); lineBlend = 1 }
    }
    onVisibleChanged: if (!visible) { lineFade.stop(); lineBlend = 1 }
    NumberAnimation {
        id: lineFade
        target: root; property: "lineBlend"; to: 1
        duration: root.tokens.motion.base
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
    }
    readonly property real position: lyrics && typeof lyrics.position === "number" ? lyrics.position : 0
    readonly property string current: lyrics ? lyrics.currentLine || "♪" : "♪"
    readonly property var words: lyrics && Array.isArray(lyrics.currentWords) && lyrics.currentWords.length
        ? lyrics.currentWords : (current.match(/\s*\S+\s*/g) || []).map(word => ({text: word, at: 0}))
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
    Item {
        anchors { fill: parent; topMargin: 3; bottomMargin: root.compact ? 3 : 20 }
        clip: true
        IslandLabel {
            tokens: root.tokens
            anchors.fill: parent
            text: root.leavingLine
            font.family: root.tokens.type.display.family
            font.pixelSize: root.textSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: 1 - root.lineBlend
            visible: opacity > 0
            transform: Translate { y: root.reduced ? 0 : -4 * root.lineBlend }
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: height <= parent.height ? (parent.height - height) / 2
                : Math.min(0, Math.max(parent.height - height, parent.height / 2 - (root.activeRow + 0.5) * metrics.height * 1.25))
            opacity: root.lineBlend
            transform: Translate { y: root.reduced ? 0 : 4 * (1 - root.lineBlend) }
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
                            Behavior on opacity { NumberAnimation { duration: root.reduced ? 0 : root.tokens.motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1] } }
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
        font.family: root.tokens.type.display.family
        font.pixelSize: 12; opacity: 0.38 * root.lineBlend
        horizontalAlignment: Text.AlignHCenter
        maximumLineCount: 1; elide: Text.ElideRight
    }
}
