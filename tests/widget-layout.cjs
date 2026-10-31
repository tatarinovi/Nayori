const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const context = {}
vm.createContext(context)
vm.runInContext(fs.readFileSync("surfaces/desktop/WidgetLayout.js", "utf8").replace(/^\.pragma.*$/m, ""), context)

const clock = { id: "a", type: "clock", x: 10, y: 12, size: "large", style: "plain" }
const note = { id: "b", type: "note", x: 4, y: 8, size: "compact", style: "card", text: "привет" }

const saved = {
    "DP-1": { snap: true, items: [clock] },
    "HDMI-A-1": { snap: false, items: [note, { id: "gone", type: "photo", x: 1, y: 1 }] }
}
const normalized = context.normalize(saved)
assert.deepStrictEqual(Object.keys(normalized).sort(), ["DP-1", "HDMI-A-1"])
assert.strictEqual(normalized["HDMI-A-1"].snap, false)
assert.strictEqual(normalized["HDMI-A-1"].items.length, 1)
assert.strictEqual(normalized["HDMI-A-1"].items[0].text, "привет")
assert.strictEqual(normalized["DP-1"].items[0].style, "plain")
assert.strictEqual(normalized["DP-1"].items[0].size, "large")
assert.strictEqual("color" in normalized["DP-1"].items[0], false)

const connected = ["DP-1"]
assert.ok(connected.indexOf("HDMI-A-1") < 0)
assert.ok(normalized["HDMI-A-1"])

assert.deepStrictEqual(context.normalize(null), {})
assert.deepStrictEqual(context.normalize([]), {})
assert.deepStrictEqual(context.normalize("DP-1"), {})

const messy = context.normalize({
    "DP-1": {
        items: [
            { type: "nope", x: "bad", y: null },
            { type: "clock", x: "nope", y: NaN, id: "a", extra: true },
            { type: "note", id: "a", text: 12, size: "huge", style: "glass" },
            { type: "music", x: -4, y: 3.6, text: "не заметка" }
        ]
    },
    "eDP-1": null,
    "": { items: [] },
    "bad\nname": { items: [{ type: "clock" }] }
})
assert.deepStrictEqual(Object.keys(messy).sort(), ["DP-1", "eDP-1"])
assert.strictEqual(messy["DP-1"].snap, true)
assert.strictEqual(messy["DP-1"].items.length, 3)
assert.strictEqual(messy["DP-1"].items[0].id, "a")
assert.strictEqual(messy["DP-1"].items[0].x, 0)
assert.strictEqual(messy["DP-1"].items[0].y, 0)
assert.strictEqual("extra" in messy["DP-1"].items[0], false)
assert.strictEqual("text" in messy["DP-1"].items[0], false)
assert.strictEqual(messy["DP-1"].items[1].type, "note")
assert.notStrictEqual(messy["DP-1"].items[1].id, "a")
assert.strictEqual(messy["DP-1"].items[1].text, "")
assert.strictEqual(messy["DP-1"].items[1].size, "compact")
assert.strictEqual(messy["DP-1"].items[1].style, "card")
assert.strictEqual(messy["DP-1"].items[2].x, -4)
assert.strictEqual(messy["DP-1"].items[2].y, 4)
assert.strictEqual("text" in messy["DP-1"].items[2], false)
assert.deepStrictEqual(messy["eDP-1"], { snap: true, items: [] })

const wide = context.clamp([
    { id: "a", type: "clock", x: 99999, y: -40, size: "compact", style: "card" }
], 800, 600)
assert.strictEqual(wide.length, 1)
assert.strictEqual(wide[0].x, 800 - 220)
assert.strictEqual(wide[0].y, 0)
assert.strictEqual(wide[0].id, "a")

const oversized = context.clamp([
    { id: "a", type: "clock", x: 40, y: 50, size: "large", style: "plain" }
], 200, 100)
assert.strictEqual(oversized.length, 1)
assert.strictEqual(oversized[0].x, 0)
assert.strictEqual(oversized[0].y, 0)
assert.strictEqual(oversized[0].type, "clock")

const pinned = context.clamp(normalized["DP-1"].items, 0, Number.NaN)
assert.strictEqual(pinned.length, 1)
assert.strictEqual(pinned[0].x, 0)
assert.strictEqual(pinned[0].y, 0)

const source = [{ id: "a", type: "note", x: 8, y: 8, size: "compact", style: "card", text: "a" }]
const frozen = JSON.stringify(source)
const snapped = context.move(source, "a", 30, 50, true, 24)
assert.strictEqual(JSON.stringify(source), frozen)
assert.strictEqual(snapped[0].x, 24)
assert.strictEqual(snapped[0].y, 48)
assert.strictEqual(snapped[0].text, "a")
const free = context.move(source, "a", 30, 50, false, 24)
assert.strictEqual(free[0].x, 30)
assert.strictEqual(free[0].y, 50)
const grid16 = context.move(source, "a", 20, 20, true, 16)
assert.strictEqual(grid16[0].x, 16)
assert.strictEqual(grid16[0].y, 16)
const missingMove = context.move(source, "nope", 100, 100, true, 24)
assert.strictEqual(missingMove[0].x, 8)
assert.strictEqual(missingMove[0].y, 8)

const atEdge = context.clamp(context.move(source, "a", 400, 500, true, 24), 280, 180)
assert.strictEqual(atEdge.length, 1)
assert.strictEqual(atEdge[0].x, 280 - 260)
assert.strictEqual(atEdge[0].y, 180 - 168)
assert.strictEqual(atEdge[0].text, "a")

const added = context.add(source, { type: "clock", size: "large", style: "plain" })
assert.strictEqual(JSON.stringify(source), frozen)
assert.strictEqual(added.length, 2)
assert.strictEqual(added[0].text, "a")
assert.strictEqual(added[1].type, "clock")
assert.strictEqual(added[1].size, "large")
assert.strictEqual(added[1].style, "plain")
assert.notStrictEqual(added[1].id, "a")
assert.strictEqual(context.add(source, { type: "photo" }).length, 1)
const placed = context.add([], { type: "system", x: 9000, y: -20 }, 400, 300)
assert.strictEqual(placed.length, 1)
assert.strictEqual(placed[0].x, 400 - context.sizeOf(placed[0]).width)
assert.strictEqual(placed[0].y, 0)

const removed = context.remove(added, added[1].id)
assert.strictEqual(removed.length, 1)
assert.strictEqual(removed[0].id, "a")
assert.strictEqual(context.remove(added, "missing").length, 2)
assert.strictEqual(JSON.stringify(added), JSON.stringify(added))

const edited = context.editText(source, "a", "новый текст")
assert.strictEqual(source[0].text, "a")
assert.strictEqual(edited[0].text, "новый текст")
assert.strictEqual(context.editText([{ id: "c", type: "clock", x: 0, y: 0, size: "compact", style: "card" }], "c", "нет").length, 1)
assert.strictEqual("text" in context.editText([{ id: "c", type: "clock", x: 0, y: 0 }], "c", "нет")[0], false)

const serviceShape = context.readWeather({ temp_C: "0", FeelsLikeC: " -2 ", weatherCode: "113", lang_ru: [{ value: "Солнечно" }] })
assert.strictEqual(serviceShape.temperature, 0)
assert.strictEqual(serviceShape.feelsLike, -2)
assert.strictEqual(serviceShape.description, "Солнечно")
assert.deepStrictEqual(serviceShape.forecast, [])
assert.strictEqual(context.temperatureText(serviceShape.feelsLike), "\u2212" + "2°")

const full = context.readWeather({
    current_condition: [{ temp_C: "18", weatherCode: 176, humidity: "40" }],
    weather: [
        { date: "2026-10-31", maxtempC: "12", mintempC: "4" },
        { date: "2026-02-31", maxtempC: "1", mintempC: "0" },
        { date: "2026-11-01", maxtempC: "nope", mintempC: "" },
        { date: "tomorrow", maxtempC: "9" }
    ]
})
assert.strictEqual(full.temperature, 18)
assert.strictEqual(full.description, "Дождь")
assert.strictEqual(full.humidity, 40)
assert.strictEqual(full.forecast.length, 2)
assert.strictEqual(full.forecast[0].label, "31\u00A0окт")
assert.strictEqual(full.forecast[0].max, 12)
assert.strictEqual(full.forecast[0].min, 4)
assert.strictEqual(full.forecast[1].label, "")
assert.strictEqual(full.forecast[1].max, 9)
assert.strictEqual(context.readWeather(null), null)
assert.strictEqual(context.readWeather({}), null)
assert.strictEqual(context.readWeather({ weather: [{ date: "2026-10-31", maxtempC: "bad" }] }), null)

assert.strictEqual(context.cpuLoad(null, { total: 10, idle: 4 }), null)
const first = context.readCpuCounters("cpu  100 0 50 200 10 0 0 0 0 0\ncpu0 1 0 0 1 0 0 0 0")
const second = context.readCpuCounters("cpu 110 0 60 240 20 0 0 0 0 0")
assert.ok(first && second)
assert.ok(Math.abs(context.cpuLoad(first, second) - (1 - 50 / 70)) < 1e-9)
assert.strictEqual(context.readCpuCounters("cpu0 1 2 3 4 5 6 7 8"), null)
assert.strictEqual(context.readCpuCounters(""), null)

const memory = context.readMeminfo("MemTotal:       1000 kB\nMemFree:         100 kB\nMemAvailable:    400 kB\n")
assert.strictEqual(memory.used, 0.6)
assert.strictEqual(context.readMeminfo("MemTotal: 1000 kB\nMemFree: 100 kB\n"), null)
assert.strictEqual(context.readMeminfo("MemTotal: 100 kB\nMemAvailable: 400 kB\n"), null)
assert.strictEqual(context.percentLabel(null), "")
assert.strictEqual(context.percentLabel(0), "0%")
assert.strictEqual(context.percentLabel(0.126), "13%")
assert.strictEqual(context.percentLabel(1.2), "")
assert.strictEqual(context.batteryPercent(0.42), "42%")
assert.strictEqual(context.batteryPercent(42), "42%")
assert.strictEqual(context.batteryPercent(0), "0%")
assert.strictEqual(context.batteryPercent(150), "")
assert.strictEqual(context.batteryPercent(Number.NaN), "")

assert.strictEqual(context.gridSize(), 24)
assert.strictEqual(context.sameLayout(normalized["DP-1"], context.normalizeScreen(saved["DP-1"])), true)
assert.strictEqual(context.sameIds(normalized["DP-1"].items, [{ id: "a" }]), true)

console.log("WIDGET_LAYOUT_PASS")
