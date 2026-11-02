import AppKit

/// The three cat frames. Loaded from a user override folder if complete,
/// otherwise from the sprites bundled with the app.
struct SpriteSet {
    let idle: NSImage
    let left: NSImage
    let right: NSImage

    static let names = ["idle", "left", "right"]

    /// ~/Library/Application Support/CatPartnerOverlay/sprites
    static var userFolder: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CatPartnerOverlay/sprites", isDirectory: true)
    }

    static func load() -> SpriteSet? {
        // 1. user override, 2. inside a packaged .app (Contents/Resources/sprites),
        // 3. SwiftPM resource bundle (only when run via `swift run`).
        if let set = load(from: userFolder) { return set }
        if let dir = Bundle.main.resourceURL?.appendingPathComponent("sprites"),
           let set = load(from: dir) { return set }
        // Bundle.module traps if its bundle is missing, so only touch it as a last resort.
        if let dir = Bundle.module.resourceURL?.appendingPathComponent("sprites") {
            return load(from: dir)
        }
        return nil
    }

    private static func load(from dir: URL) -> SpriteSet? {
        // All-or-nothing: a partial override folder falls through to the bundled set.
        let images = names.compactMap { NSImage(contentsOf: dir.appendingPathComponent("\($0).png")) }
        guard images.count == names.count else { return nil }
        return SpriteSet(idle: images[0], left: images[1], right: images[2])
    }
}
