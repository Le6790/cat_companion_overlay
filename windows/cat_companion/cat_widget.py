from __future__ import annotations

from PySide6.QtCore import QPoint, QRectF, Qt, Signal
from PySide6.QtGui import QColor, QFont, QFontMetrics, QPainter
from PySide6.QtWidgets import QWidget

from .sprites import SpriteSet

# Text area on the table, as fractions of the 256x256 sprite, top-left origin. Same area as
# CatView.swift (y 220..248 of 256): the lower body of the table, below the lip line.
TEXT_AREA = (14 / 256, 220 / 256, 228 / 256, 28 / 256)
TEXT_COLOR = QColor(255, 242, 217)  # cream, as on macOS


class CatWidget(QWidget):
    """Transparent, frameless, always-on-top cat. Drag with the left mouse button."""

    drag_finished = Signal()

    def __init__(self, sprites: SpriteSet, size: int = 160) -> None:
        super().__init__(
            None,
            Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool  # Tool: no taskbar button
            | Qt.WindowDoesNotAcceptFocus,  # clicking the cat never steals focus from what you're typing in
        )
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAttribute(Qt.WA_ShowWithoutActivating)
        self.setFixedSize(size, size)
        self._sprites = sprites
        self._frame = sprites.idle
        self._count = 0
        self._drag_offset = QPoint()

    # --- state -----------------------------------------------------------------------------
    def set_sprites(self, sprites: SpriteSet) -> None:
        self._sprites = sprites
        self._frame = sprites.idle
        self.update()

    def show_frame(self, which: str) -> None:  # "idle" | "left" | "right"
        self._frame = getattr(self._sprites, which)
        self.update()

    def set_count(self, count: int) -> None:
        self._count = count
        self.update()

    def set_always_on_top(self, on: bool) -> None:
        was_visible = self.isVisible()
        self.setWindowFlag(Qt.WindowStaysOnTopHint, on)  # changing a flag hides the window
        if was_visible:
            self.show()

    # --- painting --------------------------------------------------------------------------
    def paintEvent(self, _event) -> None:
        p = QPainter(self)
        p.setRenderHints(QPainter.Antialiasing | QPainter.SmoothPixmapTransform | QPainter.TextAntialiasing)
        p.drawPixmap(QRectF(self.rect()), self._frame, QRectF(self._frame.rect()))
        self._draw_counter(p)

    def _draw_counter(self, p: QPainter) -> None:
        w, h = self.width(), self.height()
        area = QRectF(TEXT_AREA[0] * w, TEXT_AREA[1] * h, TEXT_AREA[2] * w, TEXT_AREA[3] * h)
        font = QFont("Segoe UI")
        font.setBold(True)
        font.setPixelSize(max(8, round(area.height() * 0.7)))
        p.setFont(font)
        text = f"Boops: {self._count}"
        # Center by font metrics (not AlignCenter's line box) so digits sit mid-table regardless of font.
        fm = QFontMetrics(font)
        x = area.center().x() - fm.horizontalAdvance(text) / 2
        y = area.center().y() + (fm.ascent() - fm.descent()) / 2
        p.setPen(QColor(0, 0, 0, 128))
        p.drawText(QPoint(round(x), round(y) + 1), text)  # soft shadow
        p.setPen(TEXT_COLOR)
        p.drawText(QPoint(round(x), round(y)), text)

    # --- dragging --------------------------------------------------------------------------
    def mousePressEvent(self, event) -> None:
        if event.button() == Qt.LeftButton:
            self._drag_offset = event.globalPosition().toPoint() - self.frameGeometry().topLeft()

    def mouseMoveEvent(self, event) -> None:
        if event.buttons() & Qt.LeftButton:
            self.move(event.globalPosition().toPoint() - self._drag_offset)

    def mouseReleaseEvent(self, event) -> None:
        if event.button() == Qt.LeftButton:
            self.drag_finished.emit()  # save the position once per drag, not on every move
