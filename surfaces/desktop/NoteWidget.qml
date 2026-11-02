pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property var tokens
    property string savedText: ""
    property bool paper: false
    readonly property color ink: paper ? tokens.color.background : tokens.color.text
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
        color: root.ink
        font.pixelSize: 18
    }
    Rectangle {
        id: divider
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.alpha(root.ink, 0.25)
    }
    DesktopLabel {
        anchors.top: heading.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: divider.top
        visible: editor.text === ""
        tokens: root.tokens
        color: Qt.alpha(root.ink, 0.65)
        text: "Текст заметки"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
    TextEdit {
        id: editor
        objectName: "desktop-note-editor"
        anchors.top: heading.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: divider.top
        anchors.bottomMargin: 10
        color: root.ink
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
