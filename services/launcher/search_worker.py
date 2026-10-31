"""Один запрос поиска с stdin, один JSON-ответ в stdout. Ничего не запускает."""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from search_model import handle_request


def main() -> int:
    sys.stdin.reconfigure(encoding="utf-8", errors="replace")
    sys.stdout.reconfigure(encoding="utf-8", errors="strict")
    raw = sys.stdin.readline()
    payload = {"generation": 0, "query": ""}
    if raw.strip():
        try:
            loaded = json.loads(raw)
        except json.JSONDecodeError:
            loaded = None
        if isinstance(loaded, dict):
            payload = loaded
    result = handle_request(payload)
    sys.stdout.write(json.dumps(result, ensure_ascii=False) + "\n")
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
