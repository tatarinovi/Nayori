#!/usr/bin/env python3
"""Shared output monitor: energy, beat, RMS, 48 bands, 128 bands, 128 PCM samples."""
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


def pcm_waveform(data, count=128):
    """Fold the stronger stereo channel into a real signed scope trace."""
    samples = array.array('h')
    samples.frombytes(data[:len(data) // 4 * 4])
    if sys.byteorder != 'little':
        samples.byteswap()
    channels = [samples[::2], samples[1::2]]
    channel = max(channels, key=lambda c: sum(v * v for v in c))
    if not channel:
        return [0.0] * count
    return [sum(channel[i * len(channel) // count:max(i * len(channel) // count + 1, (i + 1) * len(channel) // count)])
            / max(1, (i + 1) * len(channel) // count - i * len(channel) // count) / 32768 for i in range(count)]


def fold_bands(values, count=48):
    return [sum(values[i * len(values) // count:(i + 1) * len(values) // count])
            / max(1, (i + 1) * len(values) // count - i * len(values) // count) for i in range(count)]


def stop(signum, frame):
    raise SystemExit(0)


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    sink = sys.argv[1]
    if not sink or '\n' in sink or '\r' in sink:
        return 2
    fps = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] in ('30', '45', '60') else 30
    config = f'''[general]
framerate = {fps}
bars = 128
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
    level = [0.0, 0.0, [0.0] * 128]
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
                        level[:] = [pcm_rms(data), time.monotonic(), pcm_waveform(data)]
                    level[:] = [0.0, 0.0, [0.0] * 128]
                threading.Thread(target=read_level, daemon=True).start()
            except OSError:
                # No spectral-energy substitute for a missing waveform monitor.
                pass
            baseline = 0.0
            last_beat = 0.0
            for line in child.stdout:
                try:
                    values = [float(v) / 1000 for v in line.strip().split(';') if v]
                    if len(values) != 128 or not all(math.isfinite(v) for v in values):
                        continue
                    values = [max(0.0, min(1.0, v)) for v in values]
                    energy = min(1.0, sum(values) / len(values))
                    # Preserve the low 3/8 of the spectrum used by the old 8-band feed.
                    bass = sum(values[:48]) / 48
                    beat = min(1.0, max(0.0, bass - baseline * 1.3) * 3) if bass > 0.08 else 0
                    now = time.monotonic()
                    if beat < 0.12 or now - last_beat < 0.16:
                        beat = 0
                    else:
                        last_beat = now
                    baseline += (bass - baseline) * 0.12
                    amplitude, sampled_at, waveform = level
                    volume = amplitude if now - sampled_at < 0.5 else 0.0
                    spectrum = ' '.join(f'{value:.4f}' for value in fold_bands(values))
                    detail = ' '.join(f'{value:.4f}' for value in values)
                    wave = ' '.join(f'{value:.5f}' for value in (waveform if now - sampled_at < 0.5 else [0.0] * 128))
                    print(f'{energy:.4f} {beat:.4f} {volume:.5f} {spectrum} {detail} {wave}', flush=True)
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
