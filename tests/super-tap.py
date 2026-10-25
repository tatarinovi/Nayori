"""Pure input-state checks: no device access and no session actions."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('super_tap', Path(__file__).resolve().parents[1] / 'services/system/super_tap.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SuperTapTests(unittest.TestCase):
    def setUp(self):
        self.detector = module.TapDetector()

    def test_single_tap(self):
        self.detector.press(('kbd', 125), 1)
        self.assertTrue(self.detector.release(('kbd', 125), 1.2))

    def test_hold(self):
        self.detector.press(('kbd', 125), 1)
        self.assertFalse(self.detector.release(('kbd', 125), 1.8))

    def test_shortcut_or_pointer_activity(self):
        self.detector.press(('kbd', 125), 1)
        self.detector.cancel()
        self.assertFalse(self.detector.release(('kbd', 125), 1.1))

    def test_preexisting_modifier(self):
        self.detector.press(('kbd', 125), 1, other_held=True)
        self.assertFalse(self.detector.release(('kbd', 125), 1.1))

    def test_two_super_keys(self):
        self.detector.press(('kbd1', 125), 1)
        self.detector.press(('kbd2', 126), 1.05)
        self.assertFalse(self.detector.release(('kbd1', 125), 1.1))
        self.assertFalse(self.detector.release(('kbd2', 126), 1.15))

    def test_device_disconnect_or_event_loss(self):
        self.detector.press(('kbd', 125), 1)
        self.detector.reset()
        self.assertFalse(self.detector.release(('kbd', 125), 1.1))
        self.detector.press(('kbd', 125), 2)
        self.assertTrue(self.detector.release(('kbd', 125), 2.1))

    def test_release_without_press(self):
        self.assertFalse(self.detector.release(('kbd', 125), 1))

    def test_repeated_keydown_does_not_restart_threshold(self):
        self.detector.press(('kbd', 125), 1)
        self.detector.press(('kbd', 125), 1.5)
        self.assertFalse(self.detector.release(('kbd', 125), 1.6))


if __name__ == '__main__':
    unittest.main()
