import QtQuick
import Quickshell
import "services/palette"
import "services/palette/PalettePick.js" as PalettePick

ShellRoot {
    id: root
    property int stage: 0
    property int ticks: 0
    property int hold: 0
    property string heldId: ""
    function check(ok, reason) { if (!ok) throw new Error(reason) }
    function fixture(name) {
        let dir = String(Quickshell.env("NAYORI_PALETTE_FIXTURES") || "")
        if (dir === "") dir = Quickshell.workingDirectory + "/tests/fixtures/palette"
        if (dir.charAt(dir.length - 1) === "/") dir = dir.slice(0, -1)
        return "file://" + dir + "/" + name
    }
    function hex(value) {
        const text = String(value || "").toUpperCase()
        return text.length === 9 && text.charAt(0) === "#" ? "#" + text.slice(3) : text
    }
    function named(name) {
        return accents.sourcePath.length >= name.length + 1 && accents.sourcePath.slice(-(name.length + 1)) === "/" + name
    }
    function settled(name) { return accents.ready && root.named(name) }
    function candidateColors() {
        const colors = []
        for (let i = 0; i < accents.candidates.length; i++) colors.push(accents.candidates[i].color)
        return colors
    }
    function ink(color) { return PalettePick.contrast(root.hex(color), "#F0E9DB") }
    function neutralLab(color) { return PalettePick.measure(root.hex(color)) }
    function hueDistance(a, b) {
        const delta = Math.abs(a - b)
        return Math.min(delta, 360 - delta)
    }
    function expectDerived(hue, label) {
        root.check(!accents.neutralFallbackUsed, label + " derived")
        root.check(root.ink(accents.background) >= 4.5, label + " bg contrast " + root.ink(accents.background))
        root.check(root.ink(accents.surfaceAlt) >= 4.5, label + " alt contrast " + root.ink(accents.surfaceAlt))
        root.check(root.hex(accents.background) !== root.hex(accents.accent), label + " bg is not accent " + accents.background)
        const bg = root.neutralLab(accents.background)
        root.check(bg.L < 0.4 && bg.C < 0.05, label + " graphite " + accents.background + " L " + bg.L + " C " + bg.C)
        if (hue !== null) {
            const distance = root.hueDistance(bg.H, hue)
            root.check(bg.C < 0.004 || distance < 25, label + " hue " + bg.H + " vs " + hue)
        }
    }
    function expectAuthored(label) {
        root.check(accents.neutralFallbackUsed, label + " neutral fallback")
        root.check(root.hex(accents.background) === "#121217", label + " bg " + accents.background)
        root.check(root.hex(accents.surface) === "#4F4F57", label + " surface " + accents.surface)
        root.check(root.hex(accents.surfaceAlt) === "#443D4E", label + " alt " + accents.surfaceAlt)
    }
    AccentExtractor { id: accents }
    Timer {
        interval: 30
        running: true
        repeat: true
        onTriggered: {
            try {
                root.ticks++
                root.check(root.ticks < 400, "timeout at stage " + root.stage + " path " + accents.sourcePath + " error " + accents.error)
                if (root.stage === 0) {
                    const sample = PalettePick.rank([
                        { color: "#121217", share: 0.7 },
                        { color: "#FF0000", share: 0.2, alpha: 0 },
                        { color: "#C4A8E0", share: 0.3 }
                    ])
                    root.check(sample.accent === "#C4A8E0" && sample.fallbackUsed === false, "qml rank")
                    root.check(sample.background === "#121217" && sample.neutralFallbackUsed === false, "qml rank neutral")
                    root.check(PalettePick.contrast(sample.background, "#F0E9DB") >= 4.5, "qml rank contrast")
                    const gray = PalettePick.rank([{ color: "#808080", share: 1 }])
                    root.check(gray.accent === "#C0AFD1" && gray.neutralFallbackUsed === false, "qml gray neutral")
                    root.check(PalettePick.contrast(gray.background, "#F0E9DB") >= 4.5 && gray.background !== "#121217", "qml gray graphite")
                    const white = PalettePick.rank([{ color: "#FFFFFF", share: 1 }])
                    root.check(white.neutralFallbackUsed === true && white.background === "#121217" && white.surfaceAlt === "#443D4E", "qml white fallback")
                    accents.source = root.fixture("lavender-dark.png")
                    root.stage = 1
                } else if (root.stage === 1) {
                    if (!root.settled("lavender-dark.png") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#C4A8E0", "lavender " + accents.accent + " " + JSON.stringify(accents.candidates))
                    root.expectDerived(286, "lavender")
                    root.check(accents.error === "" && !accents.fallbackUsed && accents.ready, "lavender flags")
                    root.check(accents.candidates[0].color === "#C4A8E0" && accents.candidates[0].share === 0.25, "lavender share")
                    root.check(accents.contentId === accents.sourcePath + ":" + accents.sourceMtime + ":" + accents.contentId.split(":").pop(), "contentId")
                    root.check(/^\d+$/.test(accents.sourceMtime) && accents.sourceMtime !== "", "mtime")
                    root.heldId = accents.contentId
                    accents.reload()
                    root.hold = root.ticks
                    root.stage = 2
                } else if (root.stage === 2) {
                    root.check(root.hex(accents.accent) === "#C4A8E0" && accents.error === "" && accents.contentId === root.heldId && accents.ready, "reload")
                    if (root.ticks - root.hold < 4) return
                    accents.source = root.fixture("black.png")
                    root.stage = 3
                } else if (root.stage === 3) {
                    if (!root.settled("black.png") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#C0AFD1" && accents.fallbackUsed && accents.error === "", "black")
                    root.expectDerived(null, "black")
                    root.check(root.neutralLab(accents.background).L < 0.08, "black graphite " + accents.background)
                    accents.source = root.fixture("white.png")
                    root.stage = 4
                } else if (root.stage === 4) {
                    if (!root.settled("white.png") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#C0AFD1" && accents.fallbackUsed && accents.error === "", "white")
                    root.expectAuthored("white")
                    accents.source = root.fixture("gray.png")
                    root.stage = 5
                } else if (root.stage === 5) {
                    if (!root.settled("gray.png") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#C0AFD1" && accents.fallbackUsed && accents.error === "", "gray")
                    root.expectDerived(null, "gray")
                    root.check(root.hex(accents.background) !== "#808080" && root.neutralLab(accents.background).C < 0.02, "gray graphite " + accents.background)
                    accents.source = root.fixture("red.png")
                    root.stage = 6
                } else if (root.stage === 6) {
                    if (!root.settled("red.png") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#FF0000" && !accents.fallbackUsed && accents.error === "", "red " + JSON.stringify(accents.candidates))
                    root.expectDerived(29, "red")
                    accents.source = root.fixture("green.png")
                    root.stage = 7
                } else if (root.stage === 7) {
                    if (!root.settled("green.png") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#00FF00" && !accents.fallbackUsed, "green " + accents.accent)
                    root.expectDerived(142, "green")
                    accents.source = root.fixture("blue.png")
                    root.stage = 8
                } else if (root.stage === 8) {
                    if (!root.settled("blue.png") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#0000FF" && !accents.fallbackUsed, "blue " + accents.accent)
                    root.expectDerived(264, "blue")
                    accents.source = root.fixture("competing.png")
                    root.stage = 9
                } else if (root.stage === 9) {
                    if (!root.settled("competing.png") || accents.contentId === "") return
                    const colors = root.candidateColors()
                    root.check(colors[0] === "#C4A8E0" && colors.indexOf("#FF0000") >= 0 && colors.indexOf("#101014") < 0, "competing " + JSON.stringify(accents.candidates))
                    root.check(accents.candidates[0].share === 0.25 && accents.candidates[1].share === 0.25, "competing shares")
                    root.check(!accents.fallbackUsed && accents.error === "", "competing flags")
                    root.expectDerived(286, "competing")
                    root.check(root.hex(accents.background) !== "#C4A8E0" && root.hex(accents.background) !== "#FF0000", "competing neutral " + accents.background)
                    accents.source = root.fixture("transparent.png")
                    root.stage = 10
                } else if (root.stage === 10) {
                    if (!root.settled("transparent.png") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#C4A8E0" && root.candidateColors().indexOf("#FF0000") < 0, "transparent " + JSON.stringify(accents.candidates))
                    root.check(accents.candidates.length === 1 && accents.candidates[0].share === 1, "transparent share")
                    accents.source = root.fixture("clear.png")
                    root.stage = 11
                } else if (root.stage === 11) {
                    if (!root.settled("clear.png") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#C0AFD1" && accents.fallbackUsed && accents.error === "Не удалось прочитать цвета обоев.", "clear " + accents.error)
                    root.expectAuthored("clear")
                    accents.source = root.fixture("corrupt.png")
                    root.stage = 12
                } else if (root.stage === 12) {
                    if (!root.settled("corrupt.png") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#C0AFD1" && accents.fallbackUsed && accents.error === "Не удалось прочитать цвета обоев.", "corrupt " + accents.error)
                    root.expectAuthored("corrupt")
                    accents.source = root.fixture("missing.png")
                    root.stage = 13
                } else if (root.stage === 13) {
                    if (!root.settled("missing.png")) return
                    root.check(accents.error === "Файл обоев не найден." && accents.contentId === "" && accents.sourceMtime === "", "missing " + accents.error)
                    root.check(root.hex(accents.accent) === "#C0AFD1" && accents.fallbackUsed, "missing accent")
                    root.expectAuthored("missing")
                    accents.source = root.fixture("picture.bmp")
                    root.stage = 14
                } else if (root.stage === 14) {
                    if (!root.settled("picture.bmp")) return
                    root.check(accents.error === "Формат изображения не поддерживается." && accents.contentId === "" && root.hex(accents.accent) === "#C0AFD1", "bmp " + accents.error)
                    root.expectAuthored("bmp")
                    accents.source = root.fixture("broken.jpg")
                    root.stage = 15
                } else if (root.stage === 15) {
                    if (!root.settled("broken.jpg") || accents.contentId === "") return
                    root.check(accents.error === "Не удалось прочитать цвета обоев." && root.hex(accents.accent) === "#C0AFD1" && accents.fallbackUsed, "broken jpg " + accents.error)
                    root.expectAuthored("broken jpg")
                    accents.source = root.fixture("RED.PNG")
                    root.stage = 16
                } else if (root.stage === 16) {
                    if (!root.settled("RED.PNG") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#FF0000" && accents.error === "", "upper png " + accents.accent)
                    accents.source = root.fixture("flat.jpg")
                    root.stage = 17
                } else if (root.stage === 17) {
                    if (!root.settled("flat.jpg") || accents.contentId === "") return
                    // JPEG YCbCr stores pure red as #FE0000. The suffix is accepted and the decoded color is used.
                    root.check(root.hex(accents.accent) === "#FE0000" && accents.error === "" && !accents.fallbackUsed, "jpg " + accents.accent + " " + JSON.stringify(accents.candidates))
                    accents.source = root.fixture("flat.jpeg")
                    root.stage = 18
                } else if (root.stage === 18) {
                    if (!root.settled("flat.jpeg") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#5C8A87" && !accents.fallbackUsed, "jpeg " + accents.accent + " " + JSON.stringify(accents.candidates))
                    accents.source = root.fixture("flat.webp")
                    root.stage = 19
                } else if (root.stage === 19) {
                    if (!root.settled("flat.webp") || accents.contentId === "") return
                    // Lossy WebP splits one lavender into a few neighboring buckets. Prevalence picks the largest.
                    root.check(root.hex(accents.accent) === "#C4A8E1" && accents.candidates[0].share === 0.75 && !accents.fallbackUsed, "webp " + accents.accent + " " + JSON.stringify(accents.candidates))
                    accents.source = root.fixture("lavender-dark.png")
                    accents.source = root.fixture("red.png")
                    accents.source = root.fixture("blue.png")
                    root.stage = 20
                } else if (root.stage === 20) {
                    if (!root.settled("blue.png") || accents.contentId === "") return
                    root.check(root.hex(accents.accent) === "#0000FF" && accents.error === "", "stale " + accents.accent + " " + accents.sourcePath)
                    console.log("ACCENT_EXTRACTOR_PASS")
                    Qt.quit()
                }
            } catch (error) {
                console.error("ACCENT_EXTRACTOR_FAIL", error)
                Qt.exit(1)
            }
        }
    }
}
