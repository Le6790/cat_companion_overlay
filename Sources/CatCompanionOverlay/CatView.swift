import AppKit

/// Draws the current cat frame and lets you drag the whole window by clicking it.
/// Dragging is done by hand (rather than `isMovableByWindowBackground`) because NSImageView
/// swallows mouse-down events, and the window is a non-activating panel.
final class CatView: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }
    var counterText = "0" { didSet { needsDisplay = true } }

    // Text area on the table, as fractions of the 256x256 sprite (origin bottom-left).
    // Sits in the table's lower body (y 220...248 top-down), below the lip line at ~y 217,
    // and horizontally centered on the table (x 14...242).
    private let textArea = NSRect(x: 14.0 / 256, y: 8.0 / 256, width: 228.0 / 256, height: 28.0 / 256)

    private var dragStartMouse = NSPoint.zero
    private var dragStartOrigin = NSPoint.zero

    override var mouseDownCanMoveWindow: Bool { false }  // we handle the move ourselves
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }  // drag on the first click, no focus needed

    override func draw(_ dirtyRect: NSRect) {
        image?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        drawCounter()
    }

    private func drawCounter() {
        let area = NSRect(x: bounds.width * textArea.minX, y: bounds.height * textArea.minY,
                          width: bounds.width * textArea.width, height: bounds.height * textArea.height)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.5)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: area.height * 0.7, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 1, green: 0.95, blue: 0.85, alpha: 1),
            .shadow: shadow,
        ]
        let text = NSAttributedString(string: "Boops: \(counterText)", attributes: attrs)
        let size = text.size()
        text.draw(at: NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2))  // centered in the area
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStartMouse = NSEvent.mouseLocation  // screen coordinates, stable while the window moves
        dragStartOrigin = window.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let now = NSEvent.mouseLocation
        window.setFrameOrigin(NSPoint(
            x: dragStartOrigin.x + now.x - dragStartMouse.x,
            y: dragStartOrigin.y + now.y - dragStartMouse.y))
    }
}
