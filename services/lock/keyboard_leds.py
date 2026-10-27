"""Read Caps Lock LEDs while the lock is visible; no keyboard capture."""
from pathlib import Path
import time

while True:
    active = False
    for path in Path('/sys/class/leds').glob('*::capslock/brightness'):
        try:
            active |= path.read_text().strip() != '0'
        except OSError:
            pass
    print('1' if active else '0', flush=True)
    time.sleep(0.4)
