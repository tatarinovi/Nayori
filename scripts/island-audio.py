#!/usr/bin/env python3
"""Stream cava energy/beats and broadband PCM RMS from the output monitor."""
import array
import math
import os
import signal
import subprocess
import sys
import tempfile
import threading
import time


def pcm_rms(data):
    samples = array.array('h')
    samples.frombytes(data[:len(data) // 2 * 2])
    if sys.byteorder != 'little':
        samples.byteswap()
    return math.sqrt(sum(sample * sample for sample in samples) / len(samples)) / 32768 if samples else 0.0


def stop(signum, frame):
    raise SystemExit(0)


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    sink = sys.argv[1]
    if not sink or '\n' in sink or '\r' in sink:
        return 2
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
    level = [0.0, 0.0]
    monitor = None
    with tempfile.TemporaryDirectory(prefix='nayori-audio-') as directory:
        path = os.path.join(directory, 'config')
        with open(path, 'w') as stream:
            stream.write(config)
        child = subprocess.Popen(['cava', '-p', path], stdout=subprocess.PIPE, text=True)
        try:
            try:
                monitor = subprocess.Popen(['parec', '--device', sink + '.monitor', '--format=s16le',
                                            '--rate=48000', '--channels=2', '--latency-msec=40'],
                                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                def read_level():
                    while data := monitor.stdout.read(3200):
                        level[:] = [pcm_rms(data), time.monotonic()]
                    level[:] = [0.0, 0.0]
                threading.Thread(target=read_level, daemon=True).start()
            except OSError:
                # No spectral-energy substitute for a missing waveform monitor.
                pass
            baseline = 0.0
            last_beat = 0.0
            for line in child.stdout:
                try:
                    values = [float(v) / 1000 for v in line.strip().split(';') if v]
                    if not values:
                        continue
                    energy = min(1.0, sum(values) / len(values))
                    bass = sum(values[:3]) / min(3, len(values))
                    beat = min(1.0, max(0.0, bass - baseline * 1.3) * 3) if bass > 0.08 else 0
                    now = time.monotonic()
                    if beat < 0.12 or now - last_beat < 0.16:
                        beat = 0
                    else:
                        last_beat = now
                    baseline += (bass - baseline) * 0.12
                    amplitude, sampled_at = level
                    volume = amplitude if now - sampled_at < 0.5 else 0.0
                    print(f'{energy:.4f} {beat:.4f} {volume:.5f}', flush=True)
                except ValueError:
                    continue
        finally:
            for process in [child, monitor]:
                if process is None:
                    continue
                process.terminate()
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        return child.returncode


if __name__ == '__main__':
    sys.exit(main())
