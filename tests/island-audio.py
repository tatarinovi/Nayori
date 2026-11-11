"""Broadband output level is amplitude-based, independent of spectral bands."""
import importlib.util
import math
from pathlib import Path
import struct
import unittest

spec = importlib.util.spec_from_file_location('island_audio', Path(__file__).resolve().parents[1] / 'scripts/island-audio.py')
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)


class VolumeTests(unittest.TestCase):
    def test_silence_and_empty(self):
        self.assertEqual(audio.pcm_rms(b''), 0)
        self.assertEqual(audio.pcm_rms(bytes(3200)), 0)

    def test_amplitude(self):
        self.assertAlmostEqual(audio.pcm_rms(struct.pack('<hhhh', 16384, -16384, 16384, -16384)), .5)

    def test_equal_loudness_bass_and_treble(self):
        for frequency in (100, 3000):
            wave = b''.join(struct.pack('<h', round(10000 * math.sin(2 * math.pi * frequency * i / 48000))) for i in range(4800))
            self.assertAlmostEqual(audio.pcm_rms(wave), 10000 / 32768 / math.sqrt(2), places=4)

    def test_scope_is_signed_and_keeps_opposite_phase_channel(self):
        wave = audio.pcm_waveform(struct.pack('<hhhhhhhh', 16000, -16000, -16000, 16000,
                                              16000, -16000, -16000, 16000), count=4)
        self.assertEqual(len(wave), 4)
        self.assertGreater(max(wave), .4)
        self.assertLess(min(wave), -.4)

    def test_scope_empty_and_short_buffers(self):
        self.assertEqual(audio.pcm_waveform(b''), [0.0] * 128)
        self.assertEqual(len(audio.pcm_waveform(b'\0')), 128)

    def test_full_spectrum_folds_for_legacy_consumers(self):
        self.assertEqual(audio.fold_bands([.25] * 128), [.25] * 48)

    def test_stereo_opposite_phase_does_not_cancel(self):
        self.assertAlmostEqual(audio.pcm_rms(struct.pack('<hhhh', 16384, -16384, 16384, -16384)), .5)


if __name__ == '__main__':
    unittest.main()
