#!/usr/bin/env python3
"""Stream normalized cava output; config lives only for the child lifetime."""
import os, signal, subprocess, sys, tempfile, time
def stop(signum, frame):
    raise SystemExit(0)
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
sink = sys.argv[1]
if not sink or '\n' in sink or '\r' in sink:
    sys.exit(2)
config = f'''[general]
framerate = 30
bars = 8
[input]
method = pulse
source = {sink}.monitor
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
channels = mono
[smoothing]
noise_reduction = 30
'''
with tempfile.TemporaryDirectory(prefix='nayori-audio-') as directory:
    path = os.path.join(directory, 'config')
    with open(path, 'w') as stream:
        stream.write(config)
    child = subprocess.Popen(['cava', '-p', path], stdout=subprocess.PIPE, text=True)
    try:
        baseline = 0.0
        last_beat = 0.0
        for line in child.stdout:
            try:
                values = [float(v) / 1000 for v in line.strip().split(';') if v]
                if not values: continue
                energy = min(1.0, sum(values) / len(values))
                bass = sum(values[:3]) / min(3, len(values))
                beat = min(1.0, max(0.0, bass - baseline * 1.3) * 3) if bass > 0.08 else 0
                now = time.monotonic()
                if beat < 0.12 or now - last_beat < 0.16:
                    beat = 0
                else:
                    last_beat = now
                baseline += (bass - baseline) * 0.12
                print(f'{energy:.4f} {beat:.4f}', flush=True)
            except ValueError:
                continue
    finally:
        child.terminate()
        child.wait()
    sys.exit(child.returncode)
