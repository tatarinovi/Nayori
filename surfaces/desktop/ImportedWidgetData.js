.pragma library

// Convert Nayori's shared wttr.in response to the original face contracts.
// Missing readings stay absent; the presentation's empty state remains visible.
function number(value) {
    if (value === null || value === undefined || value === "") return null
    var n = Number(value)
    return isFinite(n) ? n : null
}
function degrees(value, unit) {
    var n = number(value)
    if (n === null) return ""
    return String(Math.round(unit === "imperial" ? n * 9 / 5 + 32 : unit === "standard" ? n + 273.15 : n))
}
function weatherIcon(code, night) {
    code = Number(code)
    if (code === 113) return night ? "" : ""
    if ([143, 248, 260].indexOf(code) >= 0) return "󰖑"
    if ([200, 386, 389, 392, 395].indexOf(code) >= 0) return ""
    if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].indexOf(code) >= 0) return ""
    if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].indexOf(code) >= 0) return "󰖗"
    return ""
}
function weather(raw, city, unit, accent, now) {
    var current = raw && raw.current_condition && raw.current_condition[0]
    var symbol = unit === "imperial" ? "°F" : unit === "standard" ? "K" : "°C"
    var desc = function(row) { var list = row && (row.lang_ru || row.weatherDesc); return list && list[0] ? list[0].value || "" : "" }
    var days = raw && Array.isArray(raw.weather) ? raw.weather : []
    var forecast = days.map(function(day) {
        var hourly = (day.hourly || []).map(function(hour) {
            var minutes = Number(hour.time) / 100 * 60
            var night = minutes < 360 || minutes >= 1080
            return {time: String(Math.floor(minutes / 60)).padStart(2, "0") + ":00", minuteOfDay: minutes,
                label: String(Math.floor(minutes / 60)).padStart(2, "0") + ":00", temp: degrees(hour.tempC, unit),
                feels_like: degrees(hour.FeelsLikeC, unit), code: hour.weatherCode, isNight: night,
                icon: weatherIcon(hour.weatherCode, night), hex: accent, desc: desc(hour)}
        })
        return {date: day.date, tempMax: degrees(day.maxtempC, unit), tempMin: degrees(day.mintempC, unit),
            hiVal: number(degrees(day.maxtempC, unit)), loVal: number(degrees(day.mintempC, unit)),
            hourly: hourly, desc: hourly.length ? hourly[Math.floor(hourly.length / 2)].desc : ""}
    })
    var temp = current ? degrees(current.temp_C, unit) : ""
    return {city: city || "", temp: temp ? temp + symbol : "--", current_temp: temp,
        current_feels_like: current ? degrees(current.FeelsLikeC, unit) : "", wCode: current ? current.weatherCode : "",
        description: desc(current), desc: desc(current), forecast: forecast,
        hourly: forecast.length ? forecast[0].hourly.filter(function(row) { return row.minuteOfDay >= now.getHours() * 60 }).slice(0, 6) : [],
        tempMax: forecast.length ? forecast[0].tempMax : "", tempMin: forecast.length ? forecast[0].tempMin : "",
        current_icon: current ? weatherIcon(current.weatherCode, now.getHours() < 6 || now.getHours() >= 18) : "", unit_sym: symbol}
}
