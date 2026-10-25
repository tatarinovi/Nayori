pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

Column {
    property bool showHeading: true
    required property var tokens
    property string surfaceStyle: "solid"
    signal surfaceStyleChangedRequested(string style)
    signal revealRequested(var item)
    property bool animationsEnabled: true
    signal animationsChangedRequested(bool enabled)
    property string accentMode: "default"
    signal accentModeChangedRequested(string mode)
    property string manualAccent: "#C0AFD1"
    signal manualAccentChangedRequested(string color)
    property string accentStatus: ""
    property color accentPreview: "#C0AFD1"
    property var accentCandidates: []
    signal accentResetRequested()
    property string hexNotice: ""
    property bool hexDirty: false
    readonly property string previewHex: root.canonicalHex(root.accentPreview) || "#C0AFD1"
    readonly property string manualAccentHex: root.canonicalHex(root.manualAccent) || "#C0AFD1"
    readonly property bool hasAccentCandidates: root.validCandidateCount(root.accentCandidates) > 0
    function hexByte(channel) {
        const value = Math.max(0, Math.min(255, Math.round(channel * 255)))
        const digits = "0123456789ABCDEF"
        return digits.charAt(Math.floor(value / 16)) + digits.charAt(value % 16)
    }
    function canonicalHex(value) {
        if (value === undefined || value === null)
            return ""
        let text = ""
        if (typeof value === "string")
            text = value.trim()
        else if (typeof value.r === "number" && typeof value.g === "number" && typeof value.b === "number")
            text = "#" + root.hexByte(value.r) + root.hexByte(value.g) + root.hexByte(value.b)
        else
            text = ("" + value).trim()
        const match = /^#?([0-9A-Fa-f]{6})$/.exec(text)
        return match ? "#" + match[1].toUpperCase() : ""
    }
    function validCandidateCount(list) {
        if (!list || !list.length)
            return 0
        let count = 0
        for (let i = 0; i < list.length; ++i) {
            const item = list[i]
            if (item && root.canonicalHex(item.color))
                count++
        }
        return count
    }
    function requestManualAccent(value) {
        const hex = root.canonicalHex(value)
        if (!hex)
            return
        if (hex !== root.canonicalHex(root.manualAccent))
            root.manualAccentChangedRequested(hex)
    }
    function commitHexField() {
        if (!root.hexDirty)
            return
        root.hexDirty = false
        const hex = root.canonicalHex(hexField.text)
        if (!hex) {
            root.hexNotice = "Нужен цвет вроде #C0AFD1"
            hexField.text = root.manualAccentHex
            return
        }
        root.hexNotice = ""
        if (hexField.text !== hex)
            hexField.text = hex
        root.requestManualAccent(hex)
    }
    function openAccentDialog() {
        accentDialog.selectedColor = root.canonicalHex(hexField.text) || root.manualAccentHex
        accentDialog.open()
    }
    function applyPickedColor(value) {
        const hex = root.canonicalHex(value)
        if (!hex)
            return
        root.hexNotice = ""
        root.hexDirty = false
        hexField.text = hex
        root.requestManualAccent(hex)
    }
    onManualAccentChanged: {
        if (!hexField || hexField.activeFocus)
            return
        hexField.text = manualAccentHex
        hexDirty = false
    }
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }
    id: root
            spacing: 16
            Label { visible: root.showHeading; text: "Внешний вид"; font.family: root.tokens.type.display.family; font.pixelSize: 20 }
            Label { text: "Прозрачность"; font.pixelSize: 18 }
            Label {
                width: parent.width
                text: "Выберите оформление всего интерфейса Nayori."
                color: root.tokens.color.textMuted
                font.pixelSize: 13
            }
            ButtonGroup { id: surfaceStyles }
            Repeater {
                model: [
                    {key: "solid", title: "Solid", description: "Графитовые поверхности без прозрачности"},
                    {key: "frosted", title: "Frosted Glass", description: "Матовое стекло: нижние острова прозрачнее, Dynamic Island темнее, меню пуск и настройки плотнее"}
                ]
                RadioButton {
                    id: styleOption
                    required property var modelData
                    objectName: "surfaceStyle-" + modelData.key
                    width: root.width
                    ButtonGroup.group: surfaceStyles
                    checked: root.surfaceStyle === modelData.key
                    onClicked: root.surfaceStyleChangedRequested(modelData.key)
                    focusPolicy: Qt.StrongFocus
                    onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
                    spacing: 12
                    padding: 12
                    background: Rectangle {
                        radius: root.tokens.radius.small
                        color: root.tokens.color.surfaceAlt
                        border.width: styleOption.checked || styleOption.visualFocus || styleOption.hovered ? 1 : 0
                        border.color: root.tokens.color.accent
                    }
                    indicator: Rectangle {
                        x: styleOption.leftPadding
                        y: (styleOption.height - height) / 2
                        width: 20
                        height: 20
                        radius: 10
                        color: root.tokens.color.background
                        border.width: 1
                        border.color: styleOption.checked ? root.tokens.color.accent : root.tokens.color.accentSoft
                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: root.tokens.color.accent
                            visible: styleOption.checked
                        }
                    }
                    contentItem: Column {
                        spacing: 6
                        Label { width: parent.width; leftPadding: styleOption.indicator.width + styleOption.spacing; text: styleOption.modelData.title }
                        Label {
                            width: parent.width
                            leftPadding: styleOption.indicator.width + styleOption.spacing
                            text: styleOption.modelData.description
                            color: root.tokens.color.textMuted
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
            Label { text: "Акцент"; font.pixelSize: 18 }
            Label {
                width: parent.width
                text: "Выберите, откуда брать цвет акцентов"
                color: root.tokens.color.textMuted
                font.pixelSize: 13
            }
            ButtonGroup { id: accentModes }
            Repeater {
                model: [
                    {key: "default", title: "Лаванда Nayori", description: "Фирменный цвет, обои на него не влияют"},
                    {key: "automatic", title: "С\u00A0обоев", description: "Цвет с\u00A0обоев основного монитора"},
                    {key: "manual", title: "Свой цвет", description: "Выбранный цвет, смена обоев его не меняет"}
                ]
                RadioButton {
                    id: accentOption
                    required property var modelData
                    objectName: "accentMode-" + modelData.key
                    width: root.width
                    ButtonGroup.group: accentModes
                    checked: root.accentMode === modelData.key
                    onClicked: {
                        root.accentModeChangedRequested(modelData.key)
                        checked = Qt.binding(function() { return root.accentMode === accentOption.modelData.key })
                    }
                    Accessible.name: modelData.title
                    Accessible.description: modelData.description
                    focusPolicy: Qt.StrongFocus
                    onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
                    spacing: 12
                    padding: 12
                    background: Rectangle {
                        radius: root.tokens.radius.small
                        color: root.tokens.color.surfaceAlt
                        border.width: accentOption.checked || accentOption.visualFocus || accentOption.hovered ? 1 : 0
                        border.color: root.tokens.color.accent
                    }
                    indicator: Rectangle {
                        x: accentOption.leftPadding
                        y: (accentOption.height - height) / 2
                        width: 20
                        height: 20
                        radius: 10
                        color: root.tokens.color.background
                        border.width: 1
                        border.color: accentOption.checked ? root.tokens.color.accent : root.tokens.color.accentSoft
                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: root.tokens.color.accent
                            visible: accentOption.checked
                        }
                    }
                    contentItem: Column {
                        spacing: 6
                        Label { width: parent.width; leftPadding: accentOption.indicator.width + accentOption.spacing; text: accentOption.modelData.title }
                        Label {
                            width: parent.width
                            leftPadding: accentOption.indicator.width + accentOption.spacing
                            text: accentOption.modelData.description
                            color: root.tokens.color.textMuted
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
            Label { text: "Текущий цвет" }
            Row {
                spacing: 12
                Rectangle {
                    objectName: "accentPreview"
                    width: 44
                    height: 44
                    radius: root.tokens.radius.small
                    color: root.accentPreview
                    border.width: 1
                    border.color: root.tokens.color.border
                }
                Label {
                    height: 44
                    verticalAlignment: Text.AlignVCenter
                    text: root.previewHex
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                }
            }
            Column {
                visible: root.hasAccentCandidates
                width: parent.width
                spacing: 16
                Label { width: parent.width; text: "Варианты с\u00A0обоев" }
                Flow {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: root.accentCandidates
                        delegate: AccentSwatch {
                            required property int index
                            required property var modelData
                            readonly property string candidateHex: root.canonicalHex(modelData.color)
                            objectName: "accentCandidate-" + index
                            visible: candidateHex !== ""
                            tokens: root.tokens
                            fill: candidateHex || "#C0AFD1"
                            hex: candidateHex
                            marked: candidateHex !== "" && candidateHex === root.previewHex
                            onClicked: root.requestManualAccent(modelData.color)
                            onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
                        }
                    }
                }
            }
            Column {
                visible: root.accentMode === "manual"
                width: parent.width
                spacing: 16
                Label { text: "Цвет" }
                SettingsField {
                    id: hexField
                    objectName: "accentHex"
                    tokens: root.tokens
                    text: root.manualAccentHex
                    placeholderText: "#C0AFD1"
                    Accessible.name: "Цвет акцента"
                    onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
                    onTextEdited: { root.hexNotice = ""; root.hexDirty = true }
                    onEditingFinished: root.commitHexField()
                }
                Label {
                    visible: root.hexNotice !== ""
                    width: parent.width
                    text: root.hexNotice
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                }
                Action {
                    objectName: "accentPick"
                    text: "Выбрать цвет"
                    selected: true
                    onClicked: root.openAccentDialog()
                    onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
                }
            }
            Action {
                objectName: "accentReset"
                text: "Вернуть лаванду Nayori"
                selected: true
                onClicked: root.accentResetRequested()
                onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
            }
            Label {
                objectName: "accentStatus"
                visible: root.accentStatus !== ""
                width: parent.width
                text: root.accentStatus
                color: root.tokens.color.textMuted
                font.pixelSize: 13
            }
            ColorDialog {
                id: accentDialog
                objectName: "accentColorDialog"
                title: "Цвет акцента"
                onAccepted: root.applyPickedColor(selectedColor)
            }
            CheckBox {
                id: animations
                objectName: "settingsAnimationsToggle"
                onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
                width: parent.width
                text: "Анимации"
                checked: root.animationsEnabled
                focusPolicy: Qt.StrongFocus
                onClicked: root.animationsChangedRequested(checked)
                spacing: 12
                padding: 12
                background: Rectangle {
                    radius: root.tokens.radius.small
                    color: root.tokens.color.surfaceAlt
                    border.width: animations.visualFocus || animations.hovered ? 1 : 0
                    border.color: root.tokens.color.accent
                }
                indicator: Rectangle {
                    x: animations.leftPadding
                    y: (animations.height - height) / 2
                    width: 20
                    height: 20
                    radius: 5
                    color: animations.checked ? root.tokens.color.accent : root.tokens.color.background
                    border.width: animations.checked ? 0 : 1
                    border.color: root.tokens.color.accentSoft
                    Label { anchors.centerIn: parent; text: animations.checked ? "✓" : ""; color: root.tokens.color.accentText }
                }
                contentItem: Column {
                    property real labelIndent: animations.indicator.width + animations.spacing
                    spacing: 6
                    Label { width: parent.width; leftPadding: parent.labelIndent; text: "Анимации" }
                    Label { width: parent.width; leftPadding: parent.labelIndent; text: "Движение лисы и переходы интерфейса"; color: root.tokens.color.textMuted; font.pixelSize: 13 }
                }
            }


        }
