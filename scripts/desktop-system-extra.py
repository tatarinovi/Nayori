#!/usr/bin/env python3
"""Read optional system monitor data without changing the running session."""
import glob
import json
import os
import subprocess
import sys

out = {'cpuTemp': None, 'gpuTemp': None, 'rx': None, 'tx': None, 'processes': []}
for path in sorted(glob.glob('/sys/class/hwmon/hwmon*/name')):
    try:
        with open(path, encoding='utf-8') as f:
            name = f.read(128).strip()
        if name in ('k10temp', 'coretemp', 'zenpower', 'cpu_thermal'):
            with open(os.path.join(os.path.dirname(path), 'temp1_input'), encoding='utf-8') as f:
                temp = int(f.read(32)) / 1000
            if -20 <= temp <= 150:
                out['cpuTemp'] = temp
                break
    except (OSError, ValueError):
        continue
try:
    rx = tx = 0
    with open('/proc/net/dev', encoding='utf-8') as f:
        for row in list(f)[2:]:
            name, sep, rest = row.partition(':')
            fields = rest.split()
            if not sep or name.strip() == 'lo' or name.strip().startswith(('veth', 'docker')) or len(fields) < 16:
                continue
            rx += int(fields[0]); tx += int(fields[8])
    out['rx'], out['tx'] = rx, tx
except (OSError, ValueError):
    pass
if len(sys.argv) > 1 and sys.argv[1] == 'details':
    try:
        result = subprocess.run(['ps', '-eo', 'pcpu,comm', '--sort=-pcpu', '--no-headers'], capture_output=True, text=True, timeout=2, check=True)
        for row in result.stdout.splitlines()[:3]:
            fields = row.strip().split(None, 1)
            if len(fields) == 2:
                out['processes'].append({'name': fields[1][:80], 'cpu': float(fields[0])})
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
print(json.dumps(out, ensure_ascii=False))
