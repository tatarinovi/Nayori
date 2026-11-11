pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../settings"
import "WidgetLayout.js" as WidgetLayout
import "ImportedWidgets.js" as ImportedWidgets

Column {
    id: root
    required property var tokens
    property var spec: null
    readonly property var entry: spec ? WidgetLayout.registry().find(row => row.id === spec.type) : null
    readonly property bool imported: spec && WidgetLayout.isImported(spec.type)
    readonly property var box: spec ? WidgetLayout.sizeOf(spec) : ({width:0, height:0})
    readonly property var metrics: spec && spec.type === "system" ? WidgetLayout.normalizeMetrics(spec.metrics) : []
    readonly property var sizes: spec && spec.type === "clock"
        ? [{key:"compact",label:"Компактный"},{key:"large",label:"Крупный"},{key:"extraLarge",label:"Очень крупный"},{key:"huge",label:"Огромный"}]
        : spec && spec.type === "system"
        ? [{key:"compact",label:"Маленький"},{key:"large",label:"Средний"},{key:"extraLarge",label:"Большой"}]
        : [{key:"compact",label:imported ? "Исходный" : "Компактный"},{key:"large",label:"Крупный"}]
    signal fieldEdited(string id, string field, var value)
    signal noteEdited(string id, string text)
    signal geometryEdited(string id, real x, real y, real width, real height)
    spacing: 12
    function setField(field, value) { if (spec) fieldEdited(spec.id, field, value) }
    function setDimension(key, text) {
        if (!spec || String(text).trim() === "") return
        const value = Number(text)
        if (!isFinite(value) || (key === "width" || key === "height") && value <= 0) return
        geometryEdited(spec.id, key === "x" ? value : spec.x, key === "y" ? value : spec.y,
            key === "width" ? value : box.width, key === "height" ? value : box.height)
    }
    SettingsLabel {
        width: parent.width
        tokens: root.tokens
        text: root.entry ? root.entry.name : "Выберите виджет на рабочем столе"
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
    }
    SettingsLabel { tokens: root.tokens; text: "Размер" }
    SettingsSelect {
        width: parent.width; tokens: root.tokens
        model: root.sizes
        currentKey: root.spec ? root.spec.size || "compact" : "compact"
        onActivated: key => root.setField("size", key)
    }
    Grid {
        width: parent.width
        columns: 2; spacing: 8
        Repeater {
            model: [{key:"x",label:"X"},{key:"y",label:"Y"},{key:"width",label:"Ширина"},{key:"height",label:"Высота"}]
            delegate: Column {
                required property var modelData
                width: (root.width - 8) / 2
                spacing: 4
                SettingsLabel { tokens: root.tokens; text: parent.modelData.label }
                TextField {
                    width: parent.width
                    property string dimensionKey: parent.modelData.key
                    objectName: "widget-setting-" + dimensionKey
                    text: String(dimensionKey === "width" ? root.box.width : dimensionKey === "height" ? root.box.height : root.spec ? root.spec[dimensionKey] : 0)
                    Accessible.name: parent.modelData.label
                    selectByMouse: true
                    onEditingFinished: root.setDimension(dimensionKey, text)
                }
            }
        }
    }
    SettingsLabel { tokens: root.tokens; text: "Непрозрачность" }
    Slider {
        width: parent.width
        from: 0.1; to: 1; stepSize: 0.05
        value: root.spec && typeof root.spec.opacity === "number" ? root.spec.opacity : 1
        Accessible.name: "Непрозрачность виджета"
        onMoved: root.setField("opacity", value)
    }
    SettingsLabel { visible: !root.imported; tokens: root.tokens; text: "Оформление" }
    SettingsSelect {
        visible: !root.imported
        width: parent.width; tokens: root.tokens
        model: [{key:"plain",label:"Без фона"},{key:"card",label:"Карточка"}]
        currentKey: root.spec && root.spec.style === "plain" ? "plain" : "card"
        onActivated: key => root.setField("style", key)
    }
    Column {
        visible: !!root.spec && root.spec.type === "system"
        width: parent.width
        spacing: 8
        Repeater {
            model: [{key:"cpu",label:"Процессор"},{key:"memory",label:"Память"},{key:"gpu",label:"Видеокарта"}]
            delegate: SettingsSwitch {
                required property var modelData
                tokens: root.tokens
                text: modelData.label
                checked: root.metrics.indexOf(modelData.key) >= 0
                enabled: !checked || root.metrics.length > 1
                onToggled: {
                    let next = root.metrics.filter(key => key !== modelData.key)
                    if (checked) next.push(modelData.key)
                    root.setField("metrics", next)
                }
            }
        }
    }
    TextArea {
        visible: !!root.spec && root.spec.type === "note"
        width: parent.width
        implicitHeight: 180
        wrapMode: TextEdit.Wrap
        text: root.spec && root.spec.type === "note" ? root.spec.text || "" : ""
        Accessible.name: "Текст заметки"
        selectByMouse: true
        onTextChanged: if (activeFocus && root.spec && root.spec.type === "note" && text !== root.spec.text) root.noteEdited(root.spec.id, text)
    }
    ImportedWidgetOptions {
        width: parent.width
        tokens: root.tokens
        spec: root.spec
        showHeader: false
        expanded: true
        onEdited: options => root.setField("options", options)
    }
}
