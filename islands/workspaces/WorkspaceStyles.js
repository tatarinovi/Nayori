// Presentation only: Niri state and actions stay in WorkspacesIsland.
var styles = [
    { key: "dots", name: "Dots" },
    { key: "numbers", name: "Numbers" },
    { key: "kanji", name: "Kanji" },
    { key: "greek", name: "Greek" },
    { key: "dashes", name: "Dashes" },
    { key: "icons", name: "Icons" }
]

function normalize(value) {
    return styles.some(style => style.key === value) ? value : "dots"
}

function label(style, number) {
    const n = Math.max(1, Math.floor(Number(number) || 1))
    if (style === "kanji") {
        const digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        if (n < 10) return digits[n]
        if (n < 100) return (n < 20 ? "" : digits[Math.floor(n / 10)]) + "十" + digits[n % 10]
    }
    if (style === "greek") {
        const letters = "αβγδεζηθικλμνξοπρστυφχψω"
        return letters[(n - 1) % letters.length] + (n > letters.length ? String(Math.floor((n - 1) / letters.length) + 1) : "")
    }
    return String(n)
}
