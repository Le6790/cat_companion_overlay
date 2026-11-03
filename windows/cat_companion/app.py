from __future__ import annotations

import logging
import sys

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QAction, QActionGroup, QDesktopServices, QGuiApplication, QIcon
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

from . import placement, skins, sprites
from .cat_widget import CatWidget
from .counter import KeyCounter
from .input_monitor import InputMonitor
from .paths import data_dir
from .settings import Settings

log = logging.getLogger("cat_companion")

PAW_HOLD_MS = 120  # how long a paw stays down per input (same as macOS)
SIZE = 160


class Overlay:
    """Wires the window, input hooks, counter, tray menu and settings together."""

    def __init__(self, app: QApplication) -> None:
        self.app = app
        self.settings = Settings()
        self.counter = KeyCounter()
        self.next_is_left = True

        initial = sprites.load_initial(self.settings.get("skin"))
        if initial is None:
            raise RuntimeError("No sprites found (expected sprites/ next to the app or in the repo).")
        self.skin_id, loaded = initial

        self.cat = CatWidget(loaded, SIZE)
        self.cat.move(*self._initial_position())
        self.cat.drag_finished.connect(self._save_position)
        self.cat.show()

        self.paw_timer = QTimer()
        self.paw_timer.setSingleShot(True)
        self.paw_timer.timeout.connect(lambda: self.cat.show_frame("idle"))

        self._build_tray()

        self.monitor = InputMonitor()
        self.monitor.key_pressed.connect(self._on_key)
        self.monitor.clicked.connect(self._paw_hit)
        self.monitor.start()

    # --- position ------------------------------------------------------------------------------
    def _screens(self) -> list[placement.Rect]:
        return [(g.x(), g.y(), g.width(), g.height()) for g in (s.availableGeometry() for s in QGuiApplication.screens())]

    def _default_position(self) -> tuple[int, int]:
        area = QGuiApplication.primaryScreen().availableGeometry()
        return placement.default_position((SIZE, SIZE), (area.x(), area.y(), area.width(), area.height()))

    def _initial_position(self) -> tuple[int, int]:
        return placement.restored_position(self.settings.get("position"), (SIZE, SIZE), self._screens()) \
            or self._default_position()

    def _save_position(self) -> None:
        self.settings.set("position", [self.cat.x(), self.cat.y()])

    # --- input -> animation --------------------------------------------------------------------
    def _on_key(self, is_backspace: bool, is_repeat: bool) -> None:
        animate = self.counter.key_down(is_backspace=is_backspace, is_repeat=is_repeat)
        self.cat.set_count(self.counter.count)
        if animate:
            self._paw_hit()

    def _paw_hit(self) -> None:
        self.cat.show_frame("left" if self.next_is_left else "right")
        self.next_is_left = not self.next_is_left
        self.paw_timer.start(PAW_HOLD_MS)

    # --- tray menu -----------------------------------------------------------------------------
    def _build_tray(self) -> None:
        self.tray = QSystemTrayIcon(self._tray_icon())
        self.tray.setToolTip("Cat Companion Overlay")
        self.menu = QMenu()
        self.menu.aboutToShow.connect(self._refresh_menu)

        self.status_action = self.menu.addAction("")
        self.status_action.setEnabled(False)
        self.menu.addSeparator()

        skin_menu = self.menu.addMenu("Cat")
        group = QActionGroup(skin_menu)
        self.skin_actions: dict[str, QAction] = {}
        entries = [(s.id, s.title) for s in skins.BUNDLED_SKINS] + [(skins.CUSTOM_ID, "Custom (sprites folder)")]
        for skin_id, title in entries:
            action = skin_menu.addAction(title)
            action.setCheckable(True)
            group.addAction(action)
            action.triggered.connect(lambda _checked=False, sid=skin_id: self.select_skin(sid))
            self.skin_actions[skin_id] = action

        self.visibility_action = self.menu.addAction("Hide Cat")
        self.visibility_action.triggered.connect(self._toggle_visible)
        self.on_top_action = self.menu.addAction("Always on Top")
        self.on_top_action.setCheckable(True)
        self.on_top_action.setChecked(True)
        self.on_top_action.toggled.connect(self.cat.set_always_on_top)
        self.menu.addAction("Reset Position").triggered.connect(self._reset_position)
        self.menu.addAction("Reset Counter").triggered.connect(self._reset_counter)
        self.menu.addSeparator()
        self.menu.addAction("Open Sprites Folder").triggered.connect(self._open_sprites_folder)
        self.menu.addSeparator()
        self.menu.addAction("Quit").triggered.connect(self.quit)

        self.tray.setContextMenu(self.menu)
        self.tray.show()
        if not QSystemTrayIcon.isSystemTrayAvailable():
            log.warning("No system tray available")

    def _tray_icon(self) -> QIcon:
        return QIcon(self.cat._sprites.idle)  # the cat's face doubles as the icon

    def _refresh_menu(self) -> None:
        self.status_action.setText("Typing: listening ✓" if self.monitor.is_running()
                                   else "⚠ Not listening: input hook failed (see log)")
        self.skin_actions[skins.CUSTOM_ID].setVisible(skins.is_complete(skins.user_folder()))
        for skin_id, action in self.skin_actions.items():
            action.setChecked(skin_id == self.skin_id)
        self.visibility_action.setText("Hide Cat" if self.cat.isVisible() else "Show Cat")

    def select_skin(self, skin_id: str) -> None:
        loaded = sprites.load_skin(skin_id)
        if loaded is None:
            log.warning("Could not load skin %s", skin_id)
            return
        self.skin_id = skin_id
        self.cat.set_sprites(loaded)
        self.tray.setIcon(self._tray_icon())
        self.settings.set("skin", skin_id)

    def _toggle_visible(self) -> None:
        self.cat.hide() if self.cat.isVisible() else self.cat.show()

    def _reset_position(self) -> None:
        self.cat.move(*self._default_position())
        self._save_position()

    def _reset_counter(self) -> None:
        self.counter.reset()
        self.cat.set_count(0)

    def _open_sprites_folder(self) -> None:
        folder = skins.user_folder()
        folder.mkdir(parents=True, exist_ok=True)
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(folder)))

    def quit(self) -> None:
        self.monitor.stop()
        self.tray.hide()
        self.app.quit()


def _setup_logging() -> None:
    # The .exe is built --windowed (no console), so errors go to a file.
    try:
        data_dir().mkdir(parents=True, exist_ok=True)
        logging.basicConfig(filename=data_dir() / "log.txt", level=logging.INFO,
                            format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    except OSError:
        logging.basicConfig(level=logging.INFO)
    sys.excepthook = lambda t, v, tb: log.critical("Uncaught exception", exc_info=(t, v, tb))


def main() -> None:
    _setup_logging()
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)  # the cat can be hidden; the tray keeps the app alive
    overlay = Overlay(app)  # noqa: F841  (keep a reference so nothing is garbage-collected)
    sys.exit(app.exec())
