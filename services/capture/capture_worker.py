"""Capture worker. JSON-lines IPC, private frozen frames, flattened image export.

Only argv subprocesses are used. GPU Screen Recorder 6 provides region capture,
audio mixing and pause; the shell owns the countdown and all interactive UI.
"""
import asyncio
import contextlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import sys
import tempfile
import time
from uuid import uuid4

from PIL import Image, ImageDraw, ImageFilter, ImageFont


def emit(event, **values):
    print(json.dumps(dict(event=event, **values), ensure_ascii=False), flush=True)


def directory(value):
    path = Path(str(value)).expanduser()
    if not path.is_absolute() or "\x00" in str(path):
        raise ValueError("Нужен абсолютный путь к папке или путь с ~/.")
    path.mkdir(parents=True, exist_ok=True)
    return path


def number(value, low, high):
    value = float(value)
    if not math.isfinite(value) or not low <= value <= high:
        raise ValueError("Некорректные координаты области.")
    return value


def rect(value, width, height):
    x = round(number(value.get("x"), 0, width))
    y = round(number(value.get("y"), 0, height))
    w = round(number(value.get("w"), 2, width))
    h = round(number(value.get("h"), 2, height))
    if x + w > width or y + h > height:
        raise ValueError("Область выходит за границы монитора.")
    return x, y, w, h


def render(frame, area, marks, logical_size):
    """Marks are in logical output coordinates; export uses native frame pixels."""
    with Image.open(frame) as source:
        source = source.convert("RGB")
    lw, lh = logical_size
    x, y, w, h = rect(area, lw, lh)
    sx, sy = source.width / lw, source.height / lh
    image = source.crop((round(x * sx), round(y * sy), round((x + w) * sx), round((y + h) * sy)))
    if not isinstance(marks, list) or len(marks) > 2000:
        raise ValueError("Слишком много элементов разметки.")
    draw = ImageDraw.Draw(image)
    for mark in marks:
        kind = mark.get("tool")
        ax, ay = number(mark.get("x"), 0, lw), number(mark.get("y"), 0, lh)
        bx, by = number(mark.get("ex", ax), 0, lw), number(mark.get("ey", ay), 0, lh)
        a, b = ((ax - x) * sx, (ay - y) * sy), ((bx - x) * sx, (by - y) * sy)
        color = str(mark.get("color", "#CAA7AA"))
        if not re.fullmatch(r"#[0-9A-Fa-f]{6}", color):
            raise ValueError("Некорректный цвет разметки.")
        line = max(1, round(number(mark.get("size", 3), 1, 32) * (sx + sy) / 2))
        box = (max(0, round(min(a[0], b[0]))), max(0, round(min(a[1], b[1]))),
               min(image.width, round(max(a[0], b[0]))), min(image.height, round(max(a[1], b[1]))))
        if kind == "blur":
            if box[2] <= box[0] or box[3] <= box[1]:
                continue
            # Flatten strong blur into the exported RGB pixels, never retain layers.
            patch = image.crop(box).filter(ImageFilter.GaussianBlur(max(16, 18 * max(sx, sy))))
            image.paste(patch, box[:2])
        elif kind == "rect":
            draw.rectangle(box, outline=color, width=line)
        elif kind == "arrow":
            draw.line((a, b), fill=color, width=line)
            angle = math.atan2(b[1] - a[1], b[0] - a[0])
            length = max(12 * max(sx, sy), line * 4)
            draw.line(((b[0] - length * math.cos(angle - .5), b[1] - length * math.sin(angle - .5)), b,
                       (b[0] - length * math.cos(angle + .5), b[1] - length * math.sin(angle + .5))), fill=color, width=line)
        elif kind == "text":
            text = str(mark.get("text", ""))[:4000]
            font = ImageFont.truetype("DejaVuSans.ttf", max(12, round(22 * sy)))
            draw.text(a, text, font=font, fill=color, anchor="lt")
    return image


async def run(*args, timeout=15, data=None):
    proc = await asyncio.create_subprocess_exec(*map(str, args), stdin=asyncio.subprocess.PIPE if data is not None else asyncio.subprocess.DEVNULL,
                                                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        out, err = await asyncio.wait_for(proc.communicate(data), timeout)
    except (asyncio.TimeoutError, asyncio.CancelledError):
        with contextlib.suppress(ProcessLookupError):
            proc.kill()
        await proc.wait()
        raise
    if proc.returncode:
        raise RuntimeError(err.decode(errors="replace").strip()[-1400:] or f"{args[0]}: {proc.returncode}")
    return out


async def copy_file(path, image=False):
    # wl-copy forks a long-lived selection owner. Captured stdout/stderr pipes
    # can remain open in that child, so communicate() waits until the selection
    # is replaced rather than until copying succeeds. Use regular files instead.
    with contextlib.ExitStack() as stack:
        if image:
            payload = stack.enter_context(path.open("rb"))
        else:
            # URI-list copies the actual file, not a plain-text path or video bytes.
            payload = stack.enter_context(tempfile.TemporaryFile())
            payload.write((path.as_uri() + "\r\n").encode())
            payload.seek(0)
        errors = stack.enter_context(tempfile.TemporaryFile())
        proc = await asyncio.create_subprocess_exec(
            "wl-copy", "--type", "image/png" if image else "text/uri-list",
            stdin=payload, stdout=asyncio.subprocess.DEVNULL, stderr=errors,
            start_new_session=True)
        try:
            await asyncio.wait_for(proc.wait(), 5)
        except (asyncio.TimeoutError, asyncio.CancelledError):
            with contextlib.suppress(ProcessLookupError):
                proc.kill()
            await proc.wait()
            raise
        if proc.returncode:
            errors.seek(0)
            details = errors.read(1400).decode(errors="replace").strip()
            raise RuntimeError(details or f"wl-copy: {proc.returncode}")


def record_command(output, area, options, path):
    x, y, w, h = rect(area, output["width"], output["height"])
    gx, gy = x + output["x"], y + output["y"]
    fmt = options.get("captureFormat", "mp4")
    if fmt not in ("mp4", "webm"):
        raise ValueError("Неизвестный формат записи.")
    fps = options.get("captureFps", 30)
    if fps not in (30, 60):
        raise ValueError("Частота кадров должна быть 30 или 60.")
    quality = options.get("captureQuality", "high")
    if quality not in ("high", "very_high"):
        raise ValueError("Неизвестное качество записи.")
    argv = ["gpu-screen-recorder", "-w", "region", "-region", f"{w}x{h}+{gx}+{gy}", "-f", str(fps),
            "-c", fmt, "-k", "vp9" if fmt == "webm" else "h264", "-ac", "opus" if fmt == "webm" else "aac",
            "-q", quality, "-cursor", "yes" if options.get("captureCursor", True) else "no", "-o", str(path)]
    mic, system = options.get("captureMic", False), options.get("captureSystemAudio", True)
    audio = "default_output|default_input" if mic and system else "default_input" if mic else "default_output" if system else ""
    if audio:
        argv += ["-a", audio]
    return argv


class Worker:
    def __init__(self, temp):
        self.temp = Path(temp)
        self.frame = self.temp / "frame.png"
        self.output = None
        self.proc = None
        self.monitor = None
        self.log = None
        self.target = None
        self.paused = False
        self.stopping = False

    async def prepare(self, message):
        if self.proc:
            raise ValueError("Сначала завершите текущую запись.")
        self.output = None
        with contextlib.suppress(FileNotFoundError):
            self.frame.unlink()
        # Niri supplies global logical geometry, including negative monitor origins.
        outputs = json.loads(await run("niri", "msg", "-j", "outputs"))
        name = str(message.get("output", ""))
        info = outputs.get(name)
        logical = info.get("logical") if info else None
        if not logical or info.get("current_mode") is None:
            raise ValueError("Монитор недоступен. Выберите подключённый монитор.")
        output = {key: int(logical[key]) for key in ("x", "y", "width", "height")}
        output["name"] = name
        if output["width"] < 2 or output["height"] < 2:
            raise ValueError("Некорректный размер монитора.")
        # This frame lives briefly in the private runtime directory. Compression
        # only delays selection; encode the final annotated PNG when exporting.
        await run("grim", "-l", "0", "-o", name, str(self.frame))
        self.output = output
        emit("prepared", source=self.frame.as_uri() + "?" + uuid4().hex, **output)

    async def export(self, message):
        if not self.output or not self.frame.exists():
            raise ValueError("Снимок недоступен. Повторите захват.")
        options = message.get("options", {})
        image = await asyncio.to_thread(render, self.frame, message["rect"], message.get("marks", []),
                                        (self.output["width"], self.output["height"]))
        folder = directory(options.get("captureShotDir", "~/Pictures/Screenshots"))
        target = folder / (time.strftime("Screenshot-%Y-%m-%d-%H%M%S-") + uuid4().hex[:8] + ".png")
        # A completed PNG is installed atomically; failed saves keep the frozen frame.
        pending = self.temp / "export.png"
        await asyncio.to_thread(image.save, pending, format="PNG")
        fd, staged_name = tempfile.mkstemp(prefix=".nayori-shot-", suffix=".png", dir=folder)
        staged = Path(staged_name)
        try:
            with os.fdopen(fd, "wb") as dest, pending.open("rb") as src:
                shutil.copyfileobj(src, dest)
            os.link(staged, target)  # exclusive installation, never replace an existing file
        finally:
            staged.unlink(missing_ok=True)
        warning = ""
        copy_error = ""
        if message.get("copy", True):
            try:
                await copy_file(target, image=True)
            except (OSError, RuntimeError, asyncio.TimeoutError) as error:
                warning = "Файл сохранён, но скопировать изображение не удалось."
                copy_error = str(error) or "wl-copy: время ожидания истекло"
        self.frame.unlink(missing_ok=True)
        self.output = None
        emit("saved", kind="shot", path=str(target), copied=message.get("copy", True) and not warning, warning=warning, copyError=copy_error)

    async def start(self, message):
        if self.proc or not self.output:
            raise ValueError("Сначала выберите область записи.")
        if not shutil.which("gpu-screen-recorder"):
            raise ValueError("Для записи нужен gpu-screen-recorder версии 6 или новее.")
        options = message.get("options", {})
        folder = directory(options.get("captureVideoDir", "~/Videos/Screencasts"))
        fmt = options.get("captureFormat", "mp4")
        if fmt not in ("mp4", "webm"):
            raise ValueError("Неизвестный формат записи.")
        target = folder / (time.strftime("Screencast-%Y-%m-%d-%H%M%S-") + uuid4().hex[:8] + "." + fmt)
        command = record_command(self.output, message["rect"], options, target)
        self.log = (self.temp / "recorder.log").open("wb")
        try:
            self.proc = await asyncio.create_subprocess_exec(*command, stdin=asyncio.subprocess.DEVNULL,
                                                            stdout=self.log, stderr=self.log)
        except BaseException:
            self.log.close()
            self.log = None
            raise
        self.target = target
        self.paused = False
        self.stopping = False
        # Detect unsupported options, missing GPU access and encoder failure before UI says REC.
        await asyncio.sleep(.4)
        if self.proc.returncode is not None:
            await self.finish(unexpected=True)
            return
        emit("recording")
        self.monitor = asyncio.create_task(self.watch())

    async def watch(self):
        await self.proc.wait()
        if not self.stopping:
            await self.finish(unexpected=True)

    async def pause(self):
        if not self.proc or self.proc.returncode is not None or self.stopping:
            raise ValueError("Запись уже завершена.")
        self.proc.send_signal(signal.SIGUSR2)
        self.paused = not self.paused
        emit("paused", paused=self.paused)

    async def stop(self):
        if not self.proc:
            return
        self.stopping = True
        if self.proc.returncode is None:
            self.proc.send_signal(signal.SIGINT)
        try:
            await asyncio.wait_for(self.proc.wait(), 30)
        except asyncio.TimeoutError:
            self.proc.kill()
            await self.proc.wait()
        await self.finish()

    async def finish(self, unexpected=False):
        proc, target = self.proc, self.target
        if not proc:
            return
        code = proc.returncode
        self.proc = None
        if self.log:
            self.log.close()
            self.log = None
        self.output = None
        self.frame.unlink(missing_ok=True)
        if code != 0 or unexpected or not target.exists() or target.stat().st_size == 0:
            # Preserve any playable partial file. Do not claim it was successfully saved.
            details = (self.temp / "recorder.log").read_text(errors="replace")[-1200:]
            emit("error", action="record", message="Запись остановилась с ошибкой.", details=details,
                 path=str(target) if target.exists() else "")
            return
        try:
            await run("ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=codec_name",
                      "-of", "csv=p=0", str(target))
        except (OSError, RuntimeError, asyncio.TimeoutError):
            emit("error", action="record", message="Не удалось проверить видео. Файл оставлен в папке записи.", path=str(target))
            return
        warning = ""
        copy_error = ""
        try:
            await copy_file(target)
        except (OSError, RuntimeError, asyncio.TimeoutError) as error:
            warning = "Видео сохранено, но скопировать файл не удалось."
            copy_error = str(error) or "wl-copy: время ожидания истекло"
        emit("saved", kind="video", path=str(target), copied=not warning, warning=warning, copyError=copy_error)

    async def dispatch(self, message):
        action = message.get("action")
        try:
            if action == "prepare":
                await self.prepare(message)
            elif action == "export":
                await self.export(message)
            elif action == "start":
                await self.start(message)
            elif action == "pause":
                await self.pause()
            elif action == "stop":
                await self.stop()
            elif action == "cancel" and not self.proc:
                self.frame.unlink(missing_ok=True)
                self.output = None
                emit("cancelled")
            else:
                raise ValueError("Неизвестная команда захвата.")
        except (ValueError, KeyError, TypeError, OSError, RuntimeError, asyncio.TimeoutError) as error:
            emit("error", action=action, message=str(error) or "Захват не завершён. Повторите попытку.")


async def main():
    os.umask(0o077)
    # Tied to the QML owner: stdin EOF, SIGTERM and SIGINT all finalize the child.
    with tempfile.TemporaryDirectory(prefix="nayori-capture-", dir=os.environ.get("XDG_RUNTIME_DIR") or None) as temp:
        worker = Worker(temp)
        loop = asyncio.get_running_loop()
        reader = asyncio.StreamReader(limit=2 * 1024 * 1024)
        transport, _ = await loop.connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
        task = asyncio.current_task()
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(sig, task.cancel)
        emit("ready", screenshot=bool(shutil.which("grim")), recorder=bool(shutil.which("gpu-screen-recorder")))
        try:
            while line := await reader.readline():
                try:
                    value = json.loads(line)
                    if not isinstance(value, dict):
                        raise ValueError("object expected")
                except (ValueError, UnicodeError):
                    emit("error", message="Некорректная команда захвата.")
                    continue
                await worker.dispatch(value)
        except asyncio.CancelledError:
            pass
        finally:
            await worker.stop()
            transport.close()


if __name__ == "__main__":
    asyncio.run(main())
