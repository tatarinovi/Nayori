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

    def test_same_key_from_two_interfaces_is_one_press(self):
        # Провод и донгл или boot и NKRO: один физический Super приходит дважды.
        self.detector.press(125, 1)
        self.detector.press(125, 1.001)
        self.assertTrue(self.detector.release(125, 1.1))
        self.assertFalse(self.detector.release(125, 1.101))

    def test_duplicate_interface_reports_do_not_double_fire(self):
        # Интерфейсы читаются по очереди: пара press/release первого, затем пара второго.
        self.detector.press(125, 1)
        self.assertTrue(self.detector.release(125, 1.05))
        self.detector.press(125, 1.052)
        self.assertFalse(self.detector.release(125, 1.054))

    def test_two_deliberate_taps_both_fire(self):
        self.detector.press(125, 1)
        self.assertTrue(self.detector.release(125, 1.1))
        self.detector.press(125, 1.6)
        self.assertTrue(self.detector.release(125, 1.7))

    def test_stale_press_is_dropped_by_reset(self):
        # Отпускание потерялось: следующий тап обязан сработать, а не погаснуть.
        self.detector.press(125, 1)
        self.detector.reset()
        self.detector.press(125, 5)
        self.assertTrue(self.detector.release(125, 5.1))

    def test_pointer_motion_does_not_cancel(self):
        self.assertFalse(module.cancels_tap(2, 0))
        self.assertFalse(module.cancels_tap(2, 1))

    def test_wheel_buttons_and_keys_cancel(self):
        self.assertTrue(module.cancels_tap(2, 8))
        self.assertTrue(module.cancels_tap(2, 11))
        self.assertTrue(module.cancels_tap(1, 272))
        self.assertTrue(module.cancels_tap(1, 30))
        self.assertFalse(module.cancels_tap(0, 0))


if __name__ == '__main__':
    unittest.main()
