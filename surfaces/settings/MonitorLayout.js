.pragma library

// Положение мониторов на схеме настроек. Координаты — логические пиксели niri.
// Перетаскивание считает X и Y само: после отпускания блок сдвигается так,
// чтобы левый верхний угол схемы стал нулём.

function logicalSize(item) {
    var scale = Number(item && item.scale)
    if (!isFinite(scale) || scale <= 0)
        scale = 1
    var width = 0
    var height = 0
    var mode = String(item && item.mode || "")
    var parsed = /^(\d+)x(\d+)/.exec(mode)
    if (parsed) {
        width = Number(parsed[1]) / scale
        height = Number(parsed[2]) / scale
    } else if (Number(item && item.screenWidth) > 0 && Number(item && item.screenHeight) > 0) {
        width = Number(item.screenWidth)
        height = Number(item.screenHeight)
        scale = 1
    } else {
        width = 1920
        height = 1080
    }
    var transform = String(item && item.transform || "")
    if (transform === "90" || transform === "270" || transform === "flipped-90" || transform === "flipped-270") {
        var swap = width
        width = height
        height = swap
    }
    return {
        width: Math.max(1, Math.round(width)),
        height: Math.max(1, Math.round(height))
    }
}

function copyOf(item) {
    return {
        name: item.name,
        x: item.x,
        y: item.y,
        width: item.width,
        height: item.height,
        modeLabel: item.modeLabel || "",
        locked: item.locked === true
    }
}

function normalize(items) {
    if (!items.length)
        return []
    var minX = items[0].x
    var minY = items[0].y
    var index
    for (index = 1; index < items.length; index++) {
        minX = Math.min(minX, items[index].x)
        minY = Math.min(minY, items[index].y)
    }
    var next = []
    for (index = 0; index < items.length; index++) {
        var item = copyOf(items[index])
        item.x = Math.round(item.x - minX)
        item.y = Math.round(item.y - minY)
        next.push(item)
    }
    return next
}

function fromModel(list) {
    var pending = []
    var index
    var cursor = 0
    var bottom = 0
    for (index = 0; index < list.length; index++) {
        var source = list[index] || {}
        var size = logicalSize(source)
        var hasPos = source.hasPos === true && isFinite(Number(source.posX)) && isFinite(Number(source.posY))
        var item = {
            name: String(source.name || ""),
            x: hasPos ? Number(source.posX) : 0,
            y: hasPos ? Number(source.posY) : 0,
            width: size.width,
            height: size.height,
            modeLabel: source.modeLabel || (size.width + "×" + size.height),
            locked: source.locked === true,
            placed: hasPos
        }
        if (hasPos) {
            cursor = Math.max(cursor, item.x + item.width)
            bottom = Math.max(bottom, item.y + item.height)
        }
        pending.push(item)
    }
    for (index = 0; index < pending.length; index++) {
        if (pending[index].placed)
            continue
        pending[index].x = cursor
        pending[index].y = 0
        cursor += pending[index].width
    }
    var clean = []
    for (index = 0; index < pending.length; index++) {
        var ready = copyOf(pending[index])
        clean.push(ready)
    }
    return normalize(clean)
}

function intersects(left, right) {
    return left.x < right.x + right.width
        && left.x + left.width > right.x
        && left.y < right.y + right.height
        && left.y + left.height > right.y
}

function separate(items, name) {
    var self = null
    var index
    for (index = 0; index < items.length; index++) {
        if (items[index].name === name)
            self = items[index]
    }
    if (!self)
        return
    var pass
    for (pass = 0; pass < items.length; pass++) {
        var moved = false
        for (index = 0; index < items.length; index++) {
            var other = items[index]
            if (other === self || !intersects(self, other))
                continue
            var overlapX = Math.min(self.x + self.width, other.x + other.width) - Math.max(self.x, other.x)
            var overlapY = Math.min(self.y + self.height, other.y + other.height) - Math.max(self.y, other.y)
            if (overlapX <= 0 || overlapY <= 0)
                continue
            if (overlapX < overlapY) {
                var dirX = (self.x + self.width / 2) < (other.x + other.width / 2) ? -1 : 1
                self.x += dirX * overlapX
            } else {
                var dirY = (self.y + self.height / 2) < (other.y + other.height / 2) ? -1 : 1
                self.y += dirY * overlapY
            }
            moved = true
        }
        if (!moved)
            break
    }
}

function snapToNeighbors(items, name) {
    var self = null
    var index
    for (index = 0; index < items.length; index++) {
        if (items[index].name === name)
            self = items[index]
    }
    if (!self)
        return
    var threshold = Math.max(48, Math.min(self.width, self.height) * 0.12)
    var best = null
    for (index = 0; index < items.length; index++) {
        var other = items[index]
        if (other === self)
            continue
        var candidates = [
            {x: other.x + other.width, y: other.y},
            {x: other.x + other.width, y: other.y + other.height - self.height},
            {x: other.x - self.width, y: other.y},
            {x: other.x - self.width, y: other.y + other.height - self.height},
            {x: other.x, y: other.y + other.height},
            {x: other.x + other.width - self.width, y: other.y + other.height},
            {x: other.x, y: other.y - self.height},
            {x: other.x + other.width - self.width, y: other.y - self.height}
        ]
        var candidateIndex
        for (candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
            var candidate = candidates[candidateIndex]
            var dist = Math.hypot(candidate.x - self.x, candidate.y - self.y)
            if (dist <= threshold && (!best || dist < best.dist))
                best = {dist: dist, x: candidate.x, y: candidate.y}
        }
    }
    if (best) {
        self.x = best.x
        self.y = best.y
    }
}

function drop(items, name, x, y, snap) {
    var next = []
    var index
    for (index = 0; index < items.length; index++)
        next.push(copyOf(items[index]))
    var self = null
    for (index = 0; index < next.length; index++) {
        if (next[index].name === name)
            self = next[index]
    }
    if (!self || self.locked)
        return normalize(next)
    self.x = x
    self.y = y
    if (snap)
        snapToNeighbors(next, name)
    separate(next, name)
    return normalize(next)
}

function view(items, canvasWidth, canvasHeight, pad) {
    var padding = pad === undefined ? 28 : pad
    if (!items.length || canvasWidth <= 0 || canvasHeight <= 0)
        return {scale: 1, ox: padding, oy: padding}
    var minX = items[0].x
    var minY = items[0].y
    var maxX = items[0].x + items[0].width
    var maxY = items[0].y + items[0].height
    var index
    for (index = 1; index < items.length; index++) {
        minX = Math.min(minX, items[index].x)
        minY = Math.min(minY, items[index].y)
        maxX = Math.max(maxX, items[index].x + items[index].width)
        maxY = Math.max(maxY, items[index].y + items[index].height)
    }
    var innerW = Math.max(1, canvasWidth - padding * 2)
    var innerH = Math.max(1, canvasHeight - padding * 2)
    var scale = Math.min(innerW / Math.max(maxX - minX, 1), innerH / Math.max(maxY - minY, 1))
    var usedW = (maxX - minX) * scale
    var usedH = (maxY - minY) * scale
    return {
        scale: scale,
        ox: (canvasWidth - usedW) / 2 - minX * scale,
        oy: (canvasHeight - usedH) / 2 - minY * scale
    }
}
