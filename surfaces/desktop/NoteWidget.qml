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
        id: heading
        anchors.top: parent.top
        width: parent.width
        tokens: root.tokens
        display: true
        text: "Заметка"
        font.pixelSize: 15
    }
    Rectangle {
        id: divider
        anchors.top: heading.bottom
        anchors.topMargin: 8
        width: parent.width
        height: 1
        color: Qt.alpha(root.tokens.color.text, 0.16)
    }
    DesktopLabel {
        anchors.top: divider.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: editor.text === ""
        tokens: root.tokens
        muted: true
        text: "Текст заметки"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
    TextEdit {
        id: editor
        objectName: "desktop-note-editor"
        anchors.top: divider.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
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
