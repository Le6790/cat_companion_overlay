"""Where the cat window goes. Pure functions over (x, y, w, h) tuples so they are unit-testable."""
from __future__ import annotations

Rect = tuple[int, int, int, int]


def _intersects(a: Rect, b: Rect) -> bool:
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]


def default_position(size: tuple[int, int], area: Rect) -> tuple[int, int]:
    """Bottom-right of the work area (excludes the taskbar), 40px from the right and 20px up."""
    return area[0] + area[2] - size[0] - 40, area[1] + area[3] - size[1] - 20


def restored_position(saved, size: tuple[int, int], screens: list[Rect]) -> tuple[int, int] | None:
    """The saved position, only if the window would still be on a connected screen."""
    try:
        x, y = int(saved[0]), int(saved[1])
    except (TypeError, ValueError, IndexError, KeyError):
        return None
    window = (x, y, size[0], size[1])
    return (x, y) if any(_intersects(window, s) for s in screens) else None
