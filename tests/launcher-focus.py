"""Лаунчер сразу получает клавиатуру при открытии (Alt+Space, IPC, кнопка).

Статическая часть работает всегда: окно острова держит `focusable` постоянным.
Смена `focusable` одновременно с `keyboardFocus` заставляла Quickshell отправить
OnDemand поверх Exclusive, и niri отдавал фокус только по наведению мыши.

Живая часть (NAYORI_NESTED_NIRI=1) поднимает вложенный niri в отдельном XDG_RUNTIME_DIR,
запускает настоящую оболочку с изолированными HOME и D-Bus и по протоколу проверяет:
после `launcher toggle` остров просит Exclusive и получает wl_keyboard.enter без движения
курсора, после закрытия получает leave. Во вложенном окне на экране это занимает секунд 30.
"""
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[1]

# --- статическая защита от возврата бага -------------------------------------------------
panels = (root / "surfaces/panel/ScreenPanels.qml").read_text(encoding="utf-8")
start = panels.index("id: islandWindow")
block = panels[start:panels.index('WlrLayershell.namespace: "nayori-island"', start) + 400]
focusable = re.search(r"^\s*focusable:\s*(.+)$", block, re.M)
assert focusable and focusable.group(1).strip() == "true", \
    "focusable окна острова должен быть постоянным true: " + (focusable.group(1) if focusable else "нет")
keyboard = re.search(r"WlrLayershell\.keyboardFocus:\s*root\.launcherHere\s*\?\s*WlrKeyboardFocus\.Exclusive", block)
assert keyboard, "при открытом лаунчере окно острова должно просить Exclusive"
print("LAUNCHER_FOCUS_STATIC_PASS")

if os.environ.get("NAYORI_NESTED_NIRI") != "1":
    print("LAUNCHER_FOCUS_LIVE_SKIP (NAYORI_NESTED_NIRI=1 включает вложенный niri)")
    print("LAUNCHER_FOCUS_TESTS_PASS")
    raise SystemExit(0)

host = os.environ.get("WAYLAND_DISPLAY", "")
host_runtime = os.environ.get("XDG_RUNTIME_DIR", "")
if host and not host.startswith("/"):
    host = str(Path(host_runtime) / host)
if not host or not Path(host).exists() or not shutil.which("niri") or not shutil.which("qs"):
    print("LAUNCHER_FOCUS_LIVE_SKIP (нужны Wayland-сессия, niri и qs)")
    print("LAUNCHER_FOCUS_TESTS_PASS")
    raise SystemExit(0)

tmp = Path(tempfile.mkdtemp(prefix="nayori-focus-"))
runtime = tmp / "rt"
home = tmp / "home"
runtime.mkdir(mode=0o700)
(home / ".config/nayori").mkdir(parents=True)
(home / ".config/nayori/settings.json").write_text('{"version":1}', encoding="utf-8")
(tmp / "niri.kdl").write_text('input {\n    keyboard {\n        xkb {\n            layout "us"\n        }\n    }\n}\n',
                              encoding="utf-8")
env = {key: value for key, value in os.environ.items()
       if key not in ("NIRI_SOCKET", "DISPLAY", "WAYLAND_DEBUG")}
env.update(HOME=str(home), XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(home / ".config"),
           XDG_STATE_HOME=str(home / ".local/state"), XDG_CACHE_HOME=str(home / ".cache"),
           XDG_DATA_HOME=str(home / ".local/share"), QT_QPA_PLATFORMTHEME="basic",
           QS_DISABLE_FILE_WATCHER="1", DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(tmp / "no-bus"))
niri = shell = None
log = tmp / "shell.log"


def wait_for(predicate, timeout, what):
    deadline = time.time() + timeout
    while time.time() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.1)
    raise AssertionError("не дождались: " + what)


def log_text():
    return log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""


def ipc(*args):
    done = subprocess.run(["qs", "ipc", "-p", str(root), *args], env=dict(env, WAYLAND_DISPLAY="wayland-1"),
                          text=True, capture_output=True, timeout=10)
    assert done.returncode == 0, done.stdout + done.stderr


try:
    niri = subprocess.Popen(["niri", "-c", str(tmp / "niri.kdl")], env=dict(env, WAYLAND_DISPLAY=host),
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    wait_for(lambda: (runtime / "wayland-1").exists() and list(runtime.glob("niri.*.sock")), 20, "вложенный niri")
    nested = dict(env, WAYLAND_DISPLAY="wayland-1", QT_QPA_PLATFORM="wayland", WAYLAND_DEBUG="client",
                  NIRI_SOCKET=str(next(runtime.glob("niri.*.sock"))))
    with log.open("w", encoding="utf-8") as sink:
        shell = subprocess.Popen(["qs", "-p", str(root), "--no-color"], env=nested, stdout=sink,
                                 stderr=subprocess.STDOUT, start_new_session=True)
    island_ids = wait_for(lambda: re.search(
        r"get_layer_surface\(new id (zwlr_layer_surface_v1#\d+), (wl_surface#\d+), [^)]*\"nayori-island\"\)",
        log_text()), 40, "окно острова")
    layer, surface = island_ids.group(1), island_ids.group(2)
    time.sleep(2)

    for attempt in range(1, 4):
        mark = len(log_text())
        ipc("call", "launcher", "toggle")
        wait_for(lambda: re.search(r"wl_keyboard#\d+\.enter\(\d+, " + surface + ",", log_text()[mark:]), 15,
                 "wl_keyboard.enter при открытии, попытка %d" % attempt)
        opened = log_text()[mark:]
        requests = re.findall(re.escape(layer) + r"\.set_keyboard_interactivity\((\d)\)", opened)
        assert "1" in requests and "2" not in requests, "ожидали Exclusive без OnDemand: %r" % requests
        assert opened.index("set_keyboard_interactivity(1)") < opened.index("wl_keyboard"), "enter раньше запроса"
        mark = len(log_text())
        ipc("call", "launcher", "toggle")
        wait_for(lambda: re.search(r"wl_keyboard#\d+\.leave\(\d+, " + surface + r"\)", log_text()[mark:]), 15,
                 "wl_keyboard.leave при закрытии, попытка %d" % attempt)
    print("LAUNCHER_FOCUS_LIVE_PASS")
    print("LAUNCHER_FOCUS_TESTS_PASS")
finally:
    for process in (shell, niri):
        if process and process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
    shutil.rmtree(tmp, ignore_errors=True)
