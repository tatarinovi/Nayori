"""Report only isolated Super taps; never grab devices or record typed text.

Approach inspected in AngelOS MetaTap; this implementation is independent.
"""
import os
import selectors
import subprocess
import time


class TapDetector:
    def __init__(self, threshold=0.4):
        self.threshold = threshold
        self.started = None
        self.cancelled = False
        self.held = set()

    def cancel(self):
        self.cancelled = True

    def press(self, key, now, other_held=False):
        if key in self.held:
            return
        if self.held:
            self.cancel()
        else:
            self.started = now
            self.cancelled = other_held
        self.held.add(key)

    def release(self, key, now):
        if key not in self.held:
            return False
        self.held.remove(key)
        if self.held:
            return False
        tapped = (self.started is not None and not self.cancelled
                  and 0 <= now - self.started <= self.threshold)
        self.started = None
        return tapped

    def reset(self):
        self.held.clear()
        self.started = None
        self.cancelled = True


def session_unlocked():
    try:
        result = subprocess.run(
            ['loginctl', 'show-session', os.environ.get('XDG_SESSION_ID') or 'self',
             '-p', 'Active', '-p', 'LockedHint'],
            capture_output=True, text=True, timeout=1, check=True)
        values = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
        return values.get('Active') == 'yes' and values.get('LockedHint') == 'no'
    except (OSError, subprocess.SubprocessError):
        return False


def run():
    try:
        import evdev
        from evdev import ecodes as e
    except ImportError:
        print('missing-evdev', flush=True)
        return
    meta = {e.KEY_LEFTMETA, e.KEY_RIGHTMETA}
    detector = TapDetector()
    devices = {}
    selector = selectors.DefaultSelector()
    last_status = None

    def report(status):
        nonlocal last_status
        if last_status != status:
            print(status, flush=True)
            last_status = status

    def drop(path):
        device = devices.pop(path)
        selector.unregister(device)
        device.close()
        detector.reset()

    def scan():
        denied = False
        seen = set(evdev.list_devices())
        for path in set(devices) - seen:
            drop(path)
        for path in seen - set(devices):
            try:
                device = evdev.InputDevice(path)
                keys = set(device.capabilities().get(e.EV_KEY, []))
                if not (keys & meta or e.BTN_LEFT in keys or e.KEY_A in keys):
                    device.close()
                    continue
                devices[path] = device
                selector.register(device, selectors.EVENT_READ)
            except PermissionError:
                denied = True
            except OSError:
                continue
        keyboard = any(meta & set(d.capabilities().get(e.EV_KEY, [])) for d in devices.values())
        report('ready' if keyboard else 'permission-denied' if denied else 'no-keyboard')

    next_scan = 0
    while True:
        if time.monotonic() >= next_scan:
            scan()
            next_scan = time.monotonic() + 3
        for selected, _ in selector.select(timeout=1):
            device = selected.fileobj
            try:
                events = list(device.read())
            except OSError:
                drop(device.path)
                continue
            for event in events:
                if event.type == e.EV_SYN and event.code == e.SYN_DROPPED:
                    detector.reset()
                elif event.type == e.EV_KEY and event.code in meta:
                    key = (device.path, event.code)
                    if event.value == 1:
                        try:
                            other = any(set(d.active_keys()) - meta for d in devices.values())
                        except OSError:
                            other = True
                        detector.press(key, time.monotonic(), bool(other))
                    elif event.value == 0 and detector.release(key, time.monotonic()):
                        if session_unlocked():
                            print('tap', flush=True)
                elif event.type == e.EV_KEY or event.type == e.EV_REL:
                    detector.cancel()


if __name__ == '__main__':
    try:
        run()
    except KeyboardInterrupt:
        pass
