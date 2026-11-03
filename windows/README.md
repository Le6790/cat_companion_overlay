# Cat Companion Overlay: Windows 11

Port of the macOS app in this repo. A transparent, always-on-top cat sits on your desktop, slaps its
paws when you type or click, and shows **Boops: N** on its table (+1 per key press, -1 per Backspace,
never below 0). Python 3 + PySide6 (Qt) for the window and tray, `pynput` for global input.

It shares the sprites with the macOS app: `Sources/CatCompanionOverlay/sprites/` (regenerate them on a Mac with
`swift tools/gen_sprites.swift`; there is no Windows generator).

## Requirements
- Windows 11, Python 3.10+ from python.org (tick "Add python.exe to PATH", or use the `py` launcher)

## Run from source (PowerShell, from the repo root)
```powershell
cd windows
py -3 -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements.txt
.\.venv\Scripts\python main.py
```

## Build the .exe
```powershell
powershell -File windows\build_exe.ps1            # -> windows\dist\CatCompanionOverlay.exe  (single file)
powershell -File windows\build_exe.ps1 -OneDir    # -> windows\dist\CatCompanionOverlay\     (folder)
```
Single-file builds unpack themselves on every launch, so they start slower (a few seconds) and are more
likely to be flagged by antivirus (unsigned PyInstaller + a global input hook looks like a keylogger to some
scanners). If that happens, use `-OneDir`, or add an exclusion for the folder. The build never leaves the
repo's `windows/` folder (`.venv`, `build`, `dist` are gitignored).

## Using it
The cat has **no taskbar button**; look for the cat icon in the system tray (Windows 11 may hide it under
the `^` overflow arrow; drag it out to keep it visible). Right-click it for the menu:

| Item | What it does |
|---|---|
| Typing: listening ✓ | Status line. A warning here means the input hooks died (check the log) |
| Cat ▸ | Orange Tabby / Gray Tabby / Tortie / Calico / Custom. Switches instantly, remembered |
| Hide / Show Cat | Toggle the overlay |
| Always on Top | On by default |
| Reset Position / Reset Counter | Counter is not saved; it starts at 0 each launch |
| Open Sprites Folder | `%APPDATA%\CatCompanionOverlay\sprites`: drop `idle.png`, `left.png`, `right.png` (all three) to get a **Custom** entry |
| Quit | |

Drag the cat with the left mouse button; its position is saved when you let go.

## Files and where things live
| Path | Purpose |
|---|---|
| `main.py` | Entry point, also the PyInstaller target |
| `cat_companion/app.py` | Wiring: window, hooks, counter, tray menu, settings |
| `cat_companion/cat_widget.py` | The transparent window, sprite + counter painting, dragging |
| `cat_companion/input_monitor.py` | Global keyboard/mouse hooks (pynput) -> Qt signals |
| `cat_companion/counter.py` | Counter rules, key classification, auto-repeat detection (no Qt) |
| `cat_companion/skins.py`, `sprites.py` | Skin list and startup order (same as macOS), pixmap loading |
| `cat_companion/settings.py`, `placement.py` | JSON settings; window position rules |
| `tests/test_logic.py` | Unit tests for everything that doesn't need a display |
| `%APPDATA%\CatCompanionOverlay\settings.json` | Saved skin and position |
| `%APPDATA%\CatCompanionOverlay\log.txt` | Errors (the exe has no console) |

Tests (any OS, from the repo root): `python -m unittest discover -s windows/tests -t windows`

## Behaviour notes and limits
- **Elevated windows:** Windows does not show keystrokes to a hook while an administrator (elevated)
  window has focus, so typing into one isn't counted. Running the cat as admin works around it but isn't recommended.
- **Input is listen-only** and needs no special permission. Only "was it Backspace?" and "is it a modifier?" are
  checked; keys are never stored or logged.
- **Not counted:** mouse clicks (they animate a paw only), Shift/Ctrl/Alt/Win/Caps Lock alone. Held keys count once;
  a held Backspace keeps subtracting. Delete counts as +1 (same as macOS).
- **Auto-repeat:** pynput has no repeat flag, so a press with no release since the last press (within 1.5 s) is
  treated as a repeat.
- No launch-at-login, installer or auto-update yet (same as macOS).
