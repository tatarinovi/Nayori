const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')

const root = path.join(__dirname, '..')
const shell = fs.readFileSync(path.join(root, 'shell.qml'), 'utf8')
const session = fs.readFileSync(path.join(root, 'surfaces/ShellSession.qml'), 'utf8')

// The loader URL is invisible to Quickshell's import scanner. Register its
// containing directory so the scanner follows the session's own imports.
function registersSession(source) {
    return /^\s*import\s+["']surfaces["'](?:\s|$)/m.test(source)
}
assert.match(shell, /Qt\.resolvedUrl\(["']surfaces\/ShellSession\.qml["']\)/)
assert.ok(registersSession(shell), 'bootstrap must register the session with the QML scanner')
assert.equal(registersSession(shell.replace(/^\s*import\s+["']surfaces["'].*$/m, '')), false)
assert.match(session, /^\s*import\s+["']\.\.\/services\/shelf["']/m)
console.log('STARTUP_IMPORTS_PASS')
