"""Isolated clipboard tests: never read or overwrite the user's clipboard."""
import importlib.util
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "services/clipboard/clipboard_store.py"
spec = importlib.util.spec_from_file_location("clipboard_store", WORKER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory(prefix="nayori-clipboard-tests-") as temporary:
    directory = Path(temporary)
    store = module.Store(directory / "store")
    assert store.add("text", "Первая строка\nВторая строка\n".encode())
    first = store.records()[0]
    assert first["text"] == "Первая строка\nВторая строка\n"
    assert not store.add("text", "Первая строка\nВторая строка\n".encode())
    assert not store.add("text", b"\xff\xfe\x00")
    assert not store.add("image", b"not an image")
    assert not store.add("text", b"x" * (module.MAX_TEXT_BYTES + 1))
    assert not store.add("text", b" \n ")
    data = (ROOT / "assets/branding/nayori-fox-logo.png").read_bytes()
    assert store.add("image", data)
    image = store.records()[0]
    assert image["width"] > 0 and image["height"] > 0
    preview = Path(image["image"].removeprefix("file://"))
    assert preview.read_bytes() == data
    assert preview.stat().st_mode & 0o777 == 0o600
    store.pin(image["id"])
    assert store.records()[0]["pinned"]
    assert store.add("text", b"Other text")
    assert store.add("image", data)
    assert store.records()[0]["id"] == image["id"]
    assert store.records()[0]["pinned"]
    module.MAX_ENTRIES = 4
    for i in range(12):
        assert store.add("text", ("Entry %d" % i).encode())
    assert len(store.records()) == 4
    assert any(record["id"] == image["id"] for record in store.records())
    module.MAX_TOTAL_BYTES = len(data) + 32
    store.add("text", b"A" * 64)
    assert sum(record["bytes"] for record in store.records()) <= module.MAX_TOTAL_BYTES
    store.db.close()
    store = module.Store(directory / "store")
    assert store.payload(image["id"]) == ("image/png", data)
    assert any(record["pinned"] for record in store.records())
    store.remove(image["id"])
    assert not preview.exists()
    assert store.payload(image["id"]) is None
    module.MAX_ENTRIES = 100
    module.MAX_TOTAL_BYTES = 64 * 1024 * 1024
    image_file = directory / "Иллюстрация с пробелом.png"
    image_file.write_bytes(data)
    uri = (image_file.as_uri() + "\r\n").encode()
    assert store.add("text", uri)
    copied_file = store.records()[0]
    assert copied_file["kind"] == "image"
    assert copied_file["title"] == image_file.name
    assert copied_file["width"] > 0 and copied_file["height"] > 0
    assert copied_file["bytes"] == len(data)
    assert store.payload(copied_file["id"]) == ("text/uri-list", uri)
    assert store.add("text", b"http://[broken")
    if module.shutil.which("ffmpeg") and module.shutil.which("ffprobe"):
        video = directory / "video.avi"
        subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=black:s=320x180:d=0.1",
                        "-c:v", "mpeg4", "-y", str(video)], check=True, capture_output=True)
        assert store.add("text", video.as_uri().encode())
        record = store.records()[0]
        assert record["kind"] == "video"
        assert (record["width"], record["height"]) == (320, 180)
        assert record["image"].endswith(".preview.jpg")
    store.clear()
    assert store.records() == []
    store.db.close()

    # Exercise the complete JSON-line / socket / binary copy path with a fake
    # wl-copy executable. The real Wayland session is intentionally inaccessible.
    binary = directory / "bin"
    binary.mkdir()
    copy = binary / "wl-copy"
    copy.write_text("#!/usr/bin/env python3\nimport os,sys,pathlib\n"
                    "if '--clear' in sys.argv: sys.exit(0)\n"
                    "pathlib.Path(os.environ['CLIP_TEST_COPY']).write_bytes(sys.stdin.buffer.read())\n"
                    "pathlib.Path(os.environ['CLIP_TEST_MIME']).write_text(sys.argv[2])\n")
    copy.chmod(0o700)
    paste = binary / "wl-paste"
    paste.write_text("#!/bin/sh\nexit 1\n")
    paste.chmod(0o700)
    env = dict(os.environ, PATH=str(binary) + ":" + os.environ["PATH"],
               XDG_RUNTIME_DIR=temporary, WAYLAND_DISPLAY="no-such-wayland",
               CLIP_TEST_COPY=str(directory / "copied"), CLIP_TEST_MIME=str(directory / "mime"))
    process = subprocess.Popen([sys.executable, "-u", str(WORKER), "--no-watch", "--directory", str(directory / "daemon")],
                               env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    buffer = bytearray()
    def event(kind):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            while b"\n" in buffer:
                line, _, rest = buffer.partition(b"\n")
                buffer[:] = rest
                message = json.loads(line)
                if message["event"] == kind:
                    return message
            if selector.select(0.2):
                chunk = os.read(process.stdout.fileno(), 65536)
                if not chunk:
                    raise AssertionError(process.stderr.read().decode())
                buffer.extend(chunk)
        raise AssertionError("No worker event: " + kind)
    def send(action, identity=""):
        process.stdin.write(json.dumps(dict(action=action, id=identity)).encode() + b"\n")
        process.stdin.flush()
    try:
        socket_path = event("capture")["socket"]
        assert event("history")["ready"]
        for kind, payload in [("text", b"printf '$HOME `literal`'\n"), ("image", data)]:
            capture = subprocess.run([sys.executable, str(WORKER), "capture", socket_path, kind],
                                     input=payload, env=env, capture_output=True, timeout=5)
            assert capture.returncode == 0, capture.stderr
            records = event("history")["records"]
            identity = records[0]["id"]
            assert records[0]["kind"] == kind
            send("copy", identity)
            assert event("copied")["id"] == identity
            assert (directory / "copied").read_bytes() == payload
            assert (directory / "mime").read_text().startswith("image/" if kind == "image" else "text/plain")
        subprocess.run([sys.executable, str(WORKER), "capture", socket_path, "text"],
                       input=b"secret", env=dict(env, CLIPBOARD_STATE="sensitive"), check=True)
        send("list")
        assert len(event("history")["records"]) == 2
        send("pin", identity)
        assert event("history")["records"][0]["pinned"]
        send("remove", identity)
        assert len(event("history")["records"]) == 1
        send("copy", identity)
        assert "error" in event("error")
        send("paste")
        assert event("paste-unavailable")["error"]
        send("clear")
        assert event("history")["records"] == []
        send("stop")
        assert process.wait(timeout=5) == 0, process.stderr.read().decode()
        assert not Path(socket_path).exists()
    finally:
        selector.close()
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
print("CLIPBOARD_STORE_TESTS_PASS")
