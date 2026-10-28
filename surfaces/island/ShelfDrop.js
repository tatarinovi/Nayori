// Normalize Qt's browser and file-manager offers before the Wayland drop completes.
function formats(event) { return Array.from(event.formats || []) }
function supports(event) {
    return formats(event).some(f => /^text\/(plain|uri-list|html|x-moz-url)/i.test(f) || /^image\//i.test(f) || /^application\/octet-stream;/i.test(f))
}
function prefetch(event) {
    for (const format of formats(event)) {
        if (supports({formats: [format]})) {
            try { event.getDataAsArrayBuffer(format) } catch (error) {}
        }
    }
    if (event.hasUrls) return event.urls
    return []
}
function stringData(event, format) {
    try { return String(event.getDataAsString(format) || "") } catch (error) { return "" }
}
function imageSource(html) {
    const tag = String(html || "").match(/<img\b[^>]*>/i)
    if (!tag) return ""
    const attr = name => {
        const match = tag[0].match(new RegExp("\\b" + name + "\\s*=\\s*[\"']([^\"']+)[\"']", "i"))
        return match ? match[1].replace(/&amp;/g, "&") : ""
    }
    const candidates = attr("srcset").split(/,\s+/).map(s => s.trim().split(/\s+/))
    candidates.sort((a, b) => (parseFloat(b[1]) || 0) - (parseFloat(a[1]) || 0))
    const source = (candidates[0] && candidates[0][0]) || attr("src")
    return /^(https?:|data:image\/|blob:)/i.test(source) ? source : ""
}
function read(event) {
    let urls = event.hasUrls ? Array.from(event.urls, String) : []
    if (!urls.length) urls = stringData(event, "text/uri-list").split(/\r?\n/)
    if (!urls.some(u => /^(file|https?):\/\//i.test(u))) urls = stringData(event, "text/x-moz-url").split(/\r?\n/).slice(0, 1)
    urls = urls.filter(u => /^(file|https?):\/\//i.test(u))
    const text = (event.hasText ? event.text : "") || stringData(event, "text/plain")
    const html = (event.hasHtml ? event.html : "") || stringData(event, "text/html")
    let image = imageSource(html)
    if (!image && urls.length === 1 && /^https?:.*\.(png|jpe?g|gif|webp|bmp)([?#]|$)/i.test(urls[0])) image = urls[0]
    const format = formats(event).find(f => /^image\/(png|jpeg|gif|webp|bmp)$/i.test(f) || /^application\/octet-stream;/i.test(f))
    if (format && !urls.some(u => /^file:/i.test(u))) {
        try {
            const bytes = new Uint8Array(event.getDataAsArrayBuffer(format))
            if (bytes.length > 16 * 1024 * 1024) return {error: "Изображение больше 16 МиБ"}
            if (bytes.length) {
                const parts = []
                for (let i = 0; i < bytes.length; i += 8192) parts.push(String.fromCharCode.apply(null, bytes.subarray(i, i + 8192)))
                image = "data:application/octet-stream;base64," + Qt.btoa(parts.join(""))
            }
        } catch (error) {}
    }
    return {urls: urls, text: String(text || ""), image: image}
}
function mime(item) {
    return item.kind === "text" ? {"text/plain": item.text} : item.kind === "link"
        ? {"text/plain": item.url, "text/uri-list": item.url + "\r\n"}
        : {"text/uri-list": item.uri + "\r\n"}
}
