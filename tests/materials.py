"""Exercise live native blur requests on a dedicated window; no compositor rules are changed."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-materials-") as runtime:
    display = os.environ["WAYLAND_DISPLAY"]
    if not display.startswith("/"):
        display = str(Path(os.environ["XDG_RUNTIME_DIR"]) / display)
    env = dict(os.environ, XDG_RUNTIME_DIR=runtime, WAYLAND_DISPLAY=display, WAYLAND_DEBUG="client",
               QT_QPA_PLATFORM="wayland", QT_QPA_PLATFORMTHEME="basic", QT_QUICK_BACKEND="software")
    result = subprocess.run(["qs", "-p", str(root / "MaterialsSmoke.qml"), "--no-color"],
                            env=env, text=True, capture_output=True, timeout=10)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "MATERIALS_PASS" in output, output[-12000:]
    assert not any(error in output for error in ["MATERIALS_FAIL", "TypeError:", "ReferenceError:", "Failed to load", "Unable to assign"]), output[-12000:]
    protocol = [line for line in output.splitlines() if "set_blur_region" in line]
    assert any("wl_region" in line for line in protocol), protocol
    assert any("nil" in line or "null" in line for line in protocol), protocol
    print("PASS native ext-background-effect region enabled and cleared")
    print("PASS distinct material densities, opaque text, Solid round trip")
print("MATERIALS_TESTS_PASS")
