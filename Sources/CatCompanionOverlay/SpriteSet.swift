import AppKit

/// The three cat frames for one skin. Skins are the bundled sprite sets plus an optional
/// "custom" set the user drops into the Application Support folder.
struct SpriteSet {
    let idle: NSImage
    let left: NSImage
    let right: NSImage

    static let names = ["idle", "left", "right"]

    struct Skin {
        let id: String
        let title: String
        let folder: String  // subfolder of the bundled sprites dir; "" = the dir itself
    }

    static let bundledSkins = [
        Skin(id: "orange", title: "Orange Tabby", folder: ""),
        Skin(id: "gray_tabby", title: "Gray Tabby", folder: "gray_tabby"),
        Skin(id: "tortie", title: "Tortie", folder: "tortie"),
        Skin(id: "calico", title: "Calico", folder: "calico"),
    ]
    static let customID = "custom"

    /// ~/Library/Application Support/CatCompanionOverlay/sprites
    static var userFolder: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CatCompanionOverlay/sprites", isDirectory: true)
    }

    /// True when the user folder holds a complete idle/left/right set.
    static var hasCustom: Bool {
        names.allSatisfy { FileManager.default.fileExists(atPath: userFolder.appendingPathComponent("\($0).png").path) }
    }

    /// Bundled sprites: inside a packaged .app (Contents/Resources/sprites), else the SwiftPM
    /// resource bundle (only when run via `swift run`).
    private static var bundledRoot: URL? {
        if let dir = Bundle.main.resourceURL?.appendingPathComponent("sprites"),
           FileManager.default.fileExists(atPath: dir.appendingPathComponent("idle.png").path) { return dir }
        // Bundle.module traps if its bundle is missing, so only touch it as a last resort.
        return Bundle.module.resourceURL?.appendingPathComponent("sprites")
    }

    static func load(id: String) -> SpriteSet? {
        if id == customID { return load(from: userFolder) }
        guard let skin = bundledSkins.first(where: { $0.id == id }), let root = bundledRoot else { return nil }
        return load(from: skin.folder.isEmpty ? root : root.appendingPathComponent(skin.folder))
    }

    /// Startup choice: the saved skin, else the custom set if one exists (the old behaviour), else orange.
    static func loadInitial(savedID: String?) -> (id: String, set: SpriteSet)? {
        for id in [savedID, hasCustom ? customID : nil, bundledSkins[0].id].compactMap({ $0 }) {
            if let set = load(id: id) { return (id, set) }
        }
        return nil
    }

    private static func load(from dir: URL) -> SpriteSet? {
        // All-or-nothing: a partial set is treated as missing.
        let images = names.compactMap { NSImage(contentsOf: dir.appendingPathComponent("\($0).png")) }
        guard images.count == names.count else { return nil }
        return SpriteSet(idle: images[0], left: images[1], right: images[2])
    }
}
