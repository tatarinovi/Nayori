.pragma library

function values(model) {
    return model ? (Array.isArray(model) ? model : model.values || []) : []
}

function ranked(devices, wifiType) {
    const entries = []
    const list = values(devices)
    for (let d = 0; d < list.length; d++) {
        if (list[d].type !== wifiType)
            continue
        const networks = values(list[d].networks)
        for (let n = 0; n < networks.length; n++) {
            const entry = networks[n]
            if (entry && entry.name)
                entries.push(entry)
        }
    }
    return entries.sort(function(a, b) {
        return (Number(b.signalStrength) || 0) - (Number(a.signalStrength) || 0)
            || String(a.name).localeCompare(String(b.name))
    })
}

function speed(mbps) {
    return mbps >= 1000 ? (mbps / 1000).toLocaleString(Qt.locale(), 'f', mbps % 1000 ? 1 : 0) + " Гбит/с"
                        : mbps > 0 ? mbps + " Мбит/с" : ""
}
