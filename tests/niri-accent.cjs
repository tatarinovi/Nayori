const assert = require("assert")
const { spawnSync } = require("child_process")
const fs = require("fs")
const os = require("os")
const path = require("path")
const vm = require("vm")

function moduleAt(file) {
    const context = {}
    vm.createContext(context)
    vm.runInContext(fs.readFileSync(file, "utf8"), context)
    return context
}

const roles = moduleAt("tokens/AccentRoles.js")
assert.equal(roles.roles("#E23D5A", false).accent, "#C0AFD1")
assert.equal(roles.authoredRoles().accent, "#C0AFD1")

const fixture = "tests/fixtures/niri-accent/config.kdl"
const script = "services/niri/niri_accent.py"

function run(args) {
    const out = spawnSync("python3", [script, ...args], { encoding: "utf8" })
    let payload = null
    try {
        payload = JSON.parse(out.stdout)
    } catch (error) {
        payload = null
    }
    return { status: out.status, payload, stderr: out.stderr, stdout: out.stdout }
}

function colors(payload) {
    return payload.fields.map(function (field) { return field.node + " " + field.to })
}

const lavender = "#C0AFD1"
const manual = roles.roles("#E23D5A", true).accent
console.log("NIRI_ACCENT_DEFAULT " + lavender)
console.log("NIRI_ACCENT_MANUAL " + manual + " from #E23D5A")

const planned = run(["--dry-run", "--config", fixture, "--accent", lavender])
assert.equal(planned.status, 0, planned.stdout + planned.stderr)
assert.equal(planned.payload.ok, true)
assert.equal(planned.payload.changed, true)
assert.equal(planned.payload.accent, lavender)
assert.deepEqual(colors(planned.payload), [
    "layout.focus-ring.active-color #C0AFD1",
    "layout.border.active-color #C0AFD1",
    "layout.tab-indicator.active-color #C0AFD1",
    "layout.insert-hint.color #C0AFD180",
    "recent-windows.highlight.active-color #C0AFD1"
])
assert.equal(planned.payload.fields.length, 5)
planned.payload.fields.forEach(function (field) {
    assert.equal(field.file, "nayori-accent.kdl")
})
assert.equal(JSON.stringify(planned.payload).indexOf("noctalia.kdl"), -1)

const manualPlan = run(["--dry-run", "--config", fixture, "--accent", manual])
assert.equal(manualPlan.status, 0, manualPlan.stdout)
assert.equal(manualPlan.payload.accent, manual)
manualPlan.payload.fields.forEach(function (field) {
    assert.equal(field.file, "nayori-accent.kdl")
    const expected = field.node === "layout.insert-hint.color" ? manual + "80" : manual
    assert.equal(field.to, expected, field.node)
    console.log("NIRI_ACCENT_MANUAL_FIELD " + field.node + " " + field.to)
})
const adjusted = roles.roles("#101010", true).accent
assert.notEqual(adjusted, "#101010")
const adjustedPlan = run(["--dry-run", "--config", fixture, "--accent", adjusted])
adjustedPlan.payload.fields.forEach(function (field) {
    const expected = field.node === "layout.insert-hint.color" ? adjusted + "80" : adjusted
    assert.equal(field.to, expected, field.node)
})
console.log("NIRI_ACCENT_RESOLVED #101010 " + adjusted)

function noAccentBackups(dir) {
    const pending = [dir]
    while (pending.length) {
        const current = pending.pop()
        for (const name of fs.readdirSync(current)) {
            const full = path.join(current, name)
            assert.equal(name.endsWith(".bak"), false, full)
            assert.equal(name.indexOf(".nayori-accent-"), -1, full)
            assert.equal(name.indexOf(".nayori-"), -1, full)
            if (fs.statSync(full).isDirectory())
                pending.push(full)
        }
    }
}

const copy = fs.mkdtempSync(path.join(os.tmpdir(), "nayori-accent-"))
fs.cpSync("tests/fixtures/niri-accent", copy, { recursive: true })
const applied = run(["--apply", "--skip-validate", "--config", path.join(copy, "config.kdl"), "--accent", lavender])
assert.equal(applied.status, 0, applied.stdout + applied.stderr)
assert.equal(applied.payload.changed, true)
assert.deepEqual(applied.payload.backups, [])
applied.payload.fields.forEach(function (field) {
    assert.equal(field.file, "nayori-accent.kdl")
})
assert.equal(JSON.stringify(applied.payload).indexOf("noctalia.kdl"), -1)
const noctalia = fs.readFileSync(path.join(copy, "noctalia.kdl"), "utf8")
assert.equal(noctalia, fs.readFileSync("tests/fixtures/niri-accent/noctalia.kdl", "utf8"))
assert.ok(noctalia.includes('active-color   "#debcde"'))
assert.ok(noctalia.includes('color "#debcde80"'))
const written = fs.readFileSync(path.join(copy, "nayori-accent.kdl"), "utf8")
assert.ok(written.includes('active-color "#C0AFD1"'))
assert.ok(written.includes('color "#C0AFD180"'))
assert.ok(!written.toLowerCase().includes("debcde"))
assert.ok(!written.includes("inactive-color"))
const originalConfig = fs.readFileSync("tests/fixtures/niri-accent/config.kdl", "utf8")
const expectedConfig = originalConfig.replace(
    'include "noctalia.kdl"\n',
    'include "noctalia.kdl"\ninclude "nayori-accent.kdl"\n'
)
assert.notEqual(expectedConfig, originalConfig)
assert.equal(fs.readFileSync(path.join(copy, "config.kdl"), "utf8"), expectedConfig)
assert.equal(
    fs.readFileSync(path.join(copy, "cfg/layout.kdl"), "utf8"),
    fs.readFileSync("tests/fixtures/niri-accent/cfg/layout.kdl", "utf8")
)
assert.equal(
    fs.readFileSync(path.join(copy, "cfg/display.kdl"), "utf8"),
    fs.readFileSync("tests/fixtures/niri-accent/cfg/display.kdl", "utf8")
)
assert.equal(
    fs.readFileSync(path.join(copy, "cfg/misc.kdl"), "utf8"),
    fs.readFileSync("tests/fixtures/niri-accent/cfg/misc.kdl", "utf8")
)
noAccentBackups(copy)
const again = run(["--apply", "--skip-validate", "--config", path.join(copy, "config.kdl"), "--accent", lavender])
assert.equal(again.payload.changed, false)
assert.deepEqual(again.payload.backups, [])
assert.equal(again.payload.fields[0].file, "nayori-accent.kdl")
const names = fs.readdirSync(copy)
assert.ok(names.indexOf("nayori-accent.kdl") >= 0)
assert.equal(names.filter(function (name) { return name.indexOf("noctalia.kdl.nayori") === 0 }).length, 0)
assert.equal(names.filter(function (name) { return name.indexOf("nayori-accent") >= 0 && name.endsWith(".bak") }).length, 0)
noAccentBackups(copy)

const missing = run(["--dry-run", "--config", path.join(copy, "missing.kdl"), "--accent", lavender])
assert.equal(missing.status, 1)
assert.equal(missing.payload.error, "Файл конфигурации niri не найден")

const bare = fs.mkdtempSync(path.join(os.tmpdir(), "nayori-accent-bare-"))
fs.writeFileSync(path.join(bare, "config.kdl"), "layout {\n    gaps 10\n    focus-ring { width 2 }\n}\n")
const noAccent = run(["--dry-run", "--config", path.join(bare, "config.kdl"), "--accent", lavender])
assert.equal(noAccent.payload.error, "В конфигурации niri нет цвета акцента")
assert.equal(fs.readFileSync(path.join(bare, "config.kdl"), "utf8"), "layout {\n    gaps 10\n    focus-ring { width 2 }\n}\n")

const bad = fs.mkdtempSync(path.join(os.tmpdir(), "nayori-accent-bad-"))
const badText = "layout {\n    focus-ring {\n        active-color \"red\"\n    }\n}\n"
fs.writeFileSync(path.join(bad, "config.kdl"), badText)
const blocked = run(["--apply", "--skip-validate", "--config", path.join(bad, "config.kdl"), "--accent", lavender])
assert.equal(blocked.payload.ok, false)
assert.equal(blocked.payload.error, "Не удалось прочитать цвет акцента niri")
assert.equal(fs.readFileSync(path.join(bad, "config.kdl"), "utf8"), badText)
assert.equal(fs.readdirSync(bad).length, 1)
noAccentBackups(bad)

const rejected = fs.mkdtempSync(path.join(os.tmpdir(), "nayori-accent-reject-"))
fs.cpSync("tests/fixtures/niri-accent", rejected, { recursive: true })
const fakeBin = fs.mkdtempSync(path.join(os.tmpdir(), "nayori-accent-niri-"))
fs.writeFileSync(path.join(fakeBin, "niri"), "#!/bin/sh\nexit 1\n", { mode: 0o755 })
const failed = spawnSync("python3", [script, "--apply", "--config", path.join(rejected, "config.kdl"), "--accent", lavender], {
    encoding: "utf8",
    env: Object.assign({}, process.env, { PATH: fakeBin + path.delimiter + (process.env.PATH || "") })
})
let failedPayload = null
try {
    failedPayload = JSON.parse(failed.stdout)
} catch (error) {
    failedPayload = null
}
assert.equal(failed.status, 1, failed.stdout + failed.stderr)
assert.equal(failedPayload.ok, false)
assert.equal(failedPayload.error, "Конфигурация niri не приняла цвет акцента. Прежний текст возвращён")
assert.deepEqual(failedPayload.backups, [])
assert.equal(fs.readFileSync(path.join(rejected, "config.kdl"), "utf8"), fs.readFileSync("tests/fixtures/niri-accent/config.kdl", "utf8"))
assert.equal(fs.existsSync(path.join(rejected, "nayori-accent.kdl")), false)
assert.equal(fs.readFileSync(path.join(rejected, "noctalia.kdl"), "utf8"), fs.readFileSync("tests/fixtures/niri-accent/noctalia.kdl", "utf8"))
noAccentBackups(rejected)
console.log("NIRI_ACCENT_VALIDATE_RESTORE no backup")

const gated = fs.mkdtempSync(path.join(os.tmpdir(), "nayori-accent-off-"))
fs.cpSync("tests/fixtures/niri-accent", gated, { recursive: true })
const beforeTree = fs.readdirSync(gated).sort()
const noctaliaBefore = fs.readFileSync(path.join(gated, "noctalia.kdl"))
const configBefore = fs.readFileSync(path.join(gated, "config.kdl"))
const off = run(["--apply", "--integration", "off", "--config", path.join(gated, "config.kdl"), "--accent", "#E23D5A"])
assert.equal(off.status, 0, off.stdout + off.stderr)
assert.equal(off.payload.ok, true)
assert.equal(off.payload.changed, false)
assert.equal(off.payload.skipped, true)
assert.deepEqual(off.payload.fields, [])
assert.deepEqual(off.payload.backups, [])
assert.equal(off.payload.accent, "")
assert.equal(JSON.stringify(off.payload).indexOf("noctalia.kdl"), -1)
assert.equal(fs.existsSync(path.join(gated, "nayori-accent.kdl")), false)
assert.deepEqual(fs.readdirSync(gated).sort(), beforeTree)
assert.deepEqual(fs.readFileSync(path.join(gated, "noctalia.kdl")), noctaliaBefore)
assert.deepEqual(fs.readFileSync(path.join(gated, "config.kdl")), configBefore)
const noctaliaPath = path.join(gated, "noctalia.kdl")
const offNoctalia = run(["--apply", "--integration", "off", "--skip-validate", "--config", noctaliaPath, "--accent", lavender])
assert.equal(offNoctalia.status, 0, offNoctalia.stdout + offNoctalia.stderr)
assert.equal(offNoctalia.payload.skipped, true)
assert.equal(offNoctalia.payload.changed, false)
assert.deepEqual(offNoctalia.payload.fields, [])
assert.equal(JSON.stringify(offNoctalia.payload).indexOf("noctalia.kdl"), -1)
assert.deepEqual(fs.readFileSync(noctaliaPath), noctaliaBefore)
assert.equal(fs.existsSync(path.join(gated, "nayori-accent.kdl")), false)
console.log("NIRI_ACCENT_OFF skipped " + off.payload.skipped)

console.log("NIRI_ACCENT_PASS")
