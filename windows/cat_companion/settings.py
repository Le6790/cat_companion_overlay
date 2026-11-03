from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Any

from .paths import data_dir

log = logging.getLogger(__name__)


class Settings:
    """Tiny JSON store (%APPDATA%\\CatCompanionOverlay\\settings.json). Never raises: a missing or
    corrupt file just means defaults."""

    def __init__(self, path: Path | None = None):
        self.path = path or data_dir() / "settings.json"
        self._data: dict[str, Any] = {}
        try:
            loaded = json.loads(self.path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                self._data = loaded
        except FileNotFoundError:
            pass
        except (OSError, ValueError) as e:
            log.warning("Ignoring unreadable settings %s: %s", self.path, e)

    def get(self, key: str, default: Any = None) -> Any:
        return self._data.get(key, default)

    def set(self, key: str, value: Any) -> None:
        self._data[key] = value
        self._save()

    def _save(self) -> None:
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self.path.with_suffix(".tmp")
            tmp.write_text(json.dumps(self._data, indent=2), encoding="utf-8")
            os.replace(tmp, self.path)  # atomic, so a crash never leaves half a file
        except OSError as e:
            log.warning("Could not save settings: %s", e)
