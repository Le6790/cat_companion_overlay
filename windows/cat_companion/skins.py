"""Skin list and the rules for choosing one. Pure Python (no Qt) so it is unit-testable.

Mirrors Sources/CatCompanionOverlay/SpriteSet.swift: the same ids, the same sprite folders, and the
same startup order (saved choice -> custom folder if present -> orange).
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .paths import data_dir

NAMES = ("idle", "left", "right")
CUSTOM_ID = "custom"


@dataclass(frozen=True)
class Skin:
    id: str
    title: str
    folder: str  # subfolder of the bundled sprites dir; "" = the dir itself


BUNDLED_SKINS = (
    Skin("orange", "Orange Tabby", ""),
    Skin("gray_tabby", "Gray Tabby", "gray_tabby"),
    Skin("tortie", "Tortie", "tortie"),
    Skin("calico", "Calico", "calico"),
)


def user_folder() -> Path:
    """Custom sprites: %APPDATA%\\CatCompanionOverlay\\sprites"""
    return data_dir() / "sprites"


def is_complete(directory: Path) -> bool:
    """All-or-nothing: a folder missing any of idle/left/right is treated as absent."""
    return all((directory / f"{n}.png").is_file() for n in NAMES)


def skin_directory(skin_id: str, bundled_root: Path, custom_dir: Path) -> Path | None:
    if skin_id == CUSTOM_ID:
        return custom_dir
    for skin in BUNDLED_SKINS:
        if skin.id == skin_id:
            return bundled_root / skin.folder if skin.folder else bundled_root
    return None


def startup_candidates(saved_id: str | None, custom_available: bool) -> list[str]:
    """Order to try at launch; the first that loads wins."""
    out = [saved_id] if saved_id else []
    if custom_available:
        out.append(CUSTOM_ID)
    out.append(BUNDLED_SKINS[0].id)
    return out
