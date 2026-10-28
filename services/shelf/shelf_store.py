"""Persistent staging shelf; Wayland clipboard operations belong to ClipboardService."""
import base64
import hashlib
import json
import mimetypes
import os
from pathlib import Path
import shutil
import sqlite3
import sys
import urllib.parse
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "clipboard"))
from clipboard_store import image_format, local_files  # noqa: E402

MAX_BYTES = 16 * 1024 * 1024
MAX_ITEMS = 200
MAX_CACHE_BYTES = 128 * 1024 * 1024
MAX_TEXT = 64000


class Shelf:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.directory.chmod(0o700)
        self.db = sqlite3.connect(self.directory / "shelf.sqlite3")
        self.db.execute("CREATE TABLE IF NOT EXISTS items (id TEXT PRIMARY KEY, value TEXT NOT NULL, added INTEGER NOT NULL)")
        (self.directory / "shelf.sqlite3").chmod(0o600)
        self.cleanup()

    def items(self):
        result = []
        for value, in self.db.execute("SELECT value FROM items ORDER BY added DESC, id"):
            item = json.loads(value)
            path = Path(item["path"]) if item.get("path") else None
            item["missing"] = bool(path and not path.exists())
            if path and path.exists():
                item["kind"] = "folder" if path.is_dir() else "image" if (mimetypes.guess_type(path)[0] or "").startswith("image/") else "video" if (mimetypes.guess_type(path)[0] or "").startswith("video/") else "file"
            item["uri"] = path.as_uri() if path else item.get("url", "")
            result.append(item)
        return result

    def find(self, identity):
        return next((i for i in self.items() if i["id"] == identity), None)

    def save(self, item):
        with self.db:
            self.db.execute("INSERT INTO items VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET value=excluded.value,added=excluded.added",
                            (item["id"], json.dumps(item, ensure_ascii=False), item["added"]))
        return item

    def put(self, kind, *, path="", url="", text="", note=False):
        if path:
            path = os.path.normpath(path)
        key = ("url:" + url) if url else ("path:" + path) if path else ("text:" + text)
        old = next((i for i in self.items() if
                    (url and i.get("url") == url) or
                    (not url and path and i.get("path") == path) or
                    (not url and not path and i["kind"] == "text" and i["text"] == text)), None)
        identity = old["id"] if old else hashlib.sha256(key.encode()).hexdigest()
        if not old and self.find(identity):
            import uuid
            identity = uuid.uuid4().hex
        if not old and len(self.items()) >= MAX_ITEMS:
            raise ValueError("Полка заполнена: удалите ненужные элементы")
        newest = self.db.execute("SELECT coalesce(max(added),0)+1 FROM items").fetchone()[0]
        item = old or dict(id=identity, kind=kind, path=path, url=url, text=text, fav=False, note=note)
        item["added"] = newest
        # Downloaded pictures get a readable name; source URLs remain available.
        item["name"] = ((Path(urllib.parse.urlsplit(url).path).name or "Изображение") if path and url else Path(path).name if path else (url if url else text.splitlines()[0]))[:120]
        if path and url:
            item.update(kind=kind, path=path, failed=False)
        if note:
            item["note"] = True
        return self.save(item)

    def remove(self, identity):
        with self.db:
            self.db.execute("DELETE FROM items WHERE id=?", (identity,))
        # Keep managed images alive for asynchronous receivers after a successful drag.

    def cleanup(self):
        kept = {i.get("path") for i in self.items()}
        for path in self.directory.glob("*.media.*"):
            if str(path) not in kept:
                path.unlink(missing_ok=True)

    def image(self, source):
        if source.startswith("data:"):
            header, _, payload = source.partition(",")
            if len(payload) > MAX_BYTES * 4 // 3 + 8:
                raise ValueError("Изображение слишком большое")
            data = base64.b64decode(payload, validate=True) if ";base64" in header else urllib.parse.unquote_to_bytes(payload)
        elif urllib.parse.urlsplit(source).scheme in ("http", "https"):
            request = urllib.request.Request(source, headers={"User-Agent": "Mozilla/5.0", "Accept": "image/*"})
            with urllib.request.urlopen(request, timeout=15) as response:
                if urllib.parse.urlsplit(response.url).scheme not in ("http", "https"):
                    raise ValueError("Недопустимый адрес изображения")
                data = response.read(MAX_BYTES + 1)
        else:
            raise ValueError("Изображение доступно только внутри браузера")
        fmt = image_format(data)
        if not fmt or len(data) > MAX_BYTES:
            raise ValueError("Не удалось получить изображение допустимого формата (до 16 МиБ)")
        return self.save_media(data, fmt[1])

    def save_media(self, data, extension):
        path = self.directory / (hashlib.sha256(data).hexdigest() + ".media." + extension)
        if not path.exists() and sum(p.stat().st_size for p in self.directory.glob("*.media.*")) + len(data) > MAX_CACHE_BYTES:
            raise ValueError("Кэш изображений и видео полки заполнен (128 МиБ). Удалите ненужные элементы и перезапустите оболочку")
        if not path.exists():
            temporary = path.with_suffix(path.suffix + ".part")
            try:
                temporary.write_bytes(data)
                temporary.chmod(0o600)
                temporary.replace(path)
            finally:
                temporary.unlink(missing_ok=True)
        return str(path)

    def add(self, message):
        media = message.get("media")
        if media:
            if not isinstance(media, str) or len(media) > MAX_BYTES * 4 // 3 + 8:
                raise ValueError("Видео больше 16 МиБ")
            data = base64.b64decode(media, validate=True)
            mime = message.get("mime")
            extension = "mp4" if mime == "video/mp4" and data[4:8] == b"ftyp" else "webm" if mime == "video/webm" and data.startswith(b"\x1aE\xdf\xa3") else "ogv" if mime == "video/ogg" and data.startswith(b"OggS") else ""
            if not extension or len(data) > MAX_BYTES:
                raise ValueError("Неподдерживаемый формат видео")
            self.put("video", path=self.save_media(data, extension))
            return
        urls = message.get("urls") or []
        text = str(message.get("text") or "").strip()
        source = str(message.get("image") or "")
        if len(urls) > MAX_ITEMS or len(text) > MAX_TEXT or len(source) > MAX_BYTES * 2:
            raise ValueError("Слишком большой элемент")
        errors = []
        if source:
            try:
                self.put("image", path=self.image(source), url=source if source.startswith(("http://", "https://")) else "")
            except (OSError, ValueError) as failure:
                if source.startswith(("http://", "https://")):
                    item = self.put("link", url=source)
                    item["failed"] = True
                    self.save(item)
                errors.append(str(failure))
            urls = [u for u in urls if str(u).startswith("file:")]
        elif not urls and text.startswith(("https://", "http://", "file://")) and "\n" not in text:
            urls, text = [text], ""
        for url in urls:
            url = str(url)
            paths = local_files(url)
            if paths:
                self.put("file", path=str(paths[0]))
            elif urllib.parse.urlsplit(url).scheme in ("http", "https"):
                self.put("link", url=url)
            else:
                errors.append("Неподдерживаемый адрес")
        if not urls and not source and text:
            self.put("text", text=text, note=bool(message.get("note")))
        if not urls and not source and not text:
            raise ValueError("Перетащите файл, ссылку, изображение или текст")
        if errors:
            raise ValueError("; ".join(errors))

    def action(self, message):
        action = message.get("action")
        if action == "add":
            self.add(message)
            return
        if action == "list":
            return
        item = self.find(message.get("id"))
        if not item:
            raise ValueError("Элемент больше не доступен")
        if action == "remove" or (action == "taken" and not item["fav"] and not item["note"]):
            self.remove(item["id"])
        elif action == "fav":
            item["fav"] = not item["fav"]
            self.save(item)
        elif action == "edit":
            text = str(message.get("text", ""))
            if item["kind"] != "text" or len(text) > MAX_TEXT:
                raise ValueError("Недопустимый текст заметки")
            if not text.strip():
                self.remove(item["id"])
            else:
                item.update(text=text, name=text.splitlines()[0][:120])
                self.save(item)
        elif action == "into":
            if item["kind"] != "folder" or not item["fav"] or item["missing"]:
                raise ValueError("Закреплённая папка недоступна")
            sources = local_files("\n".join(message.get("urls", [])))
            if not sources:
                raise ValueError("В папку можно скопировать только локальные файлы")
            folder = Path(item["path"]).resolve()
            for source in sources:
                source = source.resolve(strict=True)
                if source == folder or source in folder.parents:
                    raise ValueError("Нельзя копировать папку в саму себя")
                target = folder / source.name
                number = 2
                while target.exists() or target.is_symlink():
                    target = folder / (source.stem + f" ({number})" + source.suffix)
                    number += 1
                if source.is_dir():
                    shutil.copytree(source, target, symlinks=True)
                else:
                    # Reserve the name exclusively; never overwrite an existing file.
                    with target.open("xb") as output, source.open("rb") as data:
                        shutil.copyfileobj(data, output)
        elif action in ("open", "folder"):
            if item["missing"]:
                raise ValueError("Файл перемещён или удалён")
            target = str(Path(item["path"]).parent) if action == "folder" and item["path"] else item.get("path") or item.get("url")
            if not target:
                raise ValueError("У элемента нет файла или адреса")
            import subprocess
            subprocess.run(["xdg-open", target], check=True, timeout=10, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def emit(**message):
    print(json.dumps(message, ensure_ascii=False), flush=True)


def run():
    os.umask(0o077)
    directory = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "nayori/shelf"
    shelf = Shelf(directory)
    def execute(message):
        error = ""
        try:
            shelf.action(message)
        except Exception as failure:
            error = str(failure) or "Не удалось выполнить действие"
        emit(event="state", items=shelf.items(), error=error, ready=True)
    execute({"action": "list"})
    while line := sys.stdin.readline(MAX_BYTES * 2 + 65536):
        try:
            if not line.endswith("\n"):
                raise ValueError("Команда слишком большая")
            message = json.loads(line)
            if not isinstance(message, dict):
                raise ValueError("Некорректная команда")
            execute(message)
        except ValueError as failure:
            emit(event="error", error=str(failure))


if __name__ == "__main__":
    try:
        run()
    except Exception as failure:
        emit(event="error", error="Не удалось открыть полку: " + str(failure))
        sys.exit(1)
