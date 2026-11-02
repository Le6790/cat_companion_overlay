import AppKit

/// Draws the current cat frame and lets you drag the whole window by clicking it.
/// Dragging is done by hand (rather than `isMovableByWindowBackground`) because NSImageView
/// swallows mouse-down events, and the window is a non-activating panel.
final class CatView: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }

    private var dragStartMouse = NSPoint.zero
    private var dragStartOrigin = NSPoint.zero

    override var mouseDownCanMoveWindow: Bool { false }  // we handle the move ourselves
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }  // drag on the first click, no focus needed

    override func draw(_ dirtyRect: NSRect) {
        image?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
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
