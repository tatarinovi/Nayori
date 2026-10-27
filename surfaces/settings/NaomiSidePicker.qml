pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Монитор и две точки в нижних углах. Выбранная сторона закрашена акцентом.
Item {
    id: root
    required property var tokens
    property string side: "right"
    signal activated(string side)
    signal focusReceived()

    implicitWidth: 196
    implicitHeight: 132

    function choose(place) {
        root.activated(place)
        const dot = place === "left" ? leftChoice : rightChoice
        dot.forceActiveFocus(Qt.TabFocusReason)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.tokens.radius.small
        color: root.tokens.color.background
        border.width: 1
        border.color: root.tokens.color.border
    }
    Rectangle {
        id: screen
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 12; rightMargin: 12; topMargin: 12; bottomMargin: 28 }
        radius: 4
        color: root.tokens.color.surfaceAlt
        border.width: 1
        border.color: root.tokens.color.border

        AbstractButton {
            id: leftChoice
            objectName: "settingsNaomiSideLeft"
            anchors { left: parent.left; bottom: parent.bottom; margins: 4 }
            width: 36
            height: 36
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            Accessible.role: Accessible.RadioButton
            Accessible.name: "Слева"
            Accessible.checked: root.side === "left"
            onClicked: root.choose("left")
            onActiveFocusChanged: if (activeFocus) root.focusReceived()
            Keys.onLeftPressed: function(event) { event.accepted = true; root.choose("left") }
            Keys.onRightPressed: function(event) { event.accepted = true; root.choose("right") }
            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7
                color: root.side === "left" ? root.tokens.color.accent
                    : leftChoice.hovered || leftChoice.activeFocus ? root.tokens.color.text : root.tokens.color.textMuted
                border.width: leftChoice.visualFocus ? 2 : 0
                border.color: root.tokens.color.accent
            }
        }
        AbstractButton {
            id: rightChoice
            objectName: "settingsNaomiSideRight"
            anchors { right: parent.right; bottom: parent.bottom; margins: 4 }
            width: 36
            height: 36
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            Accessible.role: Accessible.RadioButton
            Accessible.name: "Справа"
            Accessible.checked: root.side === "right"
            onClicked: root.choose("right")
            onActiveFocusChanged: if (activeFocus) root.focusReceived()
            Keys.onLeftPressed: function(event) { event.accepted = true; root.choose("left") }
            Keys.onRightPressed: function(event) { event.accepted = true; root.choose("right") }
            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7
                color: root.side === "right" ? root.tokens.color.accent
                    : rightChoice.hovered || rightChoice.activeFocus ? root.tokens.color.text : root.tokens.color.textMuted
                border.width: rightChoice.visualFocus ? 2 : 0
                border.color: root.tokens.color.accent
            }
        }
    }
    Rectangle {
        width: 48
        height: 8
        radius: 3
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        color: root.tokens.color.border
    }
}
