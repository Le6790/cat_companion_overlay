"""Key-press counter rules and key classification. Pure Python (no Qt, no pynput import)."""
from __future__ import annotations

import time
from typing import Callable, Hashable

# pynput names for keys that are modifiers on their own. The macOS version never counted these
# (they arrive as flagsChanged, not keyDown), so neither do we.
MODIFIER_NAMES = frozenset({
    "shift", "shift_l", "shift_r", "ctrl", "ctrl_l", "ctrl_r", "alt", "alt_l", "alt_r", "alt_gr",
    "cmd", "cmd_l", "cmd_r", "caps_lock",
})


def classify_key(key) -> tuple[bool, bool]:
    """(is_backspace, is_modifier). Only Backspace is ever distinguished; nothing is stored or logged.

    pynput gives special keys as `Key.<name>` enum members (which have `.name`) and ordinary
    keys as `KeyCode` (which do not).
    """
    name = getattr(key, "name", None)
    return name == "backspace", name in MODIFIER_NAMES


class RepeatTracker:
    """pynput reports auto-repeat as extra press events with no release in between.

    A press of a key we saw pressed less than `stale_after` seconds ago is a repeat. The staleness
    window recovers from a lost release (e.g. key let go while an elevated window had focus, which
    Windows hides from our hook): the next genuine press, long after, counts as new.
    """

    def __init__(self, stale_after: float = 1.5, clock: Callable[[], float] = time.monotonic):
        self._stale_after = stale_after
        self._clock = clock
        self._last: dict[Hashable, float] = {}

    def press(self, key: Hashable) -> bool:
        now = self._clock()
        last = self._last.get(key)
        self._last[key] = now
        return last is not None and now - last <= self._stale_after

    def release(self, key: Hashable) -> None:
        self._last.pop(key, None)


class KeyCounter:
    """Net count: +1 per non-repeat key press, -1 per Backspace (clamped at 0). Same rules as macOS."""

    def __init__(self) -> None:
        self.count = 0

    def key_down(self, *, is_backspace: bool, is_repeat: bool) -> bool:
        """Apply one key press. Returns True if the paw should animate."""
        if is_backspace:
            self.count = max(0, self.count - 1)  # a held Backspace keeps decrementing
            return not is_repeat
        if is_repeat:
            return False
        self.count += 1
        return True

    def reset(self) -> None:
        self.count = 0
