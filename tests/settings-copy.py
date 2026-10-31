"""Check settings copy, visit keys, script sections and niri accent error wiring."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]

shell = (root / "shell.qml").read_text()
status_start = shell.index("readonly property string accentStatus")
status_end = shell.index("readonly property string niriAccentError")
accent_status = shell[status_start:status_end]
assert "niriAccent" not in accent_status and "niriError" not in accent_status, accent_status
assert "accentExtractor.error" in accent_status
assert "niriAccentError: niriAccent.error" in shell
for relative in (
    "surfaces/settings/SettingsController.qml",
    "surfaces/settings/SettingsWindow.qml",
    "surfaces/settings/Settings.qml",
):
    text = (root / relative).read_text()
    assert "niriAccentError: root.niriAccentError" in text, relative
assert 'objectName: "niriAccentError"' in (root / "surfaces/settings/IntegrationsPage.qml").read_text()

controller = (root / "surfaces/settings/SettingsController.qml").read_text()
block = re.search(r"pageIndexes:\s*\(\{(.*?)\}\)", controller, re.S)
assert block, "pageIndexes"
controller_keys = set(re.findall(r"""["']?([A-Za-z][A-Za-z0-9-]*)["']?\s*:""", block.group(1)))
script = (root / "scripts/nayori-settings").read_text()
case = re.search(r'case "\$page" in\n\s*(.*?)\s*\)\s*;;', script, re.S)
assert case, "settings case"
script_keys = set()
for part in case.group(1).split("|"):
    part = part.strip().strip('"').strip("'")
    if part and part != "*":
        script_keys.add(part)
assert script_keys == controller_keys, sorted(script_keys ^ controller_keys)
for key in ("integrations", "naomi", "naomi-look", "naomi-place", "naomi-remind"):
    assert key in script_keys

def run_page(page):
    env = dict(os.environ)
    env.pop("XDG_RUNTIME_DIR", None)
    return subprocess.run(
        [str(root / "scripts/nayori-settings"), "--page", page],
        env=env, capture_output=True, text=True, timeout=5,
    )

unknown = run_page("not-a-section")
assert unknown.returncode == 2 and "Unknown settings section" in unknown.stderr, unknown.stderr
for key in sorted(script_keys):
    known = run_page(key)
    assert known.returncode != 2, key
    assert "Unknown settings section" not in known.stderr, known.stderr
    assert "XDG_RUNTIME_DIR" in known.stderr, known.stderr

with tempfile.TemporaryDirectory(prefix="nayori-copy-") as directory:
    config_home = Path(directory) / "config"
    (config_home / "niri").mkdir(parents=True)
    niri_config = config_home / "niri" / "config.kdl"
    niri_config.write_text("// isolated settings copy check\n")
    env = dict(
        os.environ,
        QT_QPA_PLATFORM="offscreen",
        QT_QPA_PLATFORMTHEME="basic",
        QT_QUICK_BACKEND="software",
        QS_DISABLE_FILE_WATCHER="1",
        XDG_RUNTIME_DIR=directory,
        XDG_CONFIG_HOME=str(config_home),
        NIRI_CONFIG=str(niri_config),
    )
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(
        ["qs", "-p", str(root / "tests/smoke/SettingsCopySmoke.qml"), "--no-color"],
        env=env, capture_output=True, text=True, timeout=25,
    )
output = result.stdout + result.stderr
assert result.returncode == 0 and "COPY_PASS" in output, output
assert not any(token in output for token in (
    "COPY_FAIL", "ReferenceError", "TypeError", "Unable to assign", "Failed to load", "Binding loop",
)), output
print("PASS settings copy, script keys and niri accent error")
