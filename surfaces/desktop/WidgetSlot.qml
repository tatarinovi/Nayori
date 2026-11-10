pragma ComponentBehavior: Bound
import QtQuick
import "WidgetLayout.js" as WidgetLayout

// Adapted from Ryoku WidgetSlot.qml at f7197d72de8a21e44b0bea922bdd915f28f6b327.
// Gesture methods retain upstream move/resize/cancel semantics. Persistence is
// emitted as one transaction to Nayori's SettingsService owner; see NOTICE.
QtObject {
    id: slot
    required property var host
    property bool locked: false
    property bool composing: false
    property var stageController: null
    readonly property string widget: host.spec ? host.spec.id : ""
    readonly property bool stageInputBlocked: !host.editing && !host.moving
    readonly property real x: host.x
    readonly property real y: host.y
    readonly property real width: host.box.width
    readonly property real height: host.box.height
    readonly property real scaleCfg: 1
    readonly property real effectiveScale: resizing ? liveScale : 1
    readonly property real previewWidth: resizeStartWidth * liveScale
    readonly property real previewHeight: resizeStartHeight * liveScale
    property var gestureBefore: null
    property bool groupDragging: false
    property real groupX: 0
    property real groupY: 0
    property real groupDragMinX: -Infinity
    property real groupDragMaxX: Infinity
    property real groupDragMinY: -Infinity
    property real groupDragMaxY: Infinity
    property bool stageMoveActive: false
    property real stageMoveGrabX: 0
    property real stageMoveGrabY: 0
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    property bool resizing: false
    property bool resizeMoved: false
    property real liveScale: 1
    property string resizeCorner: "br"
    property real resizeStartScale: 1
    property real resizeStartWidth: 1
    property real resizeStartHeight: 1
    property real resizeStartDiag: 1
    property real resizeStartX: 0
    property real resizeStartY: 0
    property real resizeOppX: 0
    property real resizeOppY: 0
    signal positionCommitted(real x, real y)
    signal geometryCommitted(real x, real y, real width, real height)
    signal dropped(rect box)
    property Timer releaseGuard: Timer { id: guard; interval: 90 }
    function _captureGesture() {
        if (gestureBefore === null) gestureBefore = JSON.parse(JSON.stringify(host.spec))
    }
    function _setFree(x, y) { positionCommitted(x, y); gestureBefore = null }
    function _quantiseScale(value, modifiers) {
        const limits = WidgetLayout.sizeLimits(host.spec.type)
        const low = Math.max(limits.minWidth / width, limits.minHeight / height)
        const high = Math.min(limits.maxWidth / width, limits.maxHeight / height)
        const bounded = Math.max(low, Math.min(high, value))
        const quantised = Boolean(modifiers & Qt.ShiftModifier)
            ? Math.round(bounded * 100) / 100 : Math.abs(bounded - 1) < 0.03
            ? 1 : Math.round(bounded / 0.05) * 0.05
        return Math.max(low, Math.min(high, quantised))
    }
    function _commitScale(value, x, y) {
        geometryCommitted(Math.round(x), Math.round(y), Math.round(width * value), Math.round(height * value))
        gestureBefore = null
    }
    function stageSetScale(value) {
        if (locked || stageInputBlocked) return
        _captureGesture()
        _commitScale(_quantiseScale(value, Qt.NoModifier), x, y)
    }
    function clampX(value) {
        return host.screenWidth > 0 ? Math.max(0, Math.min(value, host.screenWidth - (resizing ? previewWidth : host.width))) : value
    }
    function clampY(value) {
        return host.screenHeight > 0 ? Math.max(0, Math.min(value, host.screenHeight - (resizing ? previewHeight : host.height))) : value
    }
    function snap(value) { return host.snap ? Math.round(value / WidgetLayout.gridSize()) * WidgetLayout.gridSize() : value }
    function stageBeginMove(point, modifiers) {
        if (slot.locked || slot.stageInputBlocked)
            return false;
        slot.stageMoveActive = true;
        slot._captureGesture();
        slot.stageMoveGrabX = point.x - slot.x;
        slot.stageMoveGrabY = point.y - slot.y;
        slot.dragX = slot.x;
        slot.dragY = slot.y;
        if (slot.composing && slot.stageController) {
            const bounds = slot.stageController.widgetDragStarted(slot.widget);
            if (bounds.active === false) {
                slot.stageMoveActive = false;
                slot.gestureBefore = null;
                return false;
            }
            slot.groupDragMinX = bounds.minX;
            slot.groupDragMaxX = bounds.maxX;
            slot.groupDragMinY = bounds.minY;
            slot.groupDragMaxY = bounds.maxY;
        }
        return true;
    }
    function stageUpdateMove(point, modifiers) {
        if (!slot.stageMoveActive || slot.locked)
            return;
        const nx = point.x - slot.stageMoveGrabX;
        const ny = point.y - slot.stageMoveGrabY;
        if (!slot.dragging) {
            if (Math.abs(nx - slot.x) < 6 && Math.abs(ny - slot.y) < 6)
                return;
            slot.dragging = true;
        }
        slot.dragX = Math.max(slot.groupDragMinX,
            Math.min(slot.groupDragMaxX, slot.clampX(nx)));
        slot.dragY = Math.max(slot.groupDragMinY,
            Math.min(slot.groupDragMaxY, slot.clampY(ny)));
        if (slot.composing && slot.stageController) {
            const bounded = slot.stageController.widgetDragMoved(
                slot.widget, slot.dragX, slot.dragY, modifiers);
            slot.dragX = bounded.x;
            slot.dragY = bounded.y;
        }
    }
    function stageEndMove(modifiers) {
        if (!slot.stageMoveActive)
            return;
        if (slot.dragging) {
            const fx = Math.round(Math.max(slot.groupDragMinX,
                Math.min(slot.groupDragMaxX, slot.composing
                    ? slot.dragX : slot.snap(slot.dragX))));
            const fy = Math.round(Math.max(slot.groupDragMinY,
                Math.min(slot.groupDragMaxY, slot.composing
                    ? slot.dragY : slot.snap(slot.dragY))));
            const handled = slot.composing && slot.stageController
                && slot.stageController.widgetDragEnded(
                    slot.widget, fx, fy, modifiers);
            if (!handled) {
                slot._setFree(fx, fy);
                slot.dropped(Qt.rect(fx, fy, slot.width, slot.height));
            } else {
                slot.gestureBefore = null;
            }
            slot.dragging = false;
            guard.restart();
        } else {
            if (slot.composing && slot.stageController)
                slot.stageController.widgetDragCancelled(slot.widget);
            slot.gestureBefore = null;
        }
        slot.stageMoveActive = false;
        slot.groupDragMinX = -Infinity;
        slot.groupDragMaxX = Infinity;
        slot.groupDragMinY = -Infinity;
        slot.groupDragMaxY = Infinity;
    }
    function stageCancelMove() {
        if (!slot.stageMoveActive)
            return;
        if (slot.composing && slot.stageController)
            slot.stageController.widgetDragCancelled(slot.widget);
        slot.dragging = false;
        slot.stageMoveActive = false;
        slot.gestureBefore = null;
        slot.groupDragMinX = -Infinity;
        slot.groupDragMaxX = Infinity;
        slot.groupDragMinY = -Infinity;
        slot.groupDragMaxY = Infinity;
    }
    function stageBeginResize(corner, point, modifiers) {
        if (slot.locked || slot.stageInputBlocked)
            return;
        slot._captureGesture();
        slot.resizeCorner = corner;
        slot.resizeStartScale = slot.effectiveScale;
        slot.resizeStartWidth = slot.width;
        slot.resizeStartHeight = slot.height;
        slot.resizeStartX = slot.x;
        slot.resizeStartY = slot.y;
        slot.resizeOppX = corner.indexOf("l") >= 0 ? slot.x + slot.width : slot.x;
        slot.resizeOppY = corner.indexOf("t") >= 0 ? slot.y + slot.height : slot.y;
        slot.resizeStartDiag = Math.max(1,
            Math.hypot(point.x - slot.resizeOppX, point.y - slot.resizeOppY));
        slot.dragX = slot.x;
        slot.dragY = slot.y;
        slot.liveScale = slot.scaleCfg;
        slot.resizeMoved = false;
        slot.resizing = true;
    }
    function stageUpdateResize(point, modifiers) {
        if (!slot.resizing)
            return;
        slot.resizeMoved = true;
        const distance = Math.max(1,
            Math.hypot(point.x - slot.resizeOppX, point.y - slot.resizeOppY));
        slot.liveScale = slot._quantiseScale(
            slot.resizeStartScale * distance / slot.resizeStartDiag, modifiers);
        const factor = slot.liveScale / Math.max(0.001, slot.resizeStartScale);
        const nextW = slot.resizeStartWidth * factor;
        const nextH = slot.resizeStartHeight * factor;
        slot.dragX = slot.resizeCorner.indexOf("l") >= 0
            ? slot.resizeOppX - nextW : slot.resizeOppX;
        slot.dragY = slot.resizeCorner.indexOf("t") >= 0
            ? slot.resizeOppY - nextH : slot.resizeOppY;
    }
    function stageEndResize() {
        if (!slot.resizing)
            return;
        if (!slot.resizeMoved) {
            slot.resizing = false;
            slot.gestureBefore = null;
            return;
        }
        const x = slot.clampX(slot.dragX);
        const y = slot.clampY(slot.dragY);
        slot._commitScale(slot.liveScale, x, y);
        slot.resizing = false;
        guard.restart();
    }
    function stageCancelResize() {
        slot.resizing = false;
        slot.liveScale = slot.scaleCfg;
        slot.gestureBefore = null;
    }
    function stageResetScale() {
        if (slot.locked || slot.stageInputBlocked) return;
        const natural = WidgetLayout.sizeOf({type: host.spec.type, size: host.spec.size});
        slot.geometryCommitted(slot.x, slot.y, natural.width, natural.height);
    }
    function stagePreviewPosition(x, y) {
        if (!slot.groupDragging) {
            slot.groupX = slot.x;
            slot.groupY = slot.y;
            slot.groupDragging = true;
        }
        slot.groupX = x;
        slot.groupY = y;
    }
    function stageEndPreview() {
        slot.groupDragging = false;
    }
}
