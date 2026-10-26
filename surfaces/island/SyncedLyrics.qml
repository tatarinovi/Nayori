pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property var tokens
    property var lyrics: null
    property bool compact: false
    property real lineEnd: 0
    readonly property int textSize: compact ? 13 : 18
    readonly property real rowHeight: Math.ceil(textSize * 1.35)
    readonly property bool reduced: tokens.motion.off
    readonly property real position: lyrics && typeof lyrics.position === "number" ? lyrics.position : 0
    readonly property string current: lyrics ? lyrics.currentLine || "♪" : "♪"
    readonly property var words: lyrics && Array.isArray(lyrics.currentWords) && lyrics.currentWords.length
        ? lyrics.currentWords : (current.match(/\s*\S+\s*/g) || []).map(word => ({text: word, at: 0}))
    readonly property int activeRow: {
        if (!lyrics || !lyrics.currentWords || !lyrics.currentWords.length) return 0
        let active = 0
        for (let i = 0; i < rows.length; i++)
            if (rows[i].some(word => word.at <= position)) active = i
        return active
    }
    readonly property var rows: {
        const output = []
        let row = [], used = 0
        const available = Math.max(1, width - 8)
        function flush() {
            if (row.length) output.push(row)
            row = []; used = 0
        }
        for (const word of words) {
            for (const part of word.text.split(/(\r?\n)/)) {
                if (/^\r?\n$/.test(part)) { flush(); continue }
                if (!part) continue
                const advance = metrics.advanceWidth(part)
                if (row.length && used + advance > available) flush()
                if (advance <= available) {
                    row.push({text: part, at: word.at}); used += advance
                } else {
                    // A single long token must fit too, without reducing the font.
                    for (const character of Array.from(part)) {
                        const size = metrics.advanceWidth(character)
                        if (row.length && used + size > available) flush()
                        row.push({text: character, at: word.at}); used += size
                    }
                }
            }
        }
        flush()
        return output
    }
    FontMetrics { id: metrics; font.family: root.tokens.type.display.family; font.pixelSize: root.textSize; font.weight: Font.Medium }

    property real lineBlend: 1
    onCurrentChanged: {
        // Only the incoming line is drawn: outgoing words never overlap it.
        if (visible && !reduced) { lineBlend = 0; lineFade.restart() }
        else { lineFade.stop(); lineBlend = 1 }
    }
    onVisibleChanged: if (!visible) { lineFade.stop(); lineBlend = 1 }
    NumberAnimation {
        id: lineFade
        target: root; property: "lineBlend"; to: 1
        duration: root.tokens.motion.fast
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
    }

    // Centre the whole current/next group; the gap never grows for short lines.
    Column {
        id: group
        anchors.centerIn: parent
        width: parent.width
        spacing: nextLine.visible ? 4 : 0
        Item {
            id: viewport
            objectName: "currentLyricViewport"
            width: parent.width
            height: Math.max(0, Math.min(Math.min(root.rows.length, 2) * root.rowHeight,
                root.height - (nextLine.visible ? nextLine.height + group.spacing : 0)))
            clip: true
            readonly property int visibleRows: Math.max(1, Math.floor(height / root.rowHeight))
            readonly property int firstRow: Math.max(0, Math.min(root.rows.length - visibleRows, root.activeRow - visibleRows + 1))
            Column {
                id: currentLines
                objectName: "currentLyricLines"
                anchors.horizontalCenter: parent.horizontalCenter
                y: -viewport.firstRow * root.rowHeight
                opacity: root.lineBlend
                spacing: 0
                Repeater {
                    model: root.rows
                    delegate: Row {
                        id: line
                        required property var modelData
                        height: root.rowHeight
                        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                        Repeater {
                            model: line.modelData
                            delegate: Item {
                                id: word
                                required property var modelData
                                width: baseText.implicitWidth
                                height: root.rowHeight
                                readonly property real end: {
                                    for (const next of root.words)
                                        if (next.at > modelData.at) return next.at
                                    return root.lineEnd > modelData.at ? root.lineEnd : modelData.at + 1
                                }
                                readonly property real fraction: !root.lyrics || !root.lyrics.currentWords || !root.lyrics.currentWords.length
                                    ? 1 : Math.max(0, Math.min(1, (root.position - modelData.at) / (end - modelData.at)))
                                IslandLabel {
                                    id: baseText
                                    tokens: root.tokens
                                    text: word.modelData.text
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: root.tokens.type.display.family
                                    font.pixelSize: root.textSize
                                    wrapMode: Text.NoWrap
                                    lineHeight: 1
                                    color: Qt.alpha(root.tokens.color.text, 0.32)
                                }
                                Item {
                                    objectName: "lyricWordFill"
                                    width: word.width * word.fraction
                                    height: parent.height
                                    clip: true
                                    Behavior on width {
                                        enabled: !root.reduced
                                        NumberAnimation { duration: root.tokens.motion.fast; easing.type: Easing.Linear }
                                    }
                                    IslandLabel {
                                        tokens: root.tokens
                                        text: word.modelData.text
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                        font: baseText.font
                                        wrapMode: Text.NoWrap
                                        lineHeight: 1
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        IslandLabel {
            id: nextLine
            objectName: "nextLyricLine"
            visible: !root.compact && text.length > 0
            tokens: root.tokens
            width: parent.width
            height: 14
            text: root.lyrics ? root.lyrics.nextLine || "" : ""
            font.pixelSize: 11
            lineHeight: 1
            color: root.tokens.color.textMuted
            opacity: 0.5
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            maximumLineCount: 1
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }
    }
}
