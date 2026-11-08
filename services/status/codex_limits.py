#!/usr/bin/env python3
"""Adapt AI Usage Bar's OpenAI widget output for the Nayori panel."""
import html
import json
import re
import subprocess


def parse(raw):
    try:
        result = json.loads(raw)
        text = html.unescape(re.sub(r"<[^>]*>", "", result["text"]))
        fields = text.split("|")
        if len(fields) != 5 or fields[0] != "NAYORI":
            return {"status": "error"}
        windows = []
        for percent, reset, minutes in ((fields[1], fields[3], 300), (fields[2], fields[4], 10080)):
            used = int(percent.strip())
            if not 0 <= used <= 100:
                return {"status": "error"}
            windows.append({"left": 100 - used, "minutes": minutes, "resetText": reset.strip()})
        return {"status": "ok", "windows": windows}
    except (ValueError, TypeError, KeyError):
        return {"status": "error"}


def scan():
    try:
        result = subprocess.run(
            ["ai-usagebar", "--vendor", "openai", "--json", "--format",
             "NAYORI|{session_pct}|{weekly_pct}|{session_reset}|{weekly_reset}",
             "--tooltip-format", ""],
            capture_output=True, text=True, timeout=20, check=True)
        return parse(result.stdout)
    except FileNotFoundError:
        return {"status": "missing"}
    except (subprocess.SubprocessError, OSError, UnicodeError):
        return {"status": "error"}


if __name__ == "__main__":
    print(json.dumps(scan()))
