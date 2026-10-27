pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../settings"

PanelWindow {
    id: root
    required property var tokens
    required property var service
    required property string outputName
    visible: service.editing && outputName === service.output
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nayori-capture"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Native island remains above this frozen layer and accepts its own input.
    mask: Region {
        width: root.width; height: root.height
        Region { intersection: Intersection.Subtract; x: 0; y: 0; width: root.width; height: 64 }
    }
    property var liveMark: null
    property point origin: Qt.point(0, 0)
    property var startArea: null
    property string dragMode: ""
    readonly property var area: service.area
    readonly property bool hasArea: area.w >= 2 && area.h >= 2
    readonly property bool editing: service.state === "edit"
    readonly property var allMarks: liveMark ? service.marks.concat([liveMark]) : service.marks
    onVisibleChanged: if (visible) Qt.callLater(function() { editor.forceActiveFocus(Qt.OtherFocusReason) })
    function commitText() {
        if (!textInput.visible) return
        if (textInput.text.trim() !== "") service.addMark({tool: "text", x: textInput.x, y: textInput.y, text: textInput.text})
        textInput.visible = false; textInput.text = ""
        editor.forceActiveFocus(Qt.OtherFocusReason)
    }
    function save(copy) { commitText(); service.save(copy) }
    FocusScope {
        id: editor
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (textInput.activeFocus) return
            const command = !!(event.modifiers & Qt.ControlModifier)
            const letter = String(event.text).toLowerCase()
            if (event.key === Qt.Key_Escape) { root.service.cancel(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.editing) root.save(true)
                else if (root.service.state === "setup") root.service.start()
                else root.service.next()
                event.accepted = true
            }
            else if (root.editing && command && event.key === Qt.Key_Z) { root.service.undo(); event.accepted = true }
            else if (root.editing && command && event.key === Qt.Key_Y) { root.service.redo(); event.accepted = true }
            else if (root.editing && command && event.key === Qt.Key_C) { root.save(true); event.accepted = true }
            else if (root.editing && command && event.key === Qt.Key_S) { root.save(false); event.accepted = true }
            else if (root.editing && !command && !(event.modifiers & Qt.AltModifier)) {
                const tool = {a: "arrow", "ф": "arrow", r: "rect", "к": "rect", t: "text", "е": "text", b: "blur", "и": "blur"}[letter]
                if (tool) { root.service.tool = tool; event.accepted = true }
            }
        }
        Shortcut {
            sequences: ["Return", "Enter"]
            context: Qt.WindowShortcut
            enabled: root.visible && (root.editing || root.service.state === "setup") && !textInput.activeFocus && !colorPopup.opened
            onActivated: {
                if (root.service.state === "setup") root.service.start()
                else root.save(true)
            }
        }
        Image {
            id: frame
            anchors.fill: parent
            source: root.service.source
            cache: false
            fillMode: Image.Stretch
            onStatusChanged: if (status === Image.Error) root.service.error = "Не удалось открыть снимок. Повторите захват."
        }
        // Four scrims leave the selected pixels unchanged.
        Rectangle { x: 0; y: 0; width: parent.width; height: root.hasArea ? root.area.y : parent.height; color: "#88000000" }
        Rectangle { x: 0; y: root.area.y; width: root.hasArea ? root.area.x : 0; height: root.area.h; color: "#88000000" }
        Rectangle { x: root.area.x + root.area.w; y: root.area.y; width: root.hasArea ? Math.max(0, parent.width - x) : 0; height: root.area.h; color: "#88000000" }
        Rectangle { x: 0; y: root.area.y + root.area.h; width: parent.width; height: root.hasArea ? Math.max(0, parent.height - y) : 0; color: "#88000000" }
        Repeater {
            model: root.allMarks.filter(mark => mark.tool === "blur")
            delegate: Item {
                id: blurPatch
                required property var modelData
                x: Math.min(modelData.x, modelData.ex); y: Math.min(modelData.y, modelData.ey)
                width: Math.max(1, Math.abs(modelData.ex - modelData.x)); height: Math.max(1, Math.abs(modelData.ey - modelData.y))
                clip: true
                ShaderEffectSource { id: patch; sourceItem: frame; sourceRect: Qt.rect(blurPatch.x, blurPatch.y, blurPatch.width, blurPatch.height); visible: false; live: true }
                MultiEffect { anchors.fill: parent; source: patch; blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 2; autoPaddingEnabled: false }
            }
        }
        Canvas {
            id: annotationCanvas
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d"); c.reset()
                root.allMarks.forEach(m => {
                    if (m.tool === "blur") return
                    c.strokeStyle = m.color || root.service.ink; c.fillStyle = m.color || root.service.ink
                    c.lineWidth = m.size || root.service.lineSize; c.lineCap = "round"; c.lineJoin = "round"
                    if (m.tool === "text") { c.font = '22px "DejaVu Sans"'; c.textBaseline = "top"; c.fillText(m.text || "", m.x, m.y); return }
                    c.beginPath()
                    if (m.tool === "rect") c.rect(Math.min(m.x, m.ex), Math.min(m.y, m.ey), Math.abs(m.ex - m.x), Math.abs(m.ey - m.y))
                    else if (m.tool === "arrow") {
                        c.moveTo(m.x, m.y); c.lineTo(m.ex, m.ey)
                        const a = Math.atan2(m.ey - m.y, m.ex - m.x), n = Math.max(12, c.lineWidth * 4)
                        c.moveTo(m.ex - n * Math.cos(a - .5), m.ey - n * Math.sin(a - .5)); c.lineTo(m.ex, m.ey)
                        c.lineTo(m.ex - n * Math.cos(a + .5), m.ey - n * Math.sin(a + .5))
                    }
                    c.stroke()
                })
            }
            Connections { target: root; function onAllMarksChanged() { annotationCanvas.requestPaint() } }
        }
        Rectangle {
            visible: root.hasArea
            x: root.area.x; y: root.area.y; width: root.area.w; height: root.area.h
            color: "transparent"; border.width: 1; border.color: root.tokens.color.accent
            Repeater {
                model: [{x: 0, y: 0}, {x: 1, y: 0}, {x: 0, y: 1}, {x: 1, y: 1}]
                Rectangle {
                    required property var modelData
                    width: 8; height: 8; radius: 2
                    x: modelData.x * parent.width - 4; y: modelData.y * parent.height - 4
                    color: root.tokens.color.text; border.width: 1; border.color: root.tokens.color.accent
                }
            }
            Rectangle {
                x: 0; y: parent.y > 96 ? -29 : 5
                width: sizeLabel.implicitWidth + 16; height: 23; radius: 5; color: root.tokens.material.dense
                Text { id: sizeLabel; anchors.centerIn: parent; color: root.tokens.color.text; font.family: root.tokens.type.body.family; font.pixelSize: 12; text: root.area.w + " × " + root.area.h }
            }
        }
        MouseArea {
            id: drawing
            anchors.fill: parent
            enabled: root.service.state === "select" || root.editing || root.service.state === "setup"
            cursorShape: root.editing ? Qt.CrossCursor : Qt.SizeAllCursor
            onPressed: mouse => {
                root.commitText()
                root.origin = Qt.point(mouse.x, mouse.y)
                root.startArea = Object.assign({}, root.area)
                const inside = root.hasArea && mouse.x >= root.area.x && mouse.x <= root.area.x + root.area.w && mouse.y >= root.area.y && mouse.y <= root.area.y + root.area.h
                if (root.editing) {
                    if (!inside) { root.dragMode = ""; return }
                    if (root.service.tool === "text") {
                        textInput.x = Math.max(root.area.x, Math.min(mouse.x, root.area.x + root.area.w - 160)); textInput.y = Math.max(root.area.y, Math.min(mouse.y, root.area.y + root.area.h - 35))
                        textInput.visible = true; textInput.forceActiveFocus(); return
                    }
                    root.dragMode = "mark"
                    root.liveMark = {tool: root.service.tool, x: mouse.x, y: mouse.y, ex: mouse.x, ey: mouse.y, color: root.service.ink, size: root.service.lineSize}
                } else {
                    const near = (x, y) => Math.abs(mouse.x - x) < 13 && Math.abs(mouse.y - y) < 13
                    root.dragMode = near(root.area.x + root.area.w, root.area.y + root.area.h) ? "resize" : inside ? "move" : "select"
                }
            }
            onPositionChanged: mouse => {
                if (!pressed || root.dragMode === "") return
                const px = Math.max(0, Math.min(root.width, mouse.x)), py = Math.max(0, Math.min(root.height, mouse.y))
                if (root.dragMode === "mark") {
                    root.liveMark = Object.assign({}, root.liveMark, {ex: Math.max(root.area.x, Math.min(root.area.x + root.area.w, px)), ey: Math.max(root.area.y, Math.min(root.area.y + root.area.h, py))})
                } else if (root.dragMode === "move") {
                    root.service.select({x: Math.max(0, Math.min(root.width - root.startArea.w, root.startArea.x + px - root.origin.x)), y: Math.max(0, Math.min(root.height - root.startArea.h, root.startArea.y + py - root.origin.y)), w: root.startArea.w, h: root.startArea.h})
                } else if (root.dragMode === "resize") root.service.select({x: root.startArea.x, y: root.startArea.y, w: Math.max(2, px - root.startArea.x), h: Math.max(2, py - root.startArea.y)})
                else root.service.select({x: Math.min(root.origin.x, px), y: Math.min(root.origin.y, py), w: Math.abs(px - root.origin.x), h: Math.abs(py - root.origin.y)})
            }
            onReleased: {
                const selectionFinished = root.service.state === "select"
                    && root.dragMode !== "" && root.hasArea
                if (root.liveMark && (Math.abs(root.liveMark.ex - root.liveMark.x) > 2 || Math.abs(root.liveMark.ey - root.liveMark.y) > 2)) root.service.addMark(root.liveMark)
                root.liveMark = null; root.dragMode = ""
                if (selectionFinished) root.service.next()
            }
            onCanceled: { root.liveMark = null; root.dragMode = "" }
        }
        TextField {
            id: textInput
            visible: false; z: 5; width: 200; height: 36
            color: root.service.ink; font.pixelSize: 22; font.family: "DejaVu Sans"
            placeholderText: "Текст"; selectByMouse: true
            Accessible.name: "Текст разметки"
            onAccepted: root.save(true)
            Keys.onEscapePressed: { visible = false; text = ""; editor.forceActiveFocus() }
            background: Rectangle { color: root.tokens.material.dense; border.width: 1; border.color: root.service.ink; radius: 5 }
        }
        Rectangle {
            id: toolbar
            z: 10
            width: Math.min(740, parent.width - 32); height: contents.implicitHeight + 24
            anchors.horizontalCenter: parent.horizontalCenter; y: 68
            radius: 24; color: root.tokens.material.dense; border.width: 1; border.color: root.tokens.color.border
            visible: root.editing || root.service.state === "saving" || root.service.state === "setup"
            Column {
                id: contents
                x: 12; y: 12; width: parent.width - 24; spacing: 8
                RowLayout {
                    width: parent.width; spacing: 8
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.editing || root.service.state === "saving" ? "Разметка скриншота" : "Подготовка записи"
                        color: root.tokens.color.text
                        font.family: root.tokens.type.display.family
                        font.pixelSize: root.tokens.type.display.size
                        font.weight: root.tokens.type.display.weight
                        font.letterSpacing: root.tokens.type.display.letterSpacing
                        lineHeight: root.tokens.type.display.lineHeight
                        lineHeightMode: Text.ProportionalHeight
                    }
                    SettingsButton { tokens: root.tokens; text: "×"; implicitHeight: 26; implicitWidth: 28; enabled: root.service.state !== "saving"; Accessible.name: "Отменить захват"; onClicked: root.service.cancel() }
                }
                RowLayout {
                    width: parent.width; spacing: 6
                    visible: root.editing || root.service.state === "saving"
                    enabled: root.editing
                    Repeater {
                        model: [{key: "arrow", label: "↗ Стрелка · A"}, {key: "rect", label: "□ Квадрат · R"}, {key: "text", label: "T Текст · T"}, {key: "blur", label: "Блюр · B"}]
                        SettingsButton {
                            required property var modelData
                            tokens: root.tokens; text: modelData.label; primary: root.service.tool === modelData.key
                            onClicked: { root.commitText(); root.service.tool = modelData.key; editor.forceActiveFocus() }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    SettingsButton { tokens: root.tokens; text: "Цвет"; onClicked: colorPopup.open() }
                    SettingsButton {
                        tokens: root.tokens; text: root.service.lineSize + " px"
                        onClicked: root.service.lineSize = root.service.lineSize === 3 ? 5 : root.service.lineSize === 5 ? 8 : 3
                    }
                }
                RowLayout {
                    width: parent.width; spacing: 6
                    visible: root.editing || root.service.state === "saving"
                    enabled: root.editing
                    SettingsButton { tokens: root.tokens; text: "↶"; Accessible.name: "Отменить"; enabled: root.service.marks.length > 0; onClicked: root.service.undo() }
                    SettingsButton { tokens: root.tokens; text: "↷"; Accessible.name: "Повторить"; enabled: root.service.redoMarks.length > 0; onClicked: root.service.redo() }
                    Item { Layout.fillWidth: true }
                    SettingsButton { tokens: root.tokens; text: "Сохранить"; onClicked: root.save(false) }
                    SettingsButton { tokens: root.tokens; text: root.service.state === "saving" ? "Сохранение…" : "Копировать"; primary: true; onClicked: root.save(true) }
                }
                Flow {
                    width: parent.width; spacing: 6
                    visible: root.service.state === "setup"
                    SettingsButton { tokens: root.tokens; primary: root.service.options.captureMic === true; text: "Микрофон"; onClicked: root.service.changeOption("captureMic", !root.service.options.captureMic) }
                    SettingsButton { tokens: root.tokens; primary: root.service.options.captureSystemAudio === true; text: "Звук системы"; onClicked: root.service.changeOption("captureSystemAudio", !root.service.options.captureSystemAudio) }
                    SettingsButton { tokens: root.tokens; primary: root.service.options.captureCursor === true; text: "Курсор"; onClicked: root.service.changeOption("captureCursor", !root.service.options.captureCursor) }
                    SettingsButton { tokens: root.tokens; text: root.service.options.captureFps + " fps"; onClicked: root.service.changeOption("captureFps", root.service.options.captureFps === 30 ? 60 : 30) }
                    SettingsButton { tokens: root.tokens; text: "Отсчёт: " + root.service.options.captureCountdown + " с"; onClicked: root.service.changeOption("captureCountdown", root.service.options.captureCountdown === 0 ? 3 : root.service.options.captureCountdown === 3 ? 5 : 0) }
                    SettingsButton { tokens: root.tokens; primary: true; text: "Начать запись"; onClicked: root.service.start() }
                }
                Text { width: parent.width; visible: root.service.error !== ""; text: root.service.error; wrapMode: Text.Wrap; color: root.tokens.color.secondary; font.family: root.tokens.type.body.family; font.pixelSize: 12 }
            }
            Popup {
                id: colorPopup
                y: toolbar.height + 8; x: Math.max(0, toolbar.width - implicitWidth); padding: 10
                background: Rectangle { color: root.tokens.material.dense; radius: 12; border.width: 1; border.color: root.tokens.color.border }
                contentItem: Row {
                    spacing: 8
                    Repeater {
                        model: [root.service.options.captureColor || "#CAA7AA", "#F0E9DB", "#F08080", "#FFD166", "#66C7B4", "#729AE3"]
                        AbstractButton {
                            required property string modelData
                            width: 30; height: 30
                            Accessible.name: "Цвет " + modelData
                            background: Rectangle { color: parent.modelData; radius: 15; border.width: 1; border.color: root.tokens.color.border }
                            onClicked: { root.service.ink = modelData; colorPopup.close() }
                        }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: root.service.state === "countdown"
            text: root.service.countdown; color: root.tokens.color.text
            font.family: root.tokens.type.display.family; font.pixelSize: 96
        }
    }
}
