pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "WidgetLayout.js" as WidgetLayout
import "ImportedWidgets.js" as ImportedWidgets
import "../settings"

Column {
    id: root
    required property var tokens
    property var spec: null
    property bool expanded: false
    property bool showHeader: true
    readonly property var entry: spec ? ImportedWidgets.selected(spec.type, spec.options) : null
    readonly property var values: entry ? ImportedWidgets.options(entry.type, spec.options) : ({})
    readonly property var fields: Object.keys(values).filter(key => ["enable", "x", "y", "variant", "dynamicColors", "placementStrategy", "disableAnimationOnLock", "timerState", "notes", "tasks"].indexOf(key) < 0)
    signal edited(var options)
    visible: entry !== null
    spacing: 8
    function update(key, value) {
        if (!spec) return
        const next = WidgetLayout.instanceOptions(spec.options)
        next[key] = value
        edited(next)
    }
    AbstractButton {
        id: disclosure
        visible: root.showHeader
        width: parent.width
        height: 44
        hoverEnabled: true
        text: root.entry ? "Параметры: " + root.entry.name : ""
        Accessible.name: text
        Accessible.description: root.expanded ? "Свернуть параметры" : "Развернуть параметры"
        onClicked: root.expanded = !root.expanded
        background: Rectangle {
            radius: root.tokens.radius.small
            color: root.tokens.material.sidebar
            border.width: disclosure.visualFocus ? 1 : 0
            border.color: root.tokens.color.accent
        }
        contentItem: Text {
            leftPadding: 12; rightPadding: 12
            text: (root.expanded ? "⌄  " : "›  ") + disclosure.text
            verticalAlignment: Text.AlignVCenter
            color: root.tokens.color.text
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            elide: Text.ElideRight
        }
    }
    Loader {
        width: parent.width
        active: root.expanded && root.entry !== null
        visible: active
        height: active && item ? item.implicitHeight : 0
        sourceComponent: Column {
            width: root.width
            spacing: 8
            ComboBox {
                width: parent.width
                visible: model.length > 1
                model: root.spec ? ImportedWidgets.variants(root.spec.type) : []
                textRole: "name"
                currentIndex: root.entry ? model.findIndex(row => row.type === root.entry.type) : -1
                Accessible.name: "Вариант оформления"
                onActivated: root.update("variant", model[currentIndex].type)
            }
            SettingsSwitch {
                tokens: root.tokens
                width: parent.width
                text: "Динамические цвета Nayori"
                checked: root.values.dynamicColors === true
                onToggled: root.update("dynamicColors", checked)
            }
            ImportedWidgetCollectionEditor {
                width: parent.width
                tokens: root.tokens
                visible: !!root.spec && ["python_NotesFace","shima_todo"].includes(root.spec.type)
                tasks: !!root.spec && root.spec.type === "shima_todo"
                items: tasks ? root.values.tasks || [] : root.values.notes || []
                onEdited: items => root.update(tasks ? "tasks" : "notes",items)
            }
            Repeater {
                model: root.fields
                delegate: Column {
                    id: row
                    required property string modelData
                    width: root.width
                    spacing: 4
                    readonly property var value: root.values[modelData]
                    readonly property var choices: root.entry && root.entry.choices ? root.entry.choices[modelData] || [] : []
                    readonly property string label: (root.entry && root.entry.labels && root.entry.labels[modelData]) || modelData.replace(/([a-z])([A-Z])/g, "$1 $2")
                    SettingsLabel { tokens: root.tokens; width: parent.width; text: row.label; wrapMode: Text.Wrap }
                    SettingsSwitch {
                        tokens: root.tokens
                        visible: typeof row.value === "boolean"
                        checked: row.value === true
                        Accessible.name: row.label
                        onToggled: root.update(row.modelData, checked)
                    }
                    ComboBox {
                        visible: row.choices.length > 0
                        width: parent.width
                        model: row.choices
                        currentIndex: model.indexOf(String(row.value))
                        Accessible.name: row.label
                        onActivated: root.update(row.modelData, model[currentIndex])
                    }
                    TextField {
                        visible: typeof row.value !== "boolean" && row.choices.length === 0
                        width: parent.width
                        text: row.value !== null && typeof row.value === "object" ? JSON.stringify(row.value) : String(row.value)
                        Accessible.name: row.label
                        selectByMouse: true
                        onEditingFinished: {
                            if (typeof row.value === "number") {
                                const number = Number(text)
                                if (isFinite(number)) root.update(row.modelData, number)
                                else text = String(row.value)
                            } else if (row.value !== null && typeof row.value === "object") {
                                try { root.update(row.modelData, JSON.parse(text)) }
                                catch (error) { text = JSON.stringify(row.value) }
                            } else root.update(row.modelData, text)
                        }
                    }
                }
            }
        }
    }
}
