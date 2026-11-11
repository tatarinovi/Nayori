import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io


import "NotesFormat.js" as NotesFormat

Item {
    readonly property var nayoriNotesFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 240
    property real minHeight: 180
    property real maxWidth: 700
    property real maxHeight: 700
    property real minAspect: 0.5
    property real maxAspect: 2.5
    property bool isRound: false

    property string nerdFont: nayoriNotesFace.pythonTheme.iconFont

    property var notesList: nayoriNotesFace.options.notes || []
    property bool fileLoaded: true
    property bool showError: false

    property bool isViewing: false
    property string viewingNoteId: ""
    property string viewingTitle: ""
    property string viewingContent: ""
    property real viewingUpdatedAt: 0
    property real expandProgress: 0.0
    property bool isDraggingV: false

    readonly property var generalSettings: nayoriNotesFace.config.getSetting("general", {})
    readonly property bool quickactionsAvailable: generalSettings.quickactions !== false && !generalSettings.performance

    Behavior on expandProgress {
        enabled: !root.isDraggingV
        NumberAnimation { duration: (nayoriNotesFace.reducedMotion ? 0 : 250); easing.type: Easing.OutCubic }
    }

    onExpandProgressChanged: {
        if (expandProgress <= 0.001 && isViewing && !isDraggingV) {
            isViewing = false;
            viewingNoteId = "";
        }
    }

    property real currentTimeTicker: 0
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.currentTimeTicker = Date.now()
    }

    readonly property var displayNotesList: {
        let dummy = nayoriNotesFace.i18n.currentLang;
        let raw = root.notesList || [];
        let hasPinned = false;
        for (let i = 0; i < raw.length; i++) {
            if (raw[i].pinned) {
                hasPinned = true;
                break;
            }
        }
        let pinnedLabel = nayoriNotesFace.i18n.t("quickactions.notes.pinned");
        let recentLabel = nayoriNotesFace.i18n.t("quickactions.notes.recent");

        let pinned = [];
        let unpinned = [];
        for (let i = 0; i < raw.length; i++) {
            let item = raw[i];
            let copy = Object.assign({}, item);
            copy.sectionCategory = hasPinned ? (item.pinned ? pinnedLabel : recentLabel) : "";
            if (item.pinned) pinned.push(copy);
            else unpinned.push(copy);
        }
        return pinned.concat(unpinned);
    }

    function formatRelativeTime(timestamp) {
        let fmt = (nayoriNotesFace.config.rawSettings && nayoriNotesFace.config.rawSettings.bar && nayoriNotesFace.config.rawSettings.bar.time && nayoriNotesFace.config.rawSettings.bar.time.format !== undefined) ? nayoriNotesFace.config.rawSettings.bar.time.format : "HH:mm";
        return NotesFormat.formatRelativeTime(timestamp, nayoriNotesFace.i18n, fmt);
    }

    function parseNotes(rawText) {
        let txt = (rawText || "").trim();
        if (txt === "") return;
        try {
            let data = JSON.parse(txt);
            if (Array.isArray(data)) root.notesList = data.filter(n => n && n.id !== undefined);
        } catch (e) {}
    }

    function beginViewing(noteItem) {
        root.viewingNoteId = noteItem.id;
        root.viewingTitle = noteItem.title || "";
        root.viewingContent = noteItem.content || "";
        root.viewingUpdatedAt = noteItem.updatedAt || Date.now();
        root.isViewing = true;
    }

    function openNote(noteItem) {
        root.beginViewing(noteItem);
        root.expandProgress = 1.0;
    }

    function closeNote() {
        root.expandProgress = 0.0;
    }

    function openNotes() {
        if (!root.quickactionsAvailable) {
            shakeAnim.stop();
            shakeAnim.start();
            return;
        }
        nayoriNotesFace.floating.showNotes(root.Window.window ? root.Window.window.screen : null);
    }





    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shakeShift; property: "x"; to: -nayoriNotesFace.scaler.s(3); duration: (nayoriNotesFace.reducedMotion ? 0 : 50) }
        NumberAnimation { target: shakeShift; property: "x"; to: nayoriNotesFace.scaler.s(3); duration: (nayoriNotesFace.reducedMotion ? 0 : 50) }
        NumberAnimation { target: shakeShift; property: "x"; to: -nayoriNotesFace.scaler.s(3); duration: (nayoriNotesFace.reducedMotion ? 0 : 50) }
        NumberAnimation { target: shakeShift; property: "x"; to: nayoriNotesFace.scaler.s(3); duration: (nayoriNotesFace.reducedMotion ? 0 : 50) }
        NumberAnimation { target: shakeShift; property: "x"; to: 0; duration: (nayoriNotesFace.reducedMotion ? 0 : 50) }
        onStarted: root.showError = true
        onStopped: root.showError = false
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(nayoriNotesFace.pythonTheme.surface0, nayoriNotesFace.pythonTheme.elementOpacity)
        radius: nayoriNotesFace.pythonTheme.clampedBorderRadius
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        Item {
            id: mainListView
            anchors.fill: parent
            opacity: Math.max(0.0, 1.0 - root.expandProgress * 1.5)
            visible: opacity > 0.001

            Item {
                id: listControlBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: nayoriNotesFace.scaler.s(42)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: nayoriNotesFace.scaler.s(12)
                    anchors.rightMargin: nayoriNotesFace.scaler.s(10)
                    spacing: nayoriNotesFace.scaler.s(8)

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: nayoriNotesFace.i18n.t("quickactions.tabs.notes", "Notes")
                        elide: Text.ElideRight
                        color: nayoriNotesFace.pythonTheme.text
                        font.family: nayoriNotesFace.pythonTheme.fontFamily
                        font.pixelSize: nayoriNotesFace.scaler.s(13)
                        font.bold: true
                    }

                    Item {
                        id: addWrap
                        Layout.preferredWidth: nayoriNotesFace.scaler.s(32)
                        Layout.preferredHeight: nayoriNotesFace.scaler.s(32)
                        Layout.alignment: Qt.AlignVCenter
                        transform: Translate { id: shakeShift; x: 0 }

                        IconButton {
                            anchors.fill: parent
                            size: nayoriNotesFace.scaler.s(32)
                            cornerRadius: nayoriNotesFace.scaler.s(8)
                            iconFont: root.nerdFont
                            buttonIcon: "󰐕"
                            iconFontSize: nayoriNotesFace.scaler.s(15)
                            accentColor: nayoriNotesFace.pythonTheme.surface1
                            textColor: nayoriNotesFace.pythonTheme.text
                            bgOpacity: nayoriNotesFace.pythonTheme.elementOpacity
                            onClicked: root.openNotes()
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: nayoriNotesFace.scaler.s(8)
                            color: nayoriNotesFace.pythonTheme.red
                            opacity: root.showError ? 0.15 : 0.0
                            z: 4
                            Behavior on opacity { NumberAnimation { duration: (nayoriNotesFace.reducedMotion ? 0 : 250) } }
                        }
                    }
                }
            }

            ListView {
                id: notesListView
                anchors.top: listControlBar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: nayoriNotesFace.scaler.s(4)
                anchors.bottomMargin: nayoriNotesFace.scaler.s(6)
                anchors.leftMargin: nayoriNotesFace.scaler.s(8)
                anchors.rightMargin: nayoriNotesFace.scaler.s(8)
                spacing: nayoriNotesFace.scaler.s(6)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.displayNotesList

                section.property: "sectionCategory"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    width: ListView.view ? ListView.view.width : 0
                    height: (section && section !== "") ? nayoriNotesFace.scaler.s(22) : 0
                    visible: section && section !== ""

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: nayoriNotesFace.scaler.s(4)
                        anchors.verticalCenter: parent.verticalCenter
                        text: section
                        font.family: nayoriNotesFace.pythonTheme.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: nayoriNotesFace.scaler.s(10.5)
                        color: nayoriNotesFace.pythonTheme.subtext0
                        opacity: 0.85
                    }
                }

                HoverHandler {
                    id: listHover
                }

                ScrollBar.vertical: ScrollBar {
                    active: listHover.hovered
                    width: nayoriNotesFace.scaler.s(4)
                    policy: listHover.hovered ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    contentItem: Rectangle {
                        implicitWidth: nayoriNotesFace.scaler.s(4)
                        radius: nayoriNotesFace.scaler.s(2)
                        color: nayoriNotesFace.pythonTheme.surface2
                    }
                }

                delegate: Item {
                    id: noteDelegateWrapper
                    width: notesListView.width

                    readonly property bool isTargetNote: root.viewingNoteId === modelData.id
                    property real relativeUpdateTracker: root.currentTimeTicker

                    height: isTargetNote ? (nayoriNotesFace.scaler.s(54) + (nayoriNotesFace.scaler.s(130) - nayoriNotesFace.scaler.s(54)) * root.expandProgress) : nayoriNotesFace.scaler.s(54)

                    scale: itemMouseArea.pressed ? 0.98 : 1.0
                    Behavior on scale { NumberAnimation { duration: (nayoriNotesFace.reducedMotion ? 0 : 150); easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    Rectangle {
                        id: noteItemCard
                        anchors.fill: parent
                        radius: nayoriNotesFace.pythonTheme.borderRadius
                        color: noteGlass.active ? "transparent" : Qt.alpha(itemMouseArea.containsMouse ? Qt.lighter(nayoriNotesFace.pythonTheme.surface1, 1.04) : nayoriNotesFace.pythonTheme.surface1, nayoriNotesFace.pythonTheme.elementOpacity)
                        clip: true

                        GlassFill {
                            id: noteGlass
                            anchors.fill: parent
                            radius: parent.radius
                            tintColor: nayoriNotesFace.pythonTheme.surface1
                            tintAmount: 0.3
                            press: itemMouseArea.pressed ? 0.8 : (itemMouseArea.containsMouse ? 0.2 : 0)
                            Behavior on press { NumberAnimation { duration: (nayoriNotesFace.reducedMotion ? 0 : 250); easing.type: Easing.OutCubic } }
                        }

                        Behavior on color { ColorAnimation { duration: (nayoriNotesFace.reducedMotion ? 0 : 150); easing.type: Easing.OutCubic } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: nayoriNotesFace.scaler.s(12)
                            anchors.rightMargin: nayoriNotesFace.scaler.s(12)
                            spacing: nayoriNotesFace.scaler.s(10)

                            Item {
                                Layout.preferredWidth: nayoriNotesFace.scaler.s(30)
                                Layout.preferredHeight: nayoriNotesFace.scaler.s(30)
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: nayoriNotesFace.scaler.s(8)
                                    color: Qt.alpha(nayoriNotesFace.pythonTheme.surface2, nayoriNotesFace.pythonTheme.elementOpacity)

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.nerdFont
                                        font.pixelSize: nayoriNotesFace.scaler.s(14)
                                        color: nayoriNotesFace.pythonTheme.subtext0
                                        text: "󰈙"
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: nayoriNotesFace.scaler.s(1)

                                Text {
                                    text: modelData.title || nayoriNotesFace.i18n.t("quickactions.notes.new_note_title")
                                    color: nayoriNotesFace.pythonTheme.text
                                    font.family: nayoriNotesFace.pythonTheme.fontFamily
                                    font.pixelSize: nayoriNotesFace.scaler.s(12)
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: {
                                        let c = (modelData.content || "").replace(/\n/g, " ").trim();
                                        return c.length > 0 ? c : "...";
                                    }
                                    color: nayoriNotesFace.pythonTheme.subtext0
                                    opacity: 0.85
                                    font.family: nayoriNotesFace.pythonTheme.fontFamily
                                    font.pixelSize: nayoriNotesFace.scaler.s(10)
                                    font.weight: Font.Normal
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: nayoriNotesFace.scaler.s(6)

                                Text {
                                    text: {
                                        let tick = noteDelegateWrapper.relativeUpdateTracker;
                                        return root.formatRelativeTime(modelData.updatedAt);
                                    }
                                    color: nayoriNotesFace.pythonTheme.subtext1
                                    font.family: nayoriNotesFace.pythonTheme.fontFamily
                                    font.pixelSize: nayoriNotesFace.scaler.s(10)
                                }

                                FlipIcon {
                                    size: nayoriNotesFace.scaler.s(26)
                                    cornerRadius: nayoriNotesFace.scaler.s(6)
                                    accentColor: nayoriNotesFace.pythonTheme.surface2
                                    bgOpacity: nayoriNotesFace.pythonTheme.elementOpacity
                                    iconColor: isHoveredOrHighlighted ? nayoriNotesFace.pythonTheme.text : nayoriNotesFace.pythonTheme.subtext1
                                    autoToggle: false
                                    flipped: noteDelegateWrapper.isTargetNote && root.expandProgress > 0.5
                                    onClicked: root.openNote(modelData)
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            property real startY: 0
                            property bool draggingV: false

                            onPressed: mouse => {
                                startY = mouse.y;
                                draggingV = false;
                                root.isDraggingV = false;
                            }

                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                let dy = mouse.y - startY;
                                if (!draggingV && dy > nayoriNotesFace.scaler.s(6)) {
                                    draggingV = true;
                                    root.isDraggingV = true;
                                    preventStealing = true;
                                    root.beginViewing(modelData);
                                }

                                if (draggingV) {
                                    root.expandProgress = Math.max(0.0, Math.min(1.0, dy / nayoriNotesFace.scaler.s(90)));
                                }
                            }

                            onReleased: mouse => {
                                preventStealing = false;
                                if (draggingV) {
                                    root.isDraggingV = false;
                                    draggingV = false;
                                    root.expandProgress = root.expandProgress > 0.35 ? 1.0 : 0.0;
                                } else {
                                    root.openNote(modelData);
                                }
                            }

                            onCanceled: {
                                preventStealing = false;
                                if (draggingV) {
                                    root.isDraggingV = false;
                                    draggingV = false;
                                    root.expandProgress = root.expandProgress > 0.35 ? 1.0 : 0.0;
                                }
                            }
                        }
                    }
                }
            }

            Item {
                anchors.centerIn: parent
                visible: root.notesList.length === 0
                width: parent.width - nayoriNotesFace.scaler.s(40)
                height: emptyCol.implicitHeight

                ColumnLayout {
                    id: emptyCol
                    anchors.centerIn: parent
                    spacing: nayoriNotesFace.scaler.s(10)

                    Text {
                        text: "󰈙"
                        font.family: root.nerdFont
                        font.pixelSize: nayoriNotesFace.scaler.s(36)
                        color: nayoriNotesFace.pythonTheme.surface2
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: nayoriNotesFace.i18n.t("widgets.notes.empty", "No notes yet")
                        color: nayoriNotesFace.pythonTheme.subtext0
                        font.family: nayoriNotesFace.pythonTheme.fontFamily
                        font.pixelSize: nayoriNotesFace.scaler.s(12)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        Item {
            id: viewerView
            anchors.fill: parent
            visible: root.expandProgress > 0.001
            opacity: Math.max(0.0, (root.expandProgress - 0.15) / 0.85)
            scale: 0.96 + 0.04 * root.expandProgress
            transform: Translate { y: nayoriNotesFace.scaler.s(25) * (1.0 - root.expandProgress) }

            Rectangle {
                id: viewerCard
                anchors.fill: parent
                anchors.margins: nayoriNotesFace.scaler.s(8)
                color: viewerGlass.active ? "transparent" : Qt.alpha(nayoriNotesFace.pythonTheme.surface1, nayoriNotesFace.pythonTheme.elementOpacity)
                radius: nayoriNotesFace.pythonTheme.borderRadius
                clip: true

                GlassFill {
                    id: viewerGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: nayoriNotesFace.pythonTheme.surface1
                    tintAmount: 0.3
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: nayoriNotesFace.scaler.s(8)
                    spacing: nayoriNotesFace.scaler.s(8)

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: nayoriNotesFace.scaler.s(32)

                        RowLayout {
                            anchors.fill: parent
                            spacing: nayoriNotesFace.scaler.s(8)

                            CloseButton {
                                size: nayoriNotesFace.scaler.s(32)
                                cornerRadius: nayoriNotesFace.scaler.s(8)
                                iconFont: root.nerdFont
                                iconFontSize: nayoriNotesFace.scaler.s(15)
                                textColor: nayoriNotesFace.pythonTheme.text
                                accentColor: nayoriNotesFace.pythonTheme.surface2
                                bgOpacity: nayoriNotesFace.pythonTheme.elementOpacity
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: root.closeNote()
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: NotesFormat.formatPreciseTime(root.viewingUpdatedAt)
                                    color: nayoriNotesFace.pythonTheme.subtext0
                                    font.family: nayoriNotesFace.pythonTheme.fontFamily
                                    font.pixelSize: nayoriNotesFace.scaler.s(10.5)
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: headerDragArea
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    property real startY: 0
                                    property bool draggingV: false

                                    onPressed: mouse => {
                                        startY = mouse.y;
                                        draggingV = false;
                                        root.isDraggingV = false;
                                    }

                                    onPositionChanged: mouse => {
                                        if (!pressed) return;
                                        let dy = mouse.y - startY;
                                        if (!draggingV && dy > nayoriNotesFace.scaler.s(6)) {
                                            draggingV = true;
                                            root.isDraggingV = true;
                                            preventStealing = true;
                                        }
                                        if (draggingV) {
                                            root.expandProgress = Math.max(0.0, Math.min(1.0, 1.0 - (dy / nayoriNotesFace.scaler.s(90))));
                                        }
                                    }

                                    onReleased: {
                                        preventStealing = false;
                                        if (draggingV) {
                                            root.isDraggingV = false;
                                            draggingV = false;
                                            root.expandProgress = root.expandProgress < 0.65 ? 0.0 : 1.0;
                                        }
                                    }

                                    onCanceled: {
                                        preventStealing = false;
                                        if (draggingV) {
                                            root.isDraggingV = false;
                                            draggingV = false;
                                            root.expandProgress = root.expandProgress < 0.65 ? 0.0 : 1.0;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: nayoriNotesFace.scaler.s(34)
                        radius: nayoriNotesFace.scaler.s(8)
                        color: Qt.alpha(nayoriNotesFace.pythonTheme.surface0, nayoriNotesFace.pythonTheme.elementOpacity)

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: nayoriNotesFace.scaler.s(12)
                            anchors.rightMargin: nayoriNotesFace.scaler.s(12)
                            verticalAlignment: Text.AlignVCenter
                            text: root.viewingTitle.trim().length > 0 ? root.viewingTitle.trim() : nayoriNotesFace.i18n.t("quickactions.notes.new_note_title")
                            color: nayoriNotesFace.pythonTheme.text
                            font.family: nayoriNotesFace.pythonTheme.fontFamily
                            font.pixelSize: nayoriNotesFace.scaler.s(12.5)
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.alpha(nayoriNotesFace.pythonTheme.surface0, nayoriNotesFace.pythonTheme.elementOpacity)
                        radius: nayoriNotesFace.scaler.s(8)

                        Flickable {
                            id: previewFlickable
                            anchors.fill: parent
                            anchors.margins: nayoriNotesFace.scaler.s(10)
                            contentWidth: width
                            contentHeight: previewText.height
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            HoverHandler {
                                id: previewHover
                            }

                            ScrollBar.vertical: ScrollBar {
                                active: previewHover.hovered
                                width: nayoriNotesFace.scaler.s(4)
                                policy: previewHover.hovered ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                contentItem: Rectangle {
                                    implicitWidth: nayoriNotesFace.scaler.s(4)
                                    radius: nayoriNotesFace.scaler.s(2)
                                    color: nayoriNotesFace.pythonTheme.surface2
                                }
                            }

                            Text {
                                id: previewText
                                width: previewFlickable.width
                                textFormat: Text.RichText
                                text: NotesFormat.markdownToHtml(root.viewingContent)
                                color: nayoriNotesFace.pythonTheme.text
                                font.family: nayoriNotesFace.pythonTheme.fontFamily
                                font.pixelSize: nayoriNotesFace.scaler.s(12)
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
