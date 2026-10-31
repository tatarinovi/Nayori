import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import "tokens"
import "surfaces/polkit"

// Импорт модуля не создаёт PolkitAgent и не регистрирует агент в сеансе.
ShellRoot {
    Tokens { id: themeTokens }
    QtObject {
        id: sample
        property var view: ({
            message: "Установить обновление",
            actionId: "org.example.install",
            identities: [{ id: 1, title: "Катя (katamy)" }],
            selected: 0,
            hint: "",
            responseRequired: true,
            responseVisible: false,
            failed: false,
            errorText: "",
            infoText: "",
            generation: 1,
            pending: 0,
            iconName: ""
        })
    }
    Window {
        visible: true
        width: 480
        height: 420
        color: themeTokens.color.background
        PolkitCard {
            id: card
            anchors.centerIn: parent
            width: 440
            tokens: themeTokens
            view: sample.view
        }
    }
    Timer {
        interval: 50
        running: true
        onTriggered: {
            if (typeof PolkitAgent === "undefined") fail("module")
            if (card.responseEcho !== TextInput.Password) fail("echo")
            if (card.titleText !== "Нужно подтверждение") fail("title")
            if (card.identityLine !== "От\u00A0имени Катя (katamy)") fail("identity")
            sample.view = Object.assign({}, sample.view, { responseVisible: true, generation: 1 })
            if (card.responseEcho !== TextInput.Normal) fail("visible-echo")
            card.responseField.text = "метка"
            sample.view = Object.assign({}, sample.view, { responseVisible: false, failed: true, generation: 2 })
            if (!card.responseEmpty) fail("cleared")
            if (card.responseEcho !== TextInput.Password) fail("hidden-again")
            if (card.errorLine !== "Пароль не подошёл. Попробуйте снова") fail("error")
            console.log("POLKIT_DIALOG_PASS")
            Qt.quit()
        }
        function fail(reason) {
            console.log("POLKIT_DIALOG_FAIL " + reason)
            Qt.exit(1)
        }
    }
}
