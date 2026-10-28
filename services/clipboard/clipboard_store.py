"""Bounded Wayland clipboard history. Only wl-clipboard and the Python stdlib.

The two wl-paste watches stream payloads to short-lived capture helpers. QML
talks JSON lines over stdin/stdout; binary clipboard data never passes through
QML or a shell command. Original bytes are retained for lossless copying.
"""
import argparse
import base64
import asyncio
import contextlib
import fcntl
import hashlib
import json
import mimetypes
import os
from pathlib import Path
import shutil
import signal
import socket
import sqlite3
import struct
import subprocess
import sys
import tempfile
import time
from urllib.parse import unquote, urlsplit

MAX_ITEM_BYTES = 16 * 1024 * 1024
MAX_TEXT_BYTES = 1024 * 1024
MAX_ENTRIES = 100
MAX_TOTAL_BYTES = 64 * 1024 * 1024
PREVIEW_CHARS = 16000


def image_format(data):
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png", "png"
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg", "jpg"
    if data.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif", "gif"
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "image/webp", "webp"
    if data.startswith(b"BM"):
        return "image/bmp", "bmp"
    if data.startswith((b"II\x2a\x00", b"MM\x00\x2a")):
        return "image/tiff", "tiff"
    return None


def dimensions(data=b"", path=None):
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24:
        return struct.unpack(">II", data[16:24])
    if data.startswith((b"GIF87a", b"GIF89a")) and len(data) >= 10:
        return struct.unpack("<HH", data[6:10])
    if not shutil.which("ffprobe"):
        return 0, 0
    command = ["ffprobe", "-v", "error", "-protocol_whitelist", "file,pipe", "-select_streams", "v:0",
               "-show_entries", "stream=width,height", "-of", "json", "-i", str(path) if path else "pipe:0"]
    try:
        result = subprocess.run(command, input=None if path else data, capture_output=True, timeout=2)
        streams = json.loads(result.stdout).get("streams", [])
        if streams:
            return max(0, int(streams[0].get("width", 0))), max(0, int(streams[0].get("height", 0)))
    except (ValueError, OSError, subprocess.TimeoutExpired):
        pass
    return 0, 0


def local_files(text):
    lines = [line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")]
    if not lines:
        return []
    paths = []
    for line in lines:
        try:
            value = urlsplit(line)
        except ValueError:
            return []
        if value.scheme != "file" or value.netloc not in ("", "localhost") or value.query or value.fragment:
            return []
        path = Path(unquote(value.path))
        if not path.is_absolute():
            return []
        paths.append(path)
    return paths


class Store:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.directory.chmod(0o700)
        self.db = sqlite3.connect(self.directory / "history.sqlite3")
        self.db.execute("""CREATE TABLE IF NOT EXISTS entries (
            id TEXT PRIMARY KEY, kind TEXT NOT NULL, mime TEXT NOT NULL,
            data BLOB NOT NULL, title TEXT NOT NULL, preview TEXT NOT NULL,
            created REAL NOT NULL, pinned INTEGER NOT NULL DEFAULT 0,
            extension TEXT NOT NULL DEFAULT '')""")
        columns = {column[1] for column in self.db.execute("PRAGMA table_info(entries)")}
        for name, definition in [("width", "INTEGER NOT NULL DEFAULT 0"), ("height", "INTEGER NOT NULL DEFAULT 0"),
                                 ("media_path", "TEXT NOT NULL DEFAULT ''"), ("media_bytes", "INTEGER NOT NULL DEFAULT 0")]:
            if name not in columns:
                self.db.execute("ALTER TABLE entries ADD COLUMN " + name + " " + definition)
        # Upgrade existing image entries once, so already-copied pictures also
        # gain dimensions after a shell reload.
        for identity, data in self.db.execute("SELECT id,data FROM entries WHERE kind='image' AND width=0 AND media_path=''").fetchall():
            width, height = dimensions(data)
            self.db.execute("UPDATE entries SET width=?,height=? WHERE id=?", (width, height, identity))
        (self.directory / "history.sqlite3").chmod(0o600)
        self.db.commit()
        self.cleanup_images()

    def cleanup_images(self):
        ids = {row[0] for row in self.db.execute("SELECT id FROM entries WHERE kind IN ('image','video')")}
        for path in self.directory.glob("*.preview.*"):
            if path.name.split(".")[0] not in ids:
                path.unlink(missing_ok=True)

    def add(self, kind, data):
        if not data or len(data) > MAX_ITEM_BYTES:
            return False
        extension, preview, media_path = "", "", ""
        width, height, media_bytes = 0, 0, 0
        if kind == "image":
            fmt = image_format(data)
            if not fmt:
                return False
            mime, extension = fmt
            title = "Изображение " + extension.upper()
            width, height = dimensions(data)
        elif kind == "text":
            if len(data) > MAX_TEXT_BYTES or b"\x00" in data:
                return False
            try:
                text = data.decode("utf-8")
            except UnicodeDecodeError:
                return False
            if not text.strip():
                return False
            mime = "text/plain;charset=utf-8"
            preview = text[:PREVIEW_CHARS]
            title = " ".join(text.split())[:120]
            files = local_files(text)
            if files:
                mime, kind = "text/uri-list", "file"
                title = files[0].name + (" и еще " + str(len(files) - 1) if len(files) > 1 else "")
                if len(files) == 1 and files[0].is_file():
                    path = files[0]
                    media_bytes = path.stat().st_size
                    media_mime = mimetypes.guess_type(path)[0] or ""
                    if media_mime.startswith(("image/", "video/")):
                        kind = "video" if media_mime.startswith("video/") else "image"
                        media_path = str(path)
                        extension = path.suffix.lstrip(".").lower()
                        width, height = dimensions(path=path)
        else:
            return False
        identity = hashlib.sha256(mime.encode() + b"\x00" + data).hexdigest()
        previous = self.db.execute("SELECT id FROM entries ORDER BY created DESC LIMIT 1").fetchone()
        if previous and previous[0] == identity:
            return False
        with self.db:
            self.db.execute("""INSERT INTO entries(id,kind,mime,data,title,preview,created,extension,width,height,media_path,media_bytes)
                VALUES(?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET created=excluded.created,
                width=excluded.width,height=excluded.height,media_bytes=excluded.media_bytes""",
                (identity, kind, mime, data, title, preview, time.time(), extension, width, height, media_path, media_bytes))
            count, size = self.db.execute("SELECT count(*),coalesce(sum(length(data)),0) FROM entries").fetchone()
            while count > MAX_ENTRIES or size > MAX_TOTAL_BYTES:
                victim = self.db.execute("SELECT id,length(data) FROM entries WHERE pinned=0 ORDER BY created LIMIT 1").fetchone()
                if not victim:
                    break
                self.db.execute("DELETE FROM entries WHERE id=?", (victim[0],))
                count -= 1
                size -= victim[1]
        self.cleanup_images()
        return True

    def records(self):
        records = []
        for identity, kind, mime, title, preview, created, pinned, extension, size, width, height, media_path, media_bytes in self.db.execute(
                "SELECT id,kind,mime,title,preview,created,pinned,extension,length(data),width,height,media_path,media_bytes FROM entries ORDER BY created DESC,id"):
            image = ""
            if kind == "image" and media_path:
                image = Path(media_path).as_uri()
            elif kind == "image":
                path = self.directory / (identity + ".preview." + extension)
                if not path.exists():
                    payload = self.db.execute("SELECT data FROM entries WHERE id=?", (identity,)).fetchone()[0]
                    path.write_bytes(payload)
                    path.chmod(0o600)
                image = path.as_uri()
            elif kind == "video" and media_path:
                path = self.directory / (identity + ".preview.jpg")
                if not path.exists() and shutil.which("ffmpeg"):
                    try:
                        subprocess.run(["ffmpeg", "-v", "error", "-protocol_whitelist", "file,pipe", "-i", media_path,
                            "-frames:v", "1", "-vf", "scale=640:640:force_original_aspect_ratio=decrease", "-update", "1", "-y", str(path)],
                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
                    except (OSError, subprocess.TimeoutExpired):
                        pass
                if path.exists():
                    image = path.as_uri()
            records.append(dict(id=identity, kind=kind, mime=mime, title=title,
                                text=preview, created=created * 1000, pinned=bool(pinned),
                                image=image, bytes=media_bytes or size, format=extension.upper(), width=width, height=height))
        return records

    def pin(self, identity):
        with self.db:
            self.db.execute("UPDATE entries SET pinned=1-pinned WHERE id=?", (identity,))

    def remove(self, identity):
        with self.db:
            self.db.execute("DELETE FROM entries WHERE id=?", (identity,))
        self.cleanup_images()

    def clear(self):
        with self.db:
            self.db.execute("DELETE FROM entries")
        self.cleanup_images()

    def payload(self, identity):
        return self.db.execute("SELECT mime,data FROM entries WHERE id=?", (identity,)).fetchone()


def emit(message):
    print(json.dumps(message, ensure_ascii=False, separators=(",", ":")), flush=True)


def capture(socket_path, kind):
    # wl-paste explicitly marks password-manager selections as sensitive.
    if os.environ.get("CLIPBOARD_STATE") in ("nil", "clear", "sensitive"):
        return
    captured_at = time.time()
    payload = sys.stdin.buffer.read(MAX_ITEM_BYTES + 1)
    if not payload or len(payload) > MAX_ITEM_BYTES:
        return
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(5)
        try:
            connection.connect(socket_path)
            connection.sendall(json.dumps(dict(kind=kind, length=len(payload), captured_at=captured_at)).encode() + b"\n" + payload)
        except (OSError, TimeoutError):
            pass  # The shell may have closed while wl-paste was dispatching.


async def read_current():
    async def read(arguments, limit):
        process = await asyncio.create_subprocess_exec("wl-paste", *arguments,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        try:
            async def consume():
                result = bytearray()
                while chunk := await process.stdout.read(min(65536, limit + 1 - len(result))):
                    result.extend(chunk)
                    if len(result) > limit:
                        raise ValueError("Содержимое буфера больше 16 МиБ")
                return bytes(result)
            data = await asyncio.wait_for(consume(), 5)
            await asyncio.wait_for(process.wait(), 5)
            if process.returncode:
                raise ValueError("Буфер пуст или недоступен в текущем сеансе Wayland")
            return data
        finally:
            if process.returncode is None:
                process.kill()
                await process.communicate()
    types = (await read(["--list-types"], 8192)).decode("utf-8").splitlines()
    mime = next((t for t in types if t == "text/uri-list"), None)
    mime = mime or next((t for t in types if t.startswith("image/") and t != "image/svg+xml"), None)
    mime = mime or next((t for t in types if t in ("video/mp4", "video/webm", "video/ogg")), None)
    mime = mime or next((t for t in types if t.startswith("text/plain")), None)
    if not mime:
        raise ValueError("В буфере нет текста, изображения или видео поддерживаемого формата")
    data = await read(["--no-newline", "--type", mime], MAX_ITEM_BYTES)
    if not data:
        raise ValueError("Буфер обмена пуст")
    if mime.startswith("image/"):
        return {"image": "data:" + mime + ";base64," + base64.b64encode(data).decode()}
    if mime.startswith("video/"):
        return {"media": base64.b64encode(data).decode(), "mime": mime}
    text = data.decode("utf-8")
    if mime == "text/uri-list":
        return {"urls": [line for line in text.splitlines() if line and not line.startswith("#")]}
    return {"text": text}


async def run(args):
    store = Store(args.directory)
    lock = (store.directory / "worker.lock").open("w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        emit(dict(event="error", error="Журнал буфера уже запущен"))
        return
    runtime = Path(tempfile.mkdtemp(prefix="nayori-clipboard-", dir=os.environ.get("XDG_RUNTIME_DIR") or None))
    socket_path = str(runtime / "capture.sock")
    watchers = []
    stopped = asyncio.Event()
    available = bool(shutil.which("wl-paste") and shutil.which("wl-copy"))
    error = "" if available else "Для журнала нужен wl-clipboard: wl-paste и wl-copy"
    cleared_at = 0
    loop = asyncio.get_running_loop()

    def snapshot():
        emit(dict(event="history", ready=available, error=error, records=store.records()))

    async def receive(reader, writer):
        nonlocal error
        try:
            header = json.loads(await asyncio.wait_for(reader.readline(), 3))
            length = header.get("length")
            if type(length) is not int or not 0 < length <= MAX_ITEM_BYTES:
                return
            data = await asyncio.wait_for(reader.readexactly(length), 5)
            if not isinstance(header.get("captured_at"), (int, float)) or header["captured_at"] < cleared_at:
                return
            if store.add(header.get("kind"), data):
                if available:
                    error = ""
                snapshot()
        except (ValueError, OSError, asyncio.TimeoutError, asyncio.IncompleteReadError):
            pass
        finally:
            writer.close()
            with contextlib.suppress(OSError):
                await writer.wait_closed()

    async def command(message):
        nonlocal cleared_at
        try:
            action, identity = message.get("action"), message.get("id", "")
            if action == "read-current":
                emit(dict(event="content", content=await read_current()))
            elif action == "list":
                snapshot()
            elif action == "pin":
                store.pin(identity)
                snapshot()
            elif action == "remove":
                store.remove(identity)
                snapshot()
            elif action == "clear":
                cleared_at = time.time()
                store.clear()
                snapshot()
                process = await asyncio.create_subprocess_exec("wl-copy", "--clear",
                    stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
                try:
                    await asyncio.wait_for(process.wait(), 5)
                except asyncio.TimeoutError:
                    process.kill()
                    await process.wait()
                if process.returncode != 0:
                    raise ValueError("История очищена, но текущий буфер очистить не удалось")
            elif action in ("copy", "copy-content"):
                if action == "copy-content":
                    mime, text = message.get("mime"), message.get("text")
                    if mime not in ("text/plain;charset=utf-8", "text/uri-list") or not isinstance(text, str) or len(text.encode()) > MAX_TEXT_BYTES:
                        raise ValueError("Недопустимое содержимое буфера")
                    payload = (mime, text.encode())
                else:
                    payload = store.payload(identity)
                if not payload:
                    raise ValueError("Запись больше не доступна")
                process = await asyncio.create_subprocess_exec("wl-copy", "--type", payload[0],
                    stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
                try:
                    await asyncio.wait_for(process.communicate(payload[1]), 5)
                except asyncio.TimeoutError:
                    process.kill()
                    await process.wait()
                    raise ValueError("Буфер обмена не ответил. Попробуйте еще раз")
                if process.returncode != 0:
                    raise ValueError("Не удалось скопировать. Проверьте сеанс Wayland")
                emit(dict(event="copied", id=identity))
            elif action == "paste":
                process = await asyncio.create_subprocess_exec(sys.executable,
                    str(Path(__file__).with_name("paste_shortcut.py")),
                    stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
                try:
                    await asyncio.wait_for(process.wait(), 3)
                except asyncio.TimeoutError:
                    process.kill()
                    await process.wait()
                if process.returncode == 0:
                    emit(dict(event="pasted"))
                else:
                    emit(dict(event="paste-unavailable", error="Скопировано. Приложение не приняло автоматическую вставку"))
            elif action == "stop":
                stopped.set()
        except (OSError, ValueError, asyncio.TimeoutError) as failure:
            emit(dict(event="error", error=str(failure) or "Буфер обмена не ответил"))

    # Serialize UI actions, including copy, while still receiving clipboard events.
    commands = asyncio.Queue()
    async def process_commands():
        while True:
            await command(await commands.get())

    input_buffer = bytearray()
    def stdin_ready():
        chunk = os.read(sys.stdin.fileno(), 8192)
        if not chunk:
            stopped.set()
            return
        input_buffer.extend(chunk)
        if len(input_buffer) > MAX_TEXT_BYTES * 6 + 65536:
            input_buffer.clear()
            return
        while b"\n" in input_buffer:
            line, _, remainder = input_buffer.partition(b"\n")
            input_buffer[:] = remainder
            try:
                message = json.loads(line)
                if isinstance(message, dict):
                    commands.put_nowait(message)
            except ValueError:
                pass

    async def watch(kind):
        nonlocal error
        while not stopped.is_set():
            process = await asyncio.create_subprocess_exec("wl-paste", "--no-newline", "--type", kind,
                "--watch", sys.executable, str(Path(__file__).resolve()), "capture", socket_path, kind,
                stdin=asyncio.subprocess.DEVNULL, stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL, start_new_session=True)
            watchers.append(process)
            await process.wait()
            watchers.remove(process)
            if not stopped.is_set():
                error = "Нет доступа к буферу Wayland. Повторное подключение…"
                snapshot()
                await asyncio.sleep(3)

    server = await asyncio.start_unix_server(receive, path=socket_path)
    # Only the callback children need this socket; the directory is mode 0700.
    emit(dict(event="capture", socket=socket_path))
    loop.add_reader(sys.stdin.fileno(), stdin_ready)
    for signum in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(signum, stopped.set)
    tasks = [asyncio.create_task(process_commands())]
    if available and not args.no_watch:
        tasks.extend(asyncio.create_task(watch(kind)) for kind in ("image", "text"))
    snapshot()
    try:
        await stopped.wait()
    finally:
        loop.remove_reader(sys.stdin.fileno())
        server.close()
        await server.wait_closed()
        for task in tasks:
            task.cancel()
        for process in watchers:
            with contextlib.suppress(ProcessLookupError):
                os.killpg(process.pid, signal.SIGTERM)
        await asyncio.gather(*tasks, return_exceptions=True)
        for process in watchers:
            with contextlib.suppress(asyncio.TimeoutError):
                await asyncio.wait_for(process.wait(), 2)
        store.db.close()
        shutil.rmtree(runtime, ignore_errors=True)
        lock.close()


def main():
    os.umask(0o077)
    if len(sys.argv) == 4 and sys.argv[1] == "capture":
        capture(sys.argv[2], sys.argv[3])
        return
    parser = argparse.ArgumentParser()
    default_state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    parser.add_argument("--directory", type=Path, default=default_state / "nayori/clipboard")
    parser.add_argument("--no-watch", action="store_true", help="Isolated tests: do not read the system clipboard")
    args = parser.parse_args()
    try:
        asyncio.run(run(args))
    except (OSError, sqlite3.Error) as failure:
        emit(dict(event="error", error="Не удалось открыть журнал: " + str(failure)))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
