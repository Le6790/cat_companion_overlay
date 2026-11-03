from __future__ import annotations

import logging
from dataclasses import dataclass

from PySide6.QtGui import QPixmap

from . import skins
from .paths import sprites_root

log = logging.getLogger(__name__)


@dataclass
class SpriteSet:
    idle: QPixmap
    left: QPixmap
    right: QPixmap


def load_skin(skin_id: str) -> SpriteSet | None:
    directory = skins.skin_directory(skin_id, sprites_root(), skins.user_folder())
    if directory is None or not skins.is_complete(directory):
        return None
    pixmaps = [QPixmap(str(directory / f"{n}.png")) for n in skins.NAMES]
    if any(p.isNull() for p in pixmaps):
        log.warning("Skin %s has an unreadable PNG in %s", skin_id, directory)
        return None
    return SpriteSet(*pixmaps)


def load_initial(saved_id: str | None) -> tuple[str, SpriteSet] | None:
    for skin_id in skins.startup_candidates(saved_id, skins.is_complete(skins.user_folder())):
        sprites = load_skin(skin_id)
        if sprites:
            return skin_id, sprites
    return None
