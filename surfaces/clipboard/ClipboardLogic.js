function filtered(records, query, kind) {
    const needle = String(query || "").trim().toLocaleLowerCase()
    return records.filter(record => {
        if (kind === "pinned" && !record.pinned) return false
        if (kind === "media" && record.kind !== "image" && record.kind !== "video") return false
        if ((kind === "image" || kind === "text") && record.kind !== kind) return false
        return !needle || (record.title + " " + record.text).toLocaleLowerCase().indexOf(needle) >= 0
    })
}

function typeLabel(record) {
    if (!record) return ""
    if (record.kind === "video") return "Видео"
    if (record.kind === "image") return "Изображение"
    if (record.kind === "file") return "Файл"
    return "Текст"
}

function metadata(record) {
    if (!record) return ""
    let text = (record.format || typeLabel(record)) + " · " + sizeLabel(record.bytes)
    if (record.width > 0 && record.height > 0) text += " · " + record.width + " × " + record.height
    return text
}

function placement(pointer, extent, available, gap, inset) {
    const after = pointer + gap
    const before = pointer - gap - extent
    return Math.max(inset, Math.min(after + extent <= available - inset ? after : before,
                                    available - extent - inset))
}

function relativeTime(created, now) {
    const minutes = Math.max(0, Math.floor((now - created) / 60000))
    if (minutes < 1) return "Только что"
    if (minutes < 60) return minutes + " мин"
    if (minutes < 1440) return Math.floor(minutes / 60) + " ч"
    return Math.floor(minutes / 1440) + " д"
}

function sizeLabel(bytes) {
    if (bytes < 1024) return bytes + " Б"
    if (bytes < 1048576) return Math.round(bytes / 1024) + " КБ"
    return (bytes / 1048576).toFixed(1).replace(".", ",") + " МБ"
}
