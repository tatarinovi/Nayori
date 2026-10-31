pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property var tokens
    property string savedText: ""
    signal textEdited(string text)

    function flush() {
        if (editor.text !== savedText)
            textEdited(editor.text)
    }

    onSavedTextChanged: {
        if (editor.activeFocus || editor.text === savedText)
            return
        editor.text = savedText
    }
    Component.onCompleted: editor.text = savedText

    DesktopLabel {
        anchors.fill: parent
        visible: editor.text === ""
        tokens: root.tokens
        muted: true
        text: "Текст заметки"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
    TextEdit {
        id: editor
        anchors.fill: parent
        color: root.tokens.color.text
        selectionColor: root.tokens.color.accent
        selectedTextColor: root.tokens.color.accentText
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.type.body.size
        font.weight: root.tokens.type.body.weight
        wrapMode: TextEdit.Wrap
        selectByMouse: true
        selectByKeyboard: true
        persistentSelection: true
        textFormat: TextEdit.PlainText
        clip: true
        Accessible.name: "Заметка"
        Accessible.description: "Текст сохраняется в раскладке рабочего стола"
        onTextChanged: {
            if (text === root.savedText)
                saveTimer.stop()
            else
                saveTimer.restart()
        }
        onActiveFocusChanged: {
            if (!activeFocus)
                root.flush()
        }
        Keys.onEscapePressed: function(event) {
            focus = false
            event.accepted = true
        }
    }
    Timer {
        id: saveTimer
        interval: 400
        onTriggered: root.flush()
    }
}
