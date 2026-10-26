// Данные об источниках уведомлений. Правится здесь, остальной код не трогать.
//
// Имена сравниваются без регистра и без символов, кроме букв и цифр:
// «Telegram Desktop», «telegram-desktop» и «telegramdesktop» — одно и то же.
// Сравнивается appName уведомления и его desktop-entry.

// Фильтр «Системные»: уведомления от этих источников.
function systemSources() {
    return [
        "niri",
        "система",
        "system",
        "systemd",
        "батарея",
        "battery",
        "upower",
        "powerprofiles",
        "networkmanager",
        "network",
        "bluetooth",
        "bluez",
        "udisks",
        "udiskie",
        "polkit",
        "pipewire",
        "quickshell",
        "nayori",
        "notify-send",
        "screenshot",
        "скриншот"
    ]
}

// Оформление источников без своей иконки в теме: плитка с рисованным значком.
// glyph — имя из surfaces/island/Glyph.qml; tone: "accent" (по умолчанию) или "warning".
function sourceStyles() {
    return [
        { match: ["niri", "screenshot", "скриншот"], glyph: "terminal", tone: "accent" },
        { match: ["система", "system", "systemd", "батарея", "battery", "upower", "powerprofiles"], glyph: "battery", tone: "warning" },
        { match: ["networkmanager", "network", "bluetooth", "bluez"], glyph: "gear", tone: "accent" }
    ]
}
