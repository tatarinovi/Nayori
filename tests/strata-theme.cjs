const assert = require("assert")
const { spawnSync } = require("child_process")
const fs = require("fs")
const os = require("os")
const path = require("path")

const script = "services/strata/strata_theme.py"
const palette = {
    background: "#121217",
    surface: "#4F4F57",
    surfaceAlt: "#443D4E",
    text: "#F0E9DB",
    textMuted: "#D5CEC4",
    accent: "#FFC0AFD1",
    accentSoft: "#80758C",
    secondary: "#CAA7AA"
}

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

const missingBin = fs.mkdtempSync(path.join(os.tmpdir(), "nayori-strata-missing-bin-"))
const notInstalled = run(["build", "--json", JSON.stringify(palette), "--config-dir", missingBin, "--strata-bin", path.join(missingBin, "no-strata")])
assert.equal(notInstalled.status, 1, notInstalled.stdout + notInstalled.stderr)
assert.equal(notInstalled.payload.ok, false)
assert.equal(notInstalled.payload.error, "Strata не установлен. Тема не записана")
assert.equal(fs.existsSync(path.join(missingBin, "themes")), false)

const absent = path.join(os.tmpdir(), "nayori-strata-absent-" + process.pid)
const noConfig = run(["build", "--json", JSON.stringify(palette), "--config-dir", absent, "--strata-bin", "/bin/true"])
assert.equal(noConfig.status, 1)
assert.equal(noConfig.payload.error, "Каталог настроек Strata не найден. Тема не записана")
assert.equal(fs.existsSync(absent), false)

const home = fs.mkdtempSync(path.join(os.tmpdir(), "nayori-strata-"))
fs.writeFileSync(path.join(home, "noctalia.kdl"), "do-not-touch\n")
const settings = [
    'mode = "dark"',
    'theme = "tokyo-night"',
    "sidebar_order = [",
    '    "home",',
    "]",
    "check_for_updates = true",
    ""
].join("\n")
fs.writeFileSync(path.join(home, "settings.toml"), settings)
const first = run(["build", "--json", JSON.stringify(palette), "--config-dir", home, "--strata-bin", "/bin/true", "--strata-running", "no"])
assert.equal(first.status, 0, first.stdout + first.stderr)
assert.equal(first.payload.ok, true)
assert.equal(first.payload.changed, true)
assert.equal(first.payload.applied, true)
assert.equal(first.payload.error, "")
assert.equal(first.payload.path, path.join(home, "themes", "nayori.toml"))
const theme = fs.readFileSync(first.payload.path, "utf8")
const expected = [
    "# nayori - written by nayori (services/strata/strata_theme.py)",
    'name = "nayori"',
    'background = "#121217"',
    // Sidebar, path bar, and preview share Strata's surface key. It follows the file list.
    'surface = "#121217"',
    'muted = "#443D4E"',
    'highlight = "#80758C"',
    'border = "#443D4E"',
    'text = "#F0E9DB"',
    'dim_text = "#D5CEC4"',
    'accent = "#C0AFD1"',
    'danger = "#CAA7AA"',
    'syntax_keyword = "#C0AFD1"',
    'syntax_string = "#CAA7AA"',
    'syntax_constant = "#80758C"',
    'syntax_type = "#D5CEC4"',
    'syntax_preprocessor = "#C0AFD1"',
    ""
].join("\n")
assert.equal(theme, expected)
function field(text, key) {
    const match = text.match(new RegExp("^" + key + ' = "(#[0-9A-F]{6})"', "m"))
    assert.ok(match, key)
    return match[1]
}
function contrast(fg, bg) {
    function channel(value) {
        const c = value / 255
        return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
    }
    function luminance(hex) {
        const n = parseInt(hex.slice(1), 16)
        const r = channel((n >> 16) & 255)
        const g = channel((n >> 8) & 255)
        const b = channel(n & 255)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    const lighter = Math.max(luminance(fg), luminance(bg))
    const darker = Math.min(luminance(fg), luminance(bg))
    return (lighter + 0.05) / (darker + 0.05)
}
// One Strata key paints the sidebar, the path bar, and the preview.
assert.equal(field(theme, "surface"), "#121217")
assert.notEqual(field(theme, "surface"), "#4F4F57")
assert.notEqual(field(theme, "surface"), "#C0AFD1")
assert.ok(contrast("#F0E9DB", field(theme, "surface")) >= 4.5)
assert.ok(contrast("#D5CEC4", field(theme, "surface")) >= 4.5)
assert.equal(field(theme, "background"), "#121217")
assert.equal(field(theme, "muted"), "#443D4E")
assert.equal(field(theme, "highlight"), "#80758C")
assert.equal(field(theme, "border"), "#443D4E")
assert.equal(field(theme, "text"), "#F0E9DB")
assert.equal(field(theme, "dim_text"), "#D5CEC4")
assert.equal(field(theme, "accent"), "#C0AFD1")
assert.equal(field(theme, "danger"), "#CAA7AA")
assert.equal(field(theme, "syntax_keyword"), "#C0AFD1")
assert.equal(field(theme, "syntax_string"), "#CAA7AA")
assert.equal(field(theme, "syntax_constant"), "#80758C")
assert.equal(field(theme, "syntax_type"), "#D5CEC4")
assert.equal(field(theme, "syntax_preprocessor"), "#C0AFD1")
const saved = fs.readFileSync(path.join(home, "settings.toml"), "utf8")
assert.ok(saved.startsWith('mode = "theme"\ntheme = "nayori"\n'))
assert.ok(saved.includes('sidebar_order = [\n    "home",\n]'))
assert.ok(saved.includes("check_for_updates = true"))
assert.equal(fs.readFileSync(path.join(home, "noctalia.kdl"), "utf8"), "do-not-touch\n")
const themeTime = fs.statSync(first.payload.path).mtimeMs
const settingsTime = fs.statSync(path.join(home, "settings.toml")).mtimeMs
const again = run(["build", "--json", JSON.stringify(palette), "--config-dir", home, "--strata-bin", "/bin/true", "--strata-running", "no"])
assert.equal(again.payload.changed, false)
assert.equal(again.payload.applied, true)
assert.equal(again.payload.notice, "")
assert.equal(fs.statSync(first.payload.path).mtimeMs, themeTime)
assert.equal(fs.statSync(path.join(home, "settings.toml")).mtimeMs, settingsTime)

const openHome = fs.mkdtempSync(path.join(os.tmpdir(), "nayori-strata-open-"))
fs.writeFileSync(path.join(openHome, "settings.toml"), settings)
const pending = run(["build", "--json", JSON.stringify(palette), "--config-dir", openHome, "--strata-bin", "/bin/true", "--strata-running", "yes"])
assert.equal(pending.payload.ok, true)
assert.equal(pending.payload.applied, false)
assert.equal(pending.payload.notice, "Strata открыт, тема в\u00a0настройках не переключена. Цвета записаны в\u00a0файл темы")
assert.equal(fs.readFileSync(path.join(openHome, "settings.toml"), "utf8"), settings)
assert.equal(fs.readFileSync(path.join(openHome, "themes", "nayori.toml"), "utf8"), expected)

const bad = run(["build", "--json", '{"accent":"red"}', "--config-dir", home, "--strata-bin", "/bin/true", "--strata-running", "no"])
assert.equal(bad.status, 1)
assert.equal(bad.payload.error, "Не удалось прочитать цвета темы Strata")
assert.equal(fs.readFileSync(first.payload.path, "utf8"), expected)

console.log("STRATA_THEME_PASS")
