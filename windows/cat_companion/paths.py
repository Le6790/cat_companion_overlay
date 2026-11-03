from __future__ import annotations

import os
import sys
from pathlib import Path


def sprites_root() -> Path:
    """Bundled sprites: inside the PyInstaller bundle, else the repo's shared macOS/Windows sprite dir."""
    if getattr(sys, "frozen", False):
        return Path(sys._MEIPASS) / "sprites"  # type: ignore[attr-defined]
    # windows/cat_companion/paths.py -> repo root is parents[2]
    return Path(__file__).resolve().parents[2] / "Sources" / "CatCompanionOverlay" / "sprites"


def data_dir() -> Path:
    """%APPDATA%\\CatCompanionOverlay (falls back to ~/.config when APPDATA is unset, e.g. when testing elsewhere)."""
    base = os.environ.get("APPDATA")
    return (Path(base) if base else Path.home() / ".config") / "CatCompanionOverlay"
