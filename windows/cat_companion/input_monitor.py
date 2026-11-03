"""Global, listen-only keyboard and mouse hooks (pynput -> Windows low-level hooks).

No admin rights are needed. Windows does not deliver keystrokes to a hook while an elevated
(admin) window has focus, so typing into one is not counted.

Hook callbacks run on pynput's own threads; results reach the UI through Qt signals (queued onto
the main thread). Callbacks must never raise: pynput stops the listener if one does.
"""
from __future__ import annotations

import logging

from PySide6.QtCore import QObject, Signal

from .counter import RepeatTracker, classify_key

log = logging.getLogger(__name__)


class InputMonitor(QObject):
    key_pressed = Signal(bool, bool)  # is_backspace, is_repeat
    clicked = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._tracker = RepeatTracker()
        self._listeners: list = []

    def start(self) -> None:
        from pynput import keyboard, mouse  # imported here so tests and tooling never need a display/hook

        self._listeners = [
            keyboard.Listener(on_press=self._on_press, on_release=self._on_release),
            mouse.Listener(on_click=self._on_click),
        ]
        for listener in self._listeners:
            listener.start()  # daemon threads
        log.info("Input hooks started")

    def stop(self) -> None:
        for listener in self._listeners:
            listener.stop()
        self._listeners = []

    def is_running(self) -> bool:
        return bool(self._listeners) and all(l.is_alive() for l in self._listeners)

    def _on_press(self, key) -> None:
        try:
            is_backspace, is_modifier = classify_key(key)
            is_repeat = self._tracker.press(key)  # track modifiers too so release bookkeeping stays simple
            if not is_modifier:
                self.key_pressed.emit(is_backspace, is_repeat)
        except Exception:
            log.exception("key press handler failed")

    def _on_release(self, key) -> None:
        try:
            self._tracker.release(key)
        except Exception:
            log.exception("key release handler failed")

    def _on_click(self, x, y, button, pressed) -> None:
        try:
            if pressed and getattr(button, "name", "") in ("left", "right"):
                self.clicked.emit()
        except Exception:
            log.exception("click handler failed")
