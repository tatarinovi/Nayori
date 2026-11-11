"""Deterministic shared monitor fixture; never opens a real audio device."""
import math
import sys
import time

# The sink is passed as an argv element by AudioReaction, never through a shell.
assert sys.argv[1].startswith("fixture-")
for frame in range(400):
    detail = [.3 + .2 * math.sin(i * .2 + frame * .1) for i in range(128)]
    wave = [.1 * math.sin(i * .4 + frame * .1) for i in range(128)]
    values = [.5, 0, .12] + [.4] * 48 + detail + wave
    print(" ".join(map(str, values)), flush=True)
    time.sleep(.02)
