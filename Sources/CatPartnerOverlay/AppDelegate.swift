import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let displaySize = NSSize(width: 160, height: 160)
    private let pawHold: TimeInterval = 0.12  // how long a paw stays down per input
    private let positionKey = "windowOrigin"

    private var window: NSPanel!
    private var imageView: NSImageView!
    private var sprites: SpriteSet!
    private var statusItem: NSStatusItem!
    private var tap: CFMachPort?
    private var retryTimer: Timer?
    private var resetTimer: Timer?
    private var nextIsLeft = true

    private var visibilityItem: NSMenuItem!
    private var onTopItem: NSMenuItem!
    private var permissionItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let set = SpriteSet.load() else {
            NSLog("No sprites found. Run: swift tools/gen_sprites.swift")
            NSApp.terminate(nil)
            return
        }
        sprites = set
        buildWindow()
        buildMenu()
        startInputMonitor()
    }

    // MARK: - Window

    private func buildWindow() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: displaySize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isMovableByWindowBackground = true  // drag the cat anywhere
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        imageView = NSImageView(frame: NSRect(origin: .zero, size: displaySize))
        imageView.image = sprites.idle
        imageView.imageScaling = .scaleProportionallyUpOrDown
        panel.contentView = imageView

        panel.setFrameOrigin(restoredOrigin() ?? defaultOrigin())
        panel.orderFrontRegardless()
        window = panel

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowMoved),
            name: NSWindow.didMoveNotification, object: panel)
    }

    private func defaultOrigin() -> NSPoint {
        let area = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 800, height: 600)
        return NSPoint(x: area.maxX - displaySize.width - 40, y: area.minY + 20)
    }

    /// Saved position, only if it is still on a connected screen.
    private func restoredOrigin() -> NSPoint? {
        guard let arr = UserDefaults.standard.array(forKey: positionKey) as? [Double], arr.count == 2 else { return nil }
        let rect = NSRect(origin: NSPoint(x: arr[0], y: arr[1]), size: displaySize)
        return NSScreen.screens.contains { $0.visibleFrame.intersects(rect) } ? rect.origin : nil
    }

    @objc private func windowMoved() {
        let o = window.frame.origin
        UserDefaults.standard.set([Double(o.x), Double(o.y)], forKey: positionKey)
    }

    // MARK: - Input -> animation

    private func startInputMonitor() {
        // A listen-only CGEventTap needs ONLY Input Monitoring (NSEvent global monitors
        // also required Accessibility). We never read which key was pressed, only that
        // a key/click event occurred.
        if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }
        installTap()
        // Creating the tap fails until permission is granted; keep retrying so no relaunch is needed.
        if tap == nil {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
                self?.installTap()
                if self?.tap != nil { t.invalidate() }
            }
        }
    }

    private func installTap() {
        guard tap == nil else { return }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
            switch type {
            case .tapDisabledByTimeout, .tapDisabledByUserInput:
                if let tap = me.tap { CGEvent.tapEnable(tap: tap, enable: true) }  // macOS turned it off; re-enable
            case .keyDown:
                if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { me.pawHit() }
            default:
                me.pawHit()
            }
            return Unmanaged.passUnretained(event)  // listen-only: never modify or swallow events
        }
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("Event tap not created (Input Monitoring not granted yet?)")
            return
        }
        tap = newTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        NSLog("Event tap installed")
    }

    private func pawHit() {
        imageView.image = nextIsLeft ? sprites.left : sprites.right
        nextIsLeft.toggle()
        resetTimer?.invalidate()
        resetTimer = Timer.scheduledTimer(withTimeInterval: pawHold, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.imageView.image = self.sprites.idle
        }
    }

    // MARK: - Menu bar

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Cat")

        let menu = NSMenu()
        menu.delegate = self
        permissionItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        visibilityItem = menu.addItem(withTitle: "Hide Cat", action: #selector(toggleVisible), keyEquivalent: "")
        onTopItem = menu.addItem(withTitle: "Always on Top", action: #selector(toggleOnTop), keyEquivalent: "")
        onTopItem.state = .on
        menu.addItem(withTitle: "Reset Position", action: #selector(resetPosition), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Sprites Folder", action: #selector(openSpritesFolder), keyEquivalent: "")
        menu.addItem(withTitle: "Input Monitoring Settings…", action: #selector(openPrivacySettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = $0.action == #selector(NSApplication.terminate(_:)) ? NSApp : self }
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // A tap can exist without Input Monitoring (it then only delivers mouse events),
        // so report the permission state itself, not just whether the tap was created.
        let granted = CGPreflightListenEventAccess()
        switch (tap != nil, granted) {
        case (true, true):  permissionItem.title = "Typing: listening ✓"
        case (true, false): permissionItem.title = "⚠️ Clicks only: Input Monitoring not active for this build"
        default:            permissionItem.title = "⚠️ Not listening: grant Input Monitoring"
        }
    }

    @objc private func toggleVisible() {
        if window.isVisible {
            window.orderOut(nil); visibilityItem.title = "Show Cat"
        } else {
            window.orderFrontRegardless(); visibilityItem.title = "Hide Cat"
        }
    }

    @objc private func toggleOnTop() {
        let on = onTopItem.state != .on
        onTopItem.state = on ? .on : .off
        window.level = on ? .floating : .normal
    }

    @objc private func resetPosition() {
        window.setFrameOrigin(defaultOrigin())
    }

    @objc private func openSpritesFolder() {
        let dir = SpriteSet.userFolder
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    @objc private func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }
}
