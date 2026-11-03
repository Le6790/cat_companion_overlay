"""Pure-logic tests (no Qt, no hooks). Run from windows/:  python -m unittest discover -s tests -t ."""
import json
import tempfile
import unittest
from enum import Enum
from pathlib import Path

from cat_companion import placement, skins
from cat_companion.counter import KeyCounter, RepeatTracker, classify_key
from cat_companion.settings import Settings


class FakeKey(Enum):  # stands in for pynput.keyboard.Key (members have .name)
    backspace = 1
    shift = 2
    enter = 3


class FakeKeyCode:  # stands in for pynput.keyboard.KeyCode (no .name)
    def __init__(self, char):
        self.char = char


class KeyCounterTests(unittest.TestCase):
    def test_increments_and_decrements(self):
        c = KeyCounter()
        for _ in range(3):
            self.assertTrue(c.key_down(is_backspace=False, is_repeat=False))
        self.assertEqual(c.count, 3)
        c.key_down(is_backspace=True, is_repeat=False)
        self.assertEqual(c.count, 2)

    def test_clamped_at_zero(self):
        c = KeyCounter()
        c.key_down(is_backspace=True, is_repeat=False)
        self.assertEqual(c.count, 0)

    def test_held_key_counts_once_but_held_backspace_keeps_decrementing(self):
        c = KeyCounter()
        for _ in range(5):
            c.key_down(is_backspace=False, is_repeat=False)
        self.assertFalse(c.key_down(is_backspace=False, is_repeat=True))
        self.assertEqual(c.count, 5)
        self.assertFalse(c.key_down(is_backspace=True, is_repeat=True))  # no paw on repeat...
        self.assertTrue(c.key_down(is_backspace=True, is_repeat=False))
        self.assertEqual(c.count, 3)  # ...but both decremented

    def test_reset(self):
        c = KeyCounter()
        c.key_down(is_backspace=False, is_repeat=False)
        c.reset()
        self.assertEqual(c.count, 0)


class ClassifyTests(unittest.TestCase):
    def test_backspace_modifier_and_plain(self):
        self.assertEqual(classify_key(FakeKey.backspace), (True, False))
        self.assertEqual(classify_key(FakeKey.shift), (False, True))
        self.assertEqual(classify_key(FakeKey.enter), (False, False))
        self.assertEqual(classify_key(FakeKeyCode("a")), (False, False))


class RepeatTrackerTests(unittest.TestCase):
    def setUp(self):
        self.now = 0.0
        self.t = RepeatTracker(stale_after=1.5, clock=lambda: self.now)

    def test_second_press_without_release_is_a_repeat(self):
        self.assertFalse(self.t.press("a"))
        self.now = 0.5
        self.assertTrue(self.t.press("a"))
        self.now = 0.53
        self.assertTrue(self.t.press("a"))

    def test_release_resets(self):
        self.t.press("a")
        self.t.release("a")
        self.now = 0.1
        self.assertFalse(self.t.press("a"))

    def test_lost_release_recovers_after_stale_window(self):
        self.t.press("a")  # release never seen
        self.now = 10.0
        self.assertFalse(self.t.press("a"))

    def test_keys_are_independent(self):
        self.t.press("a")
        self.assertFalse(self.t.press("b"))


class SkinTests(unittest.TestCase):
    def test_startup_order(self):
        self.assertEqual(skins.startup_candidates("tortie", True), ["tortie", "custom", "orange"])
        self.assertEqual(skins.startup_candidates(None, True), ["custom", "orange"])
        self.assertEqual(skins.startup_candidates(None, False), ["orange"])

    def test_directories(self):
        root, custom = Path("/b"), Path("/c")
        self.assertEqual(skins.skin_directory("orange", root, custom), root)
        self.assertEqual(skins.skin_directory("calico", root, custom), root / "calico")
        self.assertEqual(skins.skin_directory("custom", root, custom), custom)
        self.assertIsNone(skins.skin_directory("nope", root, custom))

    def test_is_complete_is_all_or_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            for n in ("idle", "left"):
                (d / f"{n}.png").write_bytes(b"x")
            self.assertFalse(skins.is_complete(d))
            (d / "right.png").write_bytes(b"x")
            self.assertTrue(skins.is_complete(d))

    def test_bundled_sprite_folders_exist_and_match_macos(self):
        from cat_companion.paths import sprites_root
        for skin in skins.BUNDLED_SKINS:
            d = sprites_root() / skin.folder if skin.folder else sprites_root()
            self.assertTrue(skins.is_complete(d), f"{skin.id} sprites missing in {d}")


class PlacementTests(unittest.TestCase):
    screens = [(0, 0, 1920, 1040), (1920, 0, 1280, 1024)]

    def test_default_is_bottom_right_of_work_area(self):
        self.assertEqual(placement.default_position((160, 160), (0, 0, 1920, 1040)), (1720, 860))

    def test_restores_only_if_on_a_connected_screen(self):
        self.assertEqual(placement.restored_position([2000, 100], (160, 160), self.screens), (2000, 100))
        self.assertIsNone(placement.restored_position([5000, 100], (160, 160), self.screens))
        self.assertIsNone(placement.restored_position(None, (160, 160), self.screens))
        self.assertIsNone(placement.restored_position(["x", 1], (160, 160), self.screens))


class SettingsTests(unittest.TestCase):
    def test_roundtrip_and_corrupt_file(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "sub" / "settings.json"
            s = Settings(p)
            self.assertIsNone(s.get("skin"))
            s.set("skin", "tortie")
            s.set("position", [1, 2])
            s2 = Settings(p)
            self.assertEqual((s2.get("skin"), s2.get("position")), ("tortie", [1, 2]))
            p.write_text("{not json")
            self.assertEqual(Settings(p).get("skin", "dflt"), "dflt")
            p.write_text(json.dumps([1, 2]))  # valid JSON, wrong shape
            self.assertEqual(Settings(p).get("skin", "dflt"), "dflt")


if __name__ == "__main__":
    unittest.main()
