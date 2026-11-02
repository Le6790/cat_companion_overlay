# Cat Partner Overlay

A Bongo-Cat-style desktop overlay for macOS. A small cat floats above your windows and
slaps the desk whenever you type or click, anywhere on the system.

- Swift 6.2 / AppKit, no third-party dependencies. macOS 13+.
- Menu bar only (no Dock icon). Drag the cat anywhere; position is remembered.

## Run

```bash
swift run                      # debug build; or
swift build -c release && .build/release/CatPartnerOverlay
```

### Packaged app (recommended)

```bash
scripts/build_app.sh          # -> dist/CatPartnerOverlay.app (bundle id com.kent.catpartneroverlay)
open dist/CatPartnerOverlay.app
```

Grant **Input Monitoring** to *Cat Partner Overlay* itself, not to your terminal. The app needs
**only Input Monitoring**; Accessibility is not required and should stay off.
The app is ad-hoc signed, so macOS may treat a rebuilt binary as new and re-ask for permission.
If the paw menu says "Clicks only" (clicks on the cat register, typing and outside clicks do not), the
grant is stale. Fix:

```bash
pkill CatPartnerOverlay
tccutil reset ListenEvent com.kent.catpartneroverlay
# delete any leftover row in System Settings > Input Monitoring, then:
open dist/CatPartnerOverlay.app    # accept the prompt, or add the app with +
```

Always launch with `open`; running the binary inside the bundle from a terminal makes the terminal the
permission holder. A stable self-signed certificate would stop rebuilds from invalidating the grant.

Menu status line: `Typing: listening ✓` (working), `Clicks only…` (grant not effective), `Not listening` (no tap).

### Permission (required once; applies to `swift run` only)

Reacting to keys typed in *other* apps needs **Input Monitoring**:
System Settings → Privacy & Security → Input Monitoring. The menu bar paw → "Input Monitoring
Settings…" jumps there. After granting, the cat starts reacting within a couple of seconds.

The permission attaches to **the app that launched the binary**. With `swift run` that is your
terminal (Terminal/iTerm/Ghostty). Grant it there. Without it, clicks still work, keys do not.

The app never reads which key was pressed, only that a key event occurred, and stores nothing.

## Menu bar

Hide/Show Cat · Always on Top · Reset Position · Open Sprites Folder · Input Monitoring Settings · Quit

## Sprites

Three 256x256 transparent PNGs: `idle.png`, `left.png`, `right.png`.

- Bundled placeholders: `Sources/CatPartnerOverlay/sprites/`, regenerated with
  `swift tools/gen_sprites.swift` (drawn with Core Graphics, so no copyrighted art).
- Override: put all three files in `~/Library/Application Support/CatPartnerOverlay/sprites/`
  (menu → Open Sprites Folder). A partial set is ignored and the bundled set is used.

## Layout

| Path | Purpose |
|---|---|
| `Sources/CatPartnerOverlay/main.swift` | Entry point, sets accessory activation policy |
| `.../AppDelegate.swift` | Overlay window, global input monitor, menu bar |
| `.../SpriteSet.swift` | Loads the 3 frames (user folder, then bundle) |
| `tools/gen_sprites.swift` | Placeholder sprite generator |

## Design decisions

- **Swift/AppKit over Python/Qt:** transparent non-activating windows and global event monitors are
  native in AppKit, tiny idle footprint, and it packages as a normal `.app`. Cost: Windows/Linux
  would be rewrites.
- **Listen-only `CGEventTap` (not `NSEvent.addGlobalMonitorForEvents`):** the NSEvent global monitor
  turned out to need Accessibility *and* Input Monitoring. A listen-only tap needs Input Monitoring
  only, so the app holds less privilege. The tap never modifies or swallows events, re-enables itself
  if macOS disables it, and retries every 2 s until permission is granted (no relaunch needed).
- **Alternating paws:** each input flips left/right and holds ~0.12 s, then returns to idle.
- **All-or-nothing sprite override:** avoids a half-skinned cat.

## Not yet done

Stable code-signing identity (so rebuilds keep their permission), launch at login, size setting, sound, multiple skins, Windows/Linux.
