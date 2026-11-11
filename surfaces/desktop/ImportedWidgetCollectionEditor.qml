pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../settings"

Column {
    id: root
    required property var tokens
    property bool tasks: false
    property var items: []
    readonly property string ids: JSON.stringify(items.map((entry,index) => String(entry.id === undefined ? "index:" + index : entry.id)))
    signal edited(var items)
    spacing: 8
    function idOf(entry,index) { return String(entry.id === undefined ? "index:" + index : entry.id) }
    function indexOf(id) { return items.findIndex((entry,index) => idOf(entry,index) === id) }
    function change(id, key, value) {
        const next = JSON.parse(JSON.stringify(items)), index = indexOf(id)
        if (index < 0 || next[index][key] === value) return
        next[index][key] = value
        next[index].updatedAt = Date.now()
        edited(next)
    }
    function remove(id) { edited(items.filter((entry,index) => idOf(entry,index) !== id)) }
    SettingsButton {
        tokens: root.tokens
        text: root.tasks ? "Добавить задачу" : "Добавить заметку"
        onClicked: {
            const id = Date.now().toString(36) + Math.random().toString(36).slice(2,8)
            root.edited(root.items.concat([root.tasks ? {id:id,content:"Новая задача",done:false} : {id:id,title:"Новая заметка",content:"",pinned:false,updatedAt:Date.now()}]))
        }
    }
    Repeater {
        // Stable IDs preserve the active field while SettingsService accepts edits.
        model: JSON.parse(root.ids)
        delegate: Column {
            id: row
            required property string modelData
            readonly property var entry: root.items[root.indexOf(modelData)] || {}
            width: root.width
            spacing: 6
            SettingsField {
                width: parent.width; tokens: root.tokens
                text: root.tasks ? row.entry.content || "" : row.entry.title || ""
                placeholderText: root.tasks ? "Задача" : "Название заметки"
                Accessible.name: placeholderText
                onTextChanged: if (activeFocus) root.change(row.modelData,root.tasks ? "content" : "title",text)
            }
            TextArea {
                width: parent.width
                visible: !root.tasks
                implicitHeight: 120
                text: row.entry.content || ""
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                color: root.tokens.color.text
                selectionColor: root.tokens.color.accent
                selectedTextColor: root.tokens.color.accentText
                font.family: root.tokens.type.body.family
                font.pixelSize: root.tokens.settings.body
                padding: 10
                Accessible.name: "Текст заметки"
                background: Rectangle { radius: root.tokens.radius.small; color: root.tokens.color.surfaceAlt; border.width:1; border.color: parent.activeFocus ? root.tokens.color.accent : root.tokens.color.border }
                onTextChanged: if (activeFocus && !root.tasks) root.change(row.modelData,"content",text)
            }
            SettingsSwitch {
                width: parent.width; tokens: root.tokens
                text: root.tasks ? "Выполнена" : "Закреплена"
                checked: root.tasks ? row.entry.done === true : row.entry.pinned === true
                onToggled: root.change(row.modelData,root.tasks ? "done" : "pinned",checked)
            }
            SettingsButton {
                tokens: root.tokens
                text: root.tasks ? "Удалить задачу" : "Удалить заметку"
                onClicked: root.remove(row.modelData)
            }
        }
    }
}
