"""Exercise the real shell-owned service without network access or any views."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-weather-") as directory:
    base = Path(directory)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    fake = base / "request.py"
    fake.write_text('''import fcntl, json, sys, time
from pathlib import Path
log = Path(sys.argv[1])
mode = sys.argv[2]
lock = open(str(log) + ".lock", "w")
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    with log.open("a") as out: out.write("OVERLAP\\n")
    sys.exit(3)
with log.open("a") as out: out.write(mode + "\\n")
time.sleep(0.2 if mode == "slow" else 0.025)
if mode == "fail": sys.exit(2)
print(json.dumps({"current_condition": [{"temp_C": "oops" if mode == "bad" else "18", "FeelsLikeC": "17", "weatherCode": "113", "city": mode}]}))
''')
    log = base / "requests.log"
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen",
               QT_QPA_PLATFORMTHEME="basic", QT_QUICK_BACKEND="software",
               NAYORI_WEATHER_FAKE=str(fake), NAYORI_WEATHER_LOG=str(log))
    result = subprocess.run(["qs", "-p", str(root / "WeatherServiceSmoke.qml"), "--no-color"],
                            env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "WEATHER_SERVICE_PASS" in output, output
    assert not any(s in output for s in ["ReferenceError", "TypeError", "Unable to assign", "Failed to load", "WEATHER_SERVICE_FAIL"]), output
    calls = log.read_text().splitlines()
    assert "OVERLAP" not in calls and calls.count("slow") == 1 and calls.count("latest") == 1, calls
    assert "disabled" not in calls and "" not in calls and calls.count("valid") >= 2, calls
    assert calls.count("bad") == 1 and calls.count("fail") == 1, calls
print("WEATHER_SERVICE_TESTS_PASS")
