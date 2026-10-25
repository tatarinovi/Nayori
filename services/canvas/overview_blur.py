#!/usr/bin/env python3
"""Cache a downscaled blur of one wallpaper file.

The shell calls this when an output's wallpaper path, mtime, or size changes.
It does not stay running. A content hash names the cached file, so a result
from an older request cannot replace the current one. The temp file used for
the write is removed before return.
"""

import argparse
import hashlib
import json
import os
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlparse

MAX_EDGE = 480
# Gaussian radius on the already downscaled image. Strong enough that overview
# thumbnails stay readable, light enough that the picture is still recognizable.
BLUR_RADIUS = 18
MAX_PIXELS = 80_000_000

try:
    from PIL import Image, ImageFilter, ImageOps
except ImportError:
    Image = None
    ImageFilter = None
    ImageOps = None


def local_path(value):
    text = str(value or "").strip()
    if text.startswith("file:"):
        parsed = urlparse(text)
        if parsed.scheme != "file":
            return ""
        text = unquote(parsed.path)
    if not text.startswith("/"):
        return ""
    return text


def identity_key(path):
    resolved = os.path.realpath(path)
    stat = os.stat(resolved)
    return resolved, f"{resolved}\n{stat.st_mtime_ns}\n{stat.st_size}"


def cache_path(cache_dir, key):
    name = hashlib.sha256(key.encode("utf-8")).hexdigest() + ".png"
    return Path(cache_dir) / name


def downscale(image):
    image = ImageOps.exif_transpose(image)
    image = image.convert("RGB")
    width, height = image.size
    long_edge = max(width, height)
    if long_edge > MAX_EDGE:
        scale = MAX_EDGE / float(long_edge)
        width = max(1, int(round(width * scale)))
        height = max(1, int(round(height * scale)))
        image = image.resize((width, height), Image.Resampling.LANCZOS)
    return image


def write_png(image, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=str(destination.parent), prefix=".blur-", suffix=".png")
    os.close(fd)
    tmp = Path(tmp_name)
    replaced = False
    try:
        image.save(tmp, format="PNG")
        os.replace(tmp, destination)
        replaced = True
    finally:
        if not replaced:
            try:
                tmp.unlink()
            except OSError:
                pass


def blur_file(source, cache_dir):
    if Image is None:
        return {"ok": False, "pointer": "", "cached": False, "error": "blur unavailable"}
    path = local_path(source)
    if path == "":
        return {"ok": False, "pointer": "", "cached": False, "error": "missing"}
    try:
        resolved, key = identity_key(path)
    except OSError:
        return {"ok": False, "pointer": "", "cached": False, "error": "missing"}
    destination = cache_path(cache_dir, key)
    if destination.is_file() and destination.stat().st_size > 0:
        return {"ok": True, "pointer": str(destination), "cached": True, "error": ""}
    try:
        Image.MAX_IMAGE_PIXELS = MAX_PIXELS
        with Image.open(resolved) as opened:
            image = downscale(opened)
        image = image.filter(ImageFilter.GaussianBlur(radius=BLUR_RADIUS))
        write_png(image, destination)
    except Exception:
        return {"ok": False, "pointer": "", "cached": False, "error": "unreadable"}
    if not destination.is_file() or destination.stat().st_size <= 0:
        return {"ok": False, "pointer": "", "cached": False, "error": "unreadable"}
    return {"ok": True, "pointer": str(destination), "cached": False, "error": ""}


def take_pointer(payload, generation, output):
    """Ignore a finished blur whose generation is no longer the one we want."""
    if not isinstance(payload, dict) or payload.get("generation") != generation:
        return ""
    outputs = payload.get("outputs")
    if not isinstance(outputs, dict):
        return ""
    item = outputs.get(output)
    if not isinstance(item, dict) or item.get("ok") is not True:
        return ""
    pointer = item.get("pointer")
    return pointer if isinstance(pointer, str) else ""


def run_request(request):
    generation = request.get("generation")
    cache_dir = str(request.get("cacheDir") or "")
    jobs = request.get("jobs")
    outputs = {}
    if not isinstance(generation, int) or isinstance(generation, bool):
        raise ValueError("generation")
    if cache_dir == "" or not isinstance(jobs, list):
        raise ValueError("request")
    for job in jobs:
        if not isinstance(job, dict):
            continue
        output = str(job.get("output") or "")
        if output == "":
            continue
        result = blur_file(job.get("source"), cache_dir)
        outputs[output] = result
    return {"ok": True, "generation": generation, "outputs": outputs}


def main():
    parser = argparse.ArgumentParser(description="Cache a downscaled wallpaper blur")
    parser.add_argument("--request", required=True)
    args = parser.parse_args()
    try:
        request = json.loads(args.request)
        if not isinstance(request, dict):
            raise ValueError("request")
        payload = run_request(request)
    except Exception:
        payload = {"ok": False, "generation": None, "outputs": {}}
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
