"""Check the actual SwiftUI palette for readable foreground/background pairs."""
import re
import unittest
from pathlib import Path

THEME = Path(__file__).resolve().parents[1] / 'ios/MeinSpielraum/Theme.swift'
COLORS = dict(re.findall(r'static let (\w+) = Color\(hex: 0x([0-9A-F]{6})\)', THEME.read_text()))
def luminance(hex_color):
    values = [int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4)]
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values]
    return sum(v * w for v, w in zip(linear, (0.2126, 0.7152, 0.0722)))
def contrast(first, second):
    a, b = sorted((luminance(first), luminance(second)))
    return (b + 0.05) / (a + 0.05)
class DesignTests(unittest.TestCase):
    def test_body_and_secondary_text_on_all_content_surfaces(self):
        for foreground in ('text', 'muted'):
            for background in ('canvas', 'surface', 'soft'):
                with self.subTest(foreground=foreground, background=background):
                    self.assertGreaterEqual(contrast(COLORS[foreground], COLORS[background]), 4.5)
    def test_action_and_status_text_remain_readable(self):
        for foreground in ('mint', 'positive', 'warning', 'danger'):
            for background in ('surface', 'canvas'):
                with self.subTest(foreground=foreground, background=background):
                    self.assertGreaterEqual(contrast(COLORS[foreground], COLORS[background]), 4.5)
        for background in ('primary', 'primaryPressed'):
            self.assertGreaterEqual(contrast('FFFFFF', COLORS[background]), 7)
if __name__ == '__main__':
    unittest.main()
