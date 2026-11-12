import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia
import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects as GE







AbstractBackgroundWidget {
    readonly property var nayoriCustomImageWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "customImage"
    defaultConfig: ({
        enable: false,
        locked: false,
        placementStrategy: "free",
        sourceMode: "file",
        path: "",
        folder: "",
        mediaFilter: "all",
        intervalSeconds: 30,
        order: "sequential",
        transitionDuration: 450,
        shape: "Cookie4Sided",
        fitMode: "cover",
        size: 220,
        contentWidth: 0,
        contentHeight: 0,
        dim: 0,
        widgetScale: 100,
        widgetOpacity: 100,
        x: 120,
        y: 320
    })
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })

    readonly property string sourceMode: root._readConfigKey("sourceMode") === "folder" ? "folder" : "file"
    readonly property string mediaPath: String(root._readConfigKey("path") ?? "")
    readonly property string folderPath: String(root._readConfigKey("folder") ?? "")
    readonly property string mediaFilter: {
        const value = String(root._readConfigKey("mediaFilter") ?? "all")
        return ["images", "gifs", "videos"].includes(value) ? value : "all"
    }
    readonly property int intervalSeconds: Math.max(3, Math.min(3600,
        Number(root._readConfigKey("intervalSeconds") ?? 30)))
    readonly property string rotationOrder:
        root._readConfigKey("order") === "random" ? "random" : "sequential"
    readonly property int transitionDuration: Math.max(0, Math.min(2000,
        Number(root._readConfigKey("transitionDuration") ?? 450)))
    readonly property string shapeName: String(root._readConfigKey("shape") ?? "Cookie4Sided")
    readonly property string fitMode:
        root._readConfigKey("fitMode") === "contain" ? "contain" : "cover"
    readonly property real logicalSize: Math.max(80, Number(root._readConfigKey("size") ?? 220))
    readonly property real logicalWidth: {
        const value = Number(root._readConfigKey("contentWidth") ?? 0)
        return value > 0 ? Math.max(80, value) : root.logicalSize
    }
    readonly property real logicalHeight: {
        const value = Number(root._readConfigKey("contentHeight") ?? 0)
        return value > 0 ? Math.max(80, value) : root.logicalSize
    }
    readonly property real renderedWidth: Math.round(root.logicalWidth * root.scaleFactor)
    readonly property real renderedHeight: Math.round(root.logicalHeight * root.scaleFactor)
    readonly property int effectiveTransitionDuration: root.animationsActive
        ? nayoriCustomImageWidget.appearance.calcEffectiveDuration(root.transitionDuration) : 0
    property var mediaPaths: []
    property var folderAllPaths: []
    property var folderImagePaths: []
    property var folderGifPaths: []
    property var folderVideoPaths: []
    property int currentIndex: -1
    property bool rotationPaused: false
    property bool mediaPlaybackPaused: false
    property int activeSlot: 0
    property string _pendingSource: ""
    property string currentPath: ""
    readonly property bool currentIsVideo: nayoriCustomImageWidget.images.isValidVideoByName(root.currentPath)
    readonly property bool currentIsAnimatedImage:
        root.currentPath.toLowerCase().endsWith(".gif")
    readonly property int mediaCount: root.sourceMode === "folder"
        ? root.mediaPaths.length : (nayoriCustomImageWidget.images.isValidMediaByName(root.mediaPath) ? 1 : 0)
    readonly property int folderMediaCount: root.folderAllPaths.length
    readonly property int folderImageCount: root.folderImagePaths.length
    readonly property int folderGifCount: root.folderGifPaths.length
    readonly property int folderVideoCount: root.folderVideoPaths.length
    readonly property string currentName: nayoriCustomImageWidget.fileUtils.fileNameForPath(root.currentPath)
    readonly property bool activeFailed: root.activeSlot === 0 ? mediaSlotA.failed : mediaSlotB.failed
    readonly property int shapeEnum: root.shapeForName(root.shapeName)
    readonly property string activeSourceChoice:
        root.sourceMode === "file" ? "file" : root.mediaFilter

    property bool dropHover: false
    // ── Ryoku one-surface skin (additive; inert unless a WidgetSlot hosts this
    // widget in Ryoku style) ───────────────────────────────────────────────
    // In Ryoku style the slot already draws the paper card, so the widget must
    // read as a single coherent surface: the media (or the empty state) is
    // clipped to the slot's own rounded-square shape rather than the iNiR blob,
    // and the widget paints no plate or shadow of its own. Everything below is
    // gated on _ryokuSurface, so iNiR rendering stays byte-identical.
    property real ryokuSlotRadius: -1
    readonly property bool _ryokuSurface: root.ryokuHosted && root.ryokuStyle
    readonly property real _ryokuClipRadius: root.ryokuSlotRadius >= 0 ? root.ryokuSlotRadius : 0

    implicitWidth: root.renderedWidth
    implicitHeight: root.renderedHeight

    function fileUrl(path: string): string {
        const value = String(path ?? "")
        if (!value) return ""
        return value.startsWith("file:") ? value : "file://" + value
    }

    function activeSlotItem(): var {
        return root.activeSlot === 0 ? mediaSlotA : mediaSlotB
    }

    function inactiveSlotItem(): var {
        return root.activeSlot === 0 ? mediaSlotB : mediaSlotA
    }

    function rebuildMediaPaths(): void {
        const previousPath = root.currentPath
        const all = []
        const images = []
        const gifs = []
        const videos = []
        if (root.folderPath.length > 0 && folderModel.status === FolderListModel.Ready) {
            for (let i = 0; i < folderModel.count; ++i) {
                const path = String(folderModel.get(i, "filePath")
                    || nayoriCustomImageWidget.fileUtils.trimFileProtocol(folderModel.get(i, "fileURL")) || "")
                if (!path || !nayoriCustomImageWidget.images.isValidMediaByName(path)) continue
                all.push(path)
                if (nayoriCustomImageWidget.images.isValidVideoByName(path)) {
                    videos.push(path)
                } else if (nayoriCustomImageWidget.images.isValidImageByName(path)) {
                    if (path.toLowerCase().endsWith(".gif")) gifs.push(path)
                    else images.push(path)
                }
            }
        }

        root.folderAllPaths = all
        root.folderImagePaths = images
        root.folderGifPaths = gifs
        root.folderVideoPaths = videos

        let next = all
        if (root.mediaFilter === "images") next = images
        else if (root.mediaFilter === "gifs") next = gifs
        else if (root.mediaFilter === "videos") next = videos

        // Fall back only after the complete folder inventory is ready.
        if (root.sourceMode === "folder" && next.length === 0 && all.length > 0
                && root.mediaFilter !== "all") {
            Qt.callLater(() => nayoriCustomImageWidget.config.setNestedValue(root._configPath + ".mediaFilter", "all"))
            next = all
        }

        root.mediaPaths = next
        if (next.length === 0) {
            root.currentIndex = -1
            if (root.sourceMode === "folder") root.currentPath = ""
            return
        }
        const previousIndex = next.indexOf(previousPath)
        root.currentIndex = previousIndex >= 0
            ? previousIndex
            : (root.rotationOrder === "random" ? Math.floor(Math.random() * next.length) : 0)
        if (root.sourceMode === "folder")
            root.currentPath = String(next[root.currentIndex] ?? "")
    }

    function refreshSelection(): void {
        if (root.sourceMode === "file") {
            root.currentIndex = -1
            root.currentPath = nayoriCustomImageWidget.images.isValidMediaByName(root.mediaPath)
                ? root.mediaPath : ""
            return
        }
        root.rebuildMediaPaths()
    }

    function displayPath(path: string): void {
        const next = String(path ?? "")
        if (!next || !nayoriCustomImageWidget.images.isValidMediaByName(next)) {
            // Keep the previous frame while the new folder is still scanning.
            if (root.sourceMode === "folder" && root.folderPath.length > 0
                    && folderModel.status !== FolderListModel.Ready)
                return
            root._pendingSource = ""
            mediaSlotA.sourcePath = ""
            mediaSlotB.sourcePath = ""
            return
        }

        const active = root.activeSlotItem()
        if (active.sourcePath === next) {
            root._pendingSource = ""
            return
        }

        root._pendingSource = next
        if (!active.sourcePath || root.effectiveTransitionDuration <= 0) {
            const inactive = root.inactiveSlotItem()
            inactive.sourcePath = ""
            active.sourcePath = next
            return
        }

        root.inactiveSlotItem().sourcePath = next
    }

    function slotReady(slotIndex: int, path: string): void {
        if (!root._pendingSource || path !== root._pendingSource) return
        root._pendingSource = ""
        if (slotIndex !== root.activeSlot) {
            root.activeSlot = slotIndex
            staleSlotCleanup.restart()
        }
    }

    function advance(direction: int, randomPick: bool): void {
        const count = root.mediaPaths.length
        if (root.sourceMode !== "folder" || count === 0) return
        if (count === 1) {
            root.currentIndex = 0
            return
        }
        if (randomPick) {
            let next = root.currentIndex
            while (next === root.currentIndex)
                next = Math.floor(Math.random() * count)
            root.currentIndex = next
        } else {
            const current = root.currentIndex >= 0 ? root.currentIndex : 0
            root.currentIndex = (current + direction + count) % count
        }
        root.currentPath = String(root.mediaPaths[root.currentIndex] ?? "")
        rotationTimer.restart()
    }

    function activateSourceChoice(choice: string): void {
        const updates = {}
        if (choice === "file") {
            if (!nayoriCustomImageWidget.images.isValidMediaByName(root.mediaPath)) return
            updates[root._configPath + ".sourceMode"] = "file"
        } else {
            const count = choice === "images" ? root.folderImageCount
                : choice === "gifs" ? root.folderGifCount
                : choice === "videos" ? root.folderVideoCount
                : root.folderMediaCount
            if (count === 0) return
            updates[root._configPath + ".sourceMode"] = "folder"
            updates[root._configPath + ".mediaFilter"] = choice
        }
        root.rotationPaused = false
        root.mediaPlaybackPaused = false
        nayoriCustomImageWidget.config.setNestedValues(updates)
        Qt.callLater(rotationTimer.restart)
    }

    function setInterval(seconds: int): void {
        nayoriCustomImageWidget.config.setNestedValue(root._configPath + ".intervalSeconds",
            Math.max(3, Math.min(3600, seconds)))
        rotationTimer.restart()
    }

    function shapeForName(name: string): int {
        switch (name) {
        case "Circle": return MaterialShape.Shape.Circle;
        case "Square": return MaterialShape.Shape.Square;
        case "Slanted": return MaterialShape.Shape.Slanted;
        case "Arch": return MaterialShape.Shape.Arch;
        case "Fan": return MaterialShape.Shape.Fan;
        case "Arrow": return MaterialShape.Shape.Arrow;
        case "SemiCircle": return MaterialShape.Shape.SemiCircle;
        case "Oval": return MaterialShape.Shape.Oval;
        case "Pill": return MaterialShape.Shape.Pill;
        case "Triangle": return MaterialShape.Shape.Triangle;
        case "Diamond": return MaterialShape.Shape.Diamond;
        case "ClamShell": return MaterialShape.Shape.ClamShell;
        case "Pentagon": return MaterialShape.Shape.Pentagon;
        case "Gem": return MaterialShape.Shape.Gem;
        case "Sunny": return MaterialShape.Shape.Sunny;
        case "VerySunny": return MaterialShape.Shape.VerySunny;
        case "Cookie6Sided": return MaterialShape.Shape.Cookie6Sided;
        case "Cookie7Sided": return MaterialShape.Shape.Cookie7Sided;
        case "Cookie9Sided": return MaterialShape.Shape.Cookie9Sided;
        case "Cookie12Sided": return MaterialShape.Shape.Cookie12Sided;
        case "Ghostish": return MaterialShape.Shape.Ghostish;
        case "Clover4Leaf": return MaterialShape.Shape.Clover4Leaf;
        case "Clover8Leaf": return MaterialShape.Shape.Clover8Leaf;
        case "Burst": return MaterialShape.Shape.Burst;
        case "SoftBurst": return MaterialShape.Shape.SoftBurst;
        case "Boom": return MaterialShape.Shape.Boom;
        case "SoftBoom": return MaterialShape.Shape.SoftBoom;
        case "Flower": return MaterialShape.Shape.Flower;
        case "Puffy": return MaterialShape.Shape.Puffy;
        case "PuffyDiamond": return MaterialShape.Shape.PuffyDiamond;
        case "PixelCircle": return MaterialShape.Shape.PixelCircle;
        case "PixelTriangle": return MaterialShape.Shape.PixelTriangle;
        case "Bun": return MaterialShape.Shape.Bun;
        case "Heart": return MaterialShape.Shape.Heart;
        case "Cookie4Sided":
        default: return MaterialShape.Shape.Cookie4Sided;
        }
    }

    function pathFromDropUrl(value: var): string {
        const raw = String(value ?? "");
        try {
            return nayoriCustomImageWidget.fileUtils.trimFileProtocol(decodeURIComponent(raw));
        } catch (error) {
            return nayoriCustomImageWidget.fileUtils.trimFileProtocol(raw);
        }
    }

    function setMediaPath(path: string): void {
        if (!path || !nayoriCustomImageWidget.images.isValidMediaByName(path))
            return
        const updates = {}
        updates[root._configPath + ".path"] = path
        updates[root._configPath + ".sourceMode"] = "file"
        nayoriCustomImageWidget.config.setNestedValues(updates)
    }

    onCurrentPathChanged: {
        root.displayPath(root.currentPath)
    }
    onMediaFilterChanged: selectionRefreshTimer.restart()
    onSourceModeChanged: selectionRefreshTimer.restart()
    onMediaPathChanged: if (root.sourceMode === "file") selectionRefreshTimer.restart()
    onFolderPathChanged: selectionRefreshTimer.restart()
    Component.onCompleted: selectionRefreshTimer.restart()

    Timer {
        id: selectionRefreshTimer
        interval: 0
        onTriggered: root.refreshSelection()
    }

    FolderListModel {
        id: folderModel
        folder: root.folderPath.length > 0
            ? root.fileUrl(root.folderPath) : ""
        nameFilters: nayoriCustomImageWidget.images.validImageExtensions.concat(nayoriCustomImageWidget.images.validVideoExtensions)
            .map(ext => "*." + ext)
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        showOnlyReadable: true
        sortField: FolderListModel.Name
        sortReversed: false
        onCountChanged: root.rebuildMediaPaths()
        onStatusChanged: if (status === FolderListModel.Ready) root.rebuildMediaPaths()
        onFolderChanged: Qt.callLater(root.rebuildMediaPaths)
    }

    Timer {
        id: rotationTimer
        interval: root.intervalSeconds * 1000
        repeat: true
        running: root.sourceMode === "folder" && root.mediaPaths.length > 1
            && !root.rotationPaused && root.motionActive && root.visible
        onTriggered: root.advance(1, root.rotationOrder === "random")
    }

    Timer {
        id: staleSlotCleanup
        interval: Math.max(1, root.effectiveTransitionDuration) + 80
        onTriggered: {
            const stale = root.inactiveSlotItem()
            if (root._pendingSource && stale.sourcePath === root._pendingSource) return
            stale.sourcePath = ""
        }
    }

    component MediaSlot: Item {
        id: slot
        required property int slotIndex
        property string sourcePath: ""
        property bool shouldPlay: true
        property bool videoHasFrame: false
        readonly property bool isVideo: nayoriCustomImageWidget.images.isValidVideoByName(slot.sourcePath)
        readonly property bool isAnimatedImage: !slot.isVideo
            && slot.sourcePath.toLowerCase().endsWith(".gif")
        readonly property bool isStaticImage: slot.sourcePath.length > 0
            && !slot.isVideo && !slot.isAnimatedImage
        readonly property bool ready: slot.sourcePath.length > 0
            && (slot.isVideo
                ? slot.videoHasFrame
                : slot.isAnimatedImage
                    ? animatedImage.status === AnimatedImage.Ready
                    : staticImage.status === Image.Ready)
        readonly property bool failed: slot.sourcePath.length > 0
            && (slot.isAnimatedImage
                ? animatedImage.status === AnimatedImage.Error
                : slot.isStaticImage && staticImage.status === Image.Error)

        function syncVideoPlayback(): void {
            if (!slot.isVideo || slot.sourcePath.length === 0) return
            if (slot.shouldPlay && root.powerActive && root.visible) {
                videoPlayer.play()
            } else if (slot.videoHasFrame) {
                videoPlayer.pause()
            } else {
                // Decode one frame before pausing to avoid a black surface.
                videoPlayer.play()
            }
        }

        onSourcePathChanged: {
            slot.videoHasFrame = false
            Qt.callLater(slot.syncVideoPlayback)
        }
        onShouldPlayChanged: slot.syncVideoPlayback()
        onReadyChanged: if (slot.ready) root.slotReady(slot.slotIndex, slot.sourcePath)

        Connections {
            target: root
            function onPowerActiveChanged(): void { slot.syncVideoPlayback() }
            function onVisibleChanged(): void { slot.syncVideoPlayback() }
        }

        StyledImage {
            id: staticImage
            anchors.fill: parent
            visible: slot.isStaticImage
            source: visible ? root.fileUrl(slot.sourcePath) : ""
            fillMode: root.fitMode === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            cache: false
            sourceSize.width: Math.max(1, Math.round(width * 2))
            sourceSize.height: Math.max(1, Math.round(height * 2))
        }

        AnimatedImage {
            id: animatedImage
            anchors.fill: parent
            visible: slot.isAnimatedImage
            source: visible ? root.fileUrl(slot.sourcePath) : ""
            fillMode: root.fitMode === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            playing: slot.shouldPlay && root.powerActive && root.visible
                && nayoriCustomImageWidget.appearance.animationsEnabled
            smooth: true
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            visible: slot.isVideo
            fillMode: root.fitMode === "contain"
                ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop
        }

        Connections {
            target: videoOutput.videoSink
            enabled: slot.isVideo && !slot.videoHasFrame
            function onVideoFrameChanged(): void {
                const size = videoOutput.videoSink.videoSize
                if (size.width <= 0 || size.height <= 0) return
                slot.videoHasFrame = true
                if (!slot.shouldPlay || !root.powerActive || !root.visible)
                    slot.syncVideoPlayback()
            }
        }

        MediaPlayer {
            id: videoPlayer
            source: slot.isVideo ? root.fileUrl(slot.sourcePath) : ""
            videoOutput: videoOutput
            loops: MediaPlayer.Infinite
            onSourceChanged: {
                slot.videoHasFrame = false
                Qt.callLater(slot.syncVideoPlayback)
            }
        }
    }



    MaterialShape {
        hostBridge: nayoriCustomImageWidget
        id: shadowShape
        anchors.fill: parent
        shape: root.shapeEnum
        color: root.widgetSemanticContainer(root.widgetPrimaryRole)
        visible: false
    }

    StyledDropShadow {
        target: shadowShape
        visible: root.currentPath.length > 0 && !root._ryokuSurface
    }

    Item {
        id: maskedContent
        anchors.fill: parent
        layer.enabled: true
        layer.effect: GE.OpacityMask {
            // iNiR: the widget's own MaterialShape blob. Ryoku: a rounded square
            // matching the slot card, so media + card read as one surface.
            maskSource: Item {
                width: maskedContent.width
                height: maskedContent.height
                MaterialShape {
                    hostBridge: nayoriCustomImageWidget
                    anchors.fill: parent
                    shape: root.shapeEnum
                    visible: !root._ryokuSurface
                }
                Rectangle {
                    anchors.fill: parent
                    radius: root._ryokuClipRadius
                    visible: root._ryokuSurface
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            // Ryoku style leaves the slot card as the only backing.
            visible: !root._ryokuSurface
            color: root.widgetSemanticContainer(root.widgetPrimaryRole)
        }

        MediaSlot {
            id: mediaSlotA
            slotIndex: 0
            anchors.fill: parent
            opacity: root.activeSlot === 0 ? 1 : 0
            shouldPlay: !root.mediaPlaybackPaused
            Behavior on opacity {
                NumberAnimation {
                    duration: root.effectiveTransitionDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: nayoriCustomImageWidget.appearance.animationCurves.standard
                }
            }
        }

        MediaSlot {
            id: mediaSlotB
            slotIndex: 1
            anchors.fill: parent
            opacity: root.activeSlot === 1 ? 1 : 0
            shouldPlay: !root.mediaPlaybackPaused
            Behavior on opacity {
                NumberAnimation {
                    duration: root.effectiveTransitionDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: nayoriCustomImageWidget.appearance.animationCurves.standard
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: (root.currentPath.length === 0 || root.activeFailed) && !root._ryokuSurface
            text: root.activeFailed ? "broken_image" : (root.dropHover ? "download" : "perm_media")
            fill: root.dropHover ? 1 : 0
            iconSize: Math.max(28, Math.round(Math.min(root.renderedWidth, root.renderedHeight) * 0.24))
            color: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
        }

        MaterialShape {
            hostBridge: nayoriCustomImageWidget
            anchors.fill: parent
            visible: root.dropHover && !root._ryokuSurface
            shape: root.shapeEnum
            color: nayoriCustomImageWidget.colorUtils.applyAlpha(root.widgetAccentVisible, 0.22)
        }

        // Ryoku drop-hover wash, in the slot's rounded-square shape.
        Rectangle {
            anchors.fill: parent
            visible: root.dropHover && root._ryokuSurface
            radius: root._ryokuClipRadius
            color: nayoriCustomImageWidget.colorUtils.applyAlpha(root.irisAccent, 0.20)
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: !nayoriCustomImageWidget.globalStates.widgetEditMode
        keys: ["text/uri-list"]

        onEntered: drag => {
            drag.accept(Qt.CopyAction);
            root.dropHover = true;
        }
        onExited: root.dropHover = false
        onDropped: drop => {
            root.dropHover = false;
            if (!drop.hasUrls || drop.urls.length === 0) {
                drop.accepted = false;
                return;
            }

            const path = root.pathFromDropUrl(drop.urls[0]);
            if (!path || !nayoriCustomImageWidget.images.isValidMediaByName(path)) {
                drop.accepted = false;
                return;
            }

            root.setMediaPath(path);
            drop.accept(Qt.CopyAction);
        }
    }

    // Ryoku empty-state placeholder: a calm line glyph on the slot card with a
    // "Choose image" affordance that feeds the widget's own setMediaPath. Present
    // only when Ryoku-hosted with no media; iNiR keeps its own centred glyph.
    Column {
        anchors.centerIn: parent
        spacing: Math.round(10 * root.scaleFactor)
        visible: root._ryokuSurface && (root.currentPath.length === 0 || root.activeFailed)
        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.activeFailed ? "broken_image" : "image"
            fill: 0
            iconSize: Math.max(26, Math.round(Math.min(root.renderedWidth, root.renderedHeight) * 0.22))
            color: nayoriCustomImageWidget.colorUtils.applyAlpha(root.irisAccent, 0.72)
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Math.round(9 * root.scaleFactor)
            color: chooseArea.containsMouse ? nayoriCustomImageWidget.colorUtils.applyAlpha(root.irisAccent, 0.10) : "transparent"
            border.width: 1
            border.color: nayoriCustomImageWidget.colorUtils.applyAlpha(root.irisAccent, chooseArea.containsMouse ? 0.5 : 0.28)
            implicitWidth: chooseRow.implicitWidth + Math.round(20 * root.scaleFactor)
            implicitHeight: chooseRow.implicitHeight + Math.round(10 * root.scaleFactor)
            Row {
                id: chooseRow
                anchors.centerIn: parent
                spacing: Math.round(6 * root.scaleFactor)
                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "add_photo_alternate"
                    fill: 0
                    iconSize: Math.round(nayoriCustomImageWidget.appearance.font.pixelSize.normal * root.scaleFactor)
                    color: root.irisAccent
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: nayoriCustomImageWidget.translation.tr("Choose image")
                    color: root.irisAccent
                    font.pixelSize: Math.round(nayoriCustomImageWidget.appearance.font.pixelSize.small * root.scaleFactor)
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: chooseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: imagePick.open()
            }
        }
    }

    // Use the host Qt chooser; persist the selected file on this instance.
    FileDialog {
        id: imagePick
        title: nayoriCustomImageWidget.translation.tr("Choose image")
        currentFolder: "file://" + nayoriCustomImageWidget.directories.picturesPath
        nameFilters: [nayoriCustomImageWidget.translation.tr("Media") + " (" + nayoriCustomImageWidget.images.validImageExtensions
            .concat(nayoriCustomImageWidget.images.validVideoExtensions).map(ext => "*." + ext).join(" ") + ")"]
        onAccepted: root.setMediaPath(nayoriCustomImageWidget.fileUtils.trimFileProtocol(selectedFile))
    }
}
