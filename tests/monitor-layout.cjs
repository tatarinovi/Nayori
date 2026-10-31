const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const context = {}
vm.createContext(context)
vm.runInContext(fs.readFileSync("surfaces/settings/MonitorLayout.js", "utf8").replace(/^\.pragma.*$/m, ""), context)

const pair = context.fromModel([
    {name: "DP-1", mode: "2560x1440@164.836", scale: 1, hasPos: true, posX: 0, posY: 0},
    {name: "DP-2", mode: "2560x1440@164.999", scale: 1, hasPos: true, posX: 2560, posY: 0}
])
assert.strictEqual(pair[0].x, 0)
assert.strictEqual(pair[0].y, 0)
assert.strictEqual(pair[1].x, 2560)
assert.strictEqual(pair[1].y, 0)
assert.strictEqual(pair[0].width, 2560)
assert.strictEqual(pair[0].height, 1440)

const snapped = context.drop(pair, "DP-2", 2500, 30, true)
assert.strictEqual(snapped.find(item => item.name === "DP-1").x, 0)
assert.strictEqual(snapped.find(item => item.name === "DP-2").x, 2560)
assert.strictEqual(snapped.find(item => item.name === "DP-2").y, 0)

const below = context.drop(pair, "DP-2", 20, 1400, true)
assert.strictEqual(below.find(item => item.name === "DP-2").x, 0)
assert.strictEqual(below.find(item => item.name === "DP-2").y, 1440)

const free = context.drop(pair, "DP-2", 4000, 2000, false)
assert.strictEqual(free.find(item => item.name === "DP-1").x, 0)
assert.strictEqual(free.find(item => item.name === "DP-1").y, 0)
assert.strictEqual(free.find(item => item.name === "DP-2").x, 4000)
assert.strictEqual(free.find(item => item.name === "DP-2").y, 2000)

const turned = context.logicalSize({mode: "1920x1080", scale: 1, transform: "90"})
assert.strictEqual(turned.width, 1080)
assert.strictEqual(turned.height, 1920)

const scaled = context.logicalSize({mode: "2560x1440", scale: 2, transform: ""})
assert.strictEqual(scaled.width, 1280)
assert.strictEqual(scaled.height, 720)

const fresh = context.fromModel([
    {name: "A", screenWidth: 800, screenHeight: 600, hasPos: false},
    {name: "B", screenWidth: 800, screenHeight: 600, hasPos: false}
])
assert.strictEqual(fresh[0].x, 0)
assert.strictEqual(fresh[1].x, 800)
assert.strictEqual(fresh[1].y, 0)

const shifted = context.normalize([
    {name: "A", x: 100, y: 40, width: 10, height: 10},
    {name: "B", x: 300, y: 40, width: 10, height: 10}
])
assert.strictEqual(shifted[0].x, 0)
assert.strictEqual(shifted[0].y, 0)
assert.strictEqual(shifted[1].x, 200)

console.log("MONITOR_LAYOUT_PASS")
