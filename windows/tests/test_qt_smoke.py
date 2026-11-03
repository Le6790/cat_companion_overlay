"""Qt smoke tests, run headless (offscreen platform). Skipped when PySide6 isn't installed.

They cover rendering and the app wiring (menu, skin switching, counter) but NOT real Windows
behaviour: the global hooks are stubbed, and transparency/tray need a real desktop to verify.
"""
import os
import tempfile
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

try:
    from PySide6.QtWidgets import QApplication
    HAVE_QT = True
except ImportError:  # pragma: no cover
    HAVE_QT = False


@unittest.skipUnless(HAVE_QT, "PySide6 not installed")
class QtSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])
        cls._tmp = tempfile.TemporaryDirectory()
        os.environ["APPDATA"] = cls._tmp.name  # settings/custom sprites go to a throwaway dir

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def test_every_skin_renders_transparent_with_counter_text(self):
        from cat_companion import sprites, skins
        from cat_companion.cat_widget import CatWidget
        for skin in skins.BUNDLED_SKINS:
            loaded = sprites.load_skin(skin.id)
            self.assertIsNotNone(loaded, skin.id)
            w = CatWidget(loaded, 160)
            img0 = w.grab().toImage()
            self.assertEqual(img0.pixelColor(0, 0).alpha(), 0, "corner should be transparent")
            w.set_count(1234)
            img1 = w.grab().toImage()
            self.assertNotEqual(img0, img1, f"{skin.id}: counter text did not change the render")

    def test_overlay_wiring(self):
        from cat_companion import app as appmod
        from cat_companion.input_monitor import InputMonitor
        original_start = InputMonitor.start
        InputMonitor.start = lambda self: None  # don't install real global hooks in tests
        try:
            o = appmod.Overlay(self.app)
        finally:
            InputMonitor.start = original_start
        self.addCleanup(o.tray.hide)
        # counter: keys +1, backspace -1, repeat ignored
        o._on_key(False, False); o._on_key(False, False); o._on_key(False, True)
        self.assertEqual(o.counter.count, 2)
        o._on_key(True, False)
        self.assertEqual(o.counter.count, 1)
        # paw alternates left/right on hits
        o._paw_hit(); first = o.cat._frame
        o._paw_hit(); self.assertIsNot(o.cat._frame, first)
        # skin switching persists and updates the checked item
        o.select_skin("tortie")
        o._refresh_menu()
        self.assertTrue(o.skin_actions["tortie"].isChecked())
        self.assertFalse(o.skin_actions["custom"].isVisible(), "no custom sprites folder -> entry hidden")
        self.assertEqual(appmod.Settings().get("skin"), "tortie")
        o._reset_counter()
        self.assertEqual(o.counter.count, 0)


if __name__ == "__main__":
    unittest.main()
