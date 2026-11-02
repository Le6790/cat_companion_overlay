// Generates the placeholder cat sprites (idle/left/right) as 256x256 transparent PNGs.
// Usage: swift tools/gen_sprites.swift [output_dir]
// Default output: Sources/CatPartnerOverlay/sprites
import AppKit

let size = 256
let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Sources/CatPartnerOverlay/sprites"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let fur     = NSColor(calibratedRed: 0.96, green: 0.64, blue: 0.30, alpha: 1)
let furDark = NSColor(calibratedRed: 0.85, green: 0.50, blue: 0.20, alpha: 1)
let cream   = NSColor(calibratedRed: 1.00, green: 0.90, blue: 0.75, alpha: 1)
let ink     = NSColor(calibratedRed: 0.20, green: 0.13, blue: 0.12, alpha: 1)
let pink    = NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.66, alpha: 1)
let wood    = NSColor(calibratedRed: 0.55, green: 0.38, blue: 0.26, alpha: 1)
let woodTop = NSColor(calibratedRed: 0.68, green: 0.48, blue: 0.33, alpha: 1)

func shape(_ path: NSBezierPath, _ fill: NSColor, stroke: Bool = true) {
    fill.setFill(); path.fill()
    if stroke { ink.setStroke(); path.lineWidth = 4; path.lineJoinStyle = .round; path.stroke() }
}
func oval(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
}
func tri(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> NSBezierPath {
    let p = NSBezierPath(); p.move(to: a); p.line(to: b); p.line(to: c); p.close(); return p
}
func line(_ a: CGPoint, _ b: CGPoint, width: CGFloat = 3) {
    let p = NSBezierPath(); p.move(to: a); p.line(to: b)
    p.lineWidth = width; p.lineCapStyle = .round; ink.setStroke(); p.stroke()
}

func drawPaw(_ x: CGFloat, down: Bool) {
    let y: CGFloat = down ? 66 : 112
    shape(oval(x, y, 50, down ? 34 : 44), cream)
    // toe lines
    for dx: CGFloat in [-8, 0, 8] {
        line(CGPoint(x: x + dx, y: y - 2), CGPoint(x: x + dx, y: y - (down ? 9 : 12)), width: 2)
    }
}

func render(_ name: String, leftDown: Bool, rightDown: Bool) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.set(); NSRect(x: 0, y: 0, width: size, height: size).fill()

    // body (mostly hidden behind desk)
    shape(oval(128, 70, 150, 100), fur)
    // ears
    shape(tri(CGPoint(x: 62, y: 150), CGPoint(x: 72, y: 214), CGPoint(x: 112, y: 168)), fur)
    shape(tri(CGPoint(x: 194, y: 150), CGPoint(x: 184, y: 214), CGPoint(x: 144, y: 168)), fur)
    shape(tri(CGPoint(x: 74, y: 162), CGPoint(x: 78, y: 196), CGPoint(x: 99, y: 170)), pink, stroke: false)
    shape(tri(CGPoint(x: 182, y: 162), CGPoint(x: 178, y: 196), CGPoint(x: 157, y: 170)), pink, stroke: false)
    // head
    shape(oval(128, 140, 150, 112), fur)
    // forehead stripes
    for dx: CGFloat in [-14, 0, 14] {
        line(CGPoint(x: 128 + dx, y: 192), CGPoint(x: 128 + dx, y: 178), width: 4)
    }
    // eyes: happy arcs while typing, round when idle
    let typing = leftDown || rightDown
    for ex: CGFloat in [100, 156] {
        if typing {
            let p = NSBezierPath()
            p.appendArc(withCenter: CGPoint(x: ex, y: 138), radius: 11, startAngle: 20, endAngle: 160)
            p.lineWidth = 4; p.lineCapStyle = .round; ink.setStroke(); p.stroke()
        } else {
            shape(oval(ex, 140, 20, 24), ink, stroke: false)
            shape(oval(ex + 3, 146, 7, 8), .white, stroke: false)
        }
    }
    // muzzle, nose, mouth, whiskers
    shape(oval(128, 112, 44, 28), cream, stroke: false)
    shape(tri(CGPoint(x: 120, y: 122), CGPoint(x: 136, y: 122), CGPoint(x: 128, y: 113)), pink)
    line(CGPoint(x: 128, y: 113), CGPoint(x: 128, y: 106), width: 3)
    line(CGPoint(x: 128, y: 106), CGPoint(x: 118, y: 100), width: 3)
    line(CGPoint(x: 128, y: 106), CGPoint(x: 138, y: 100), width: 3)
    for dy: CGFloat in [-4, 6] {
        line(CGPoint(x: 86, y: 114 + dy), CGPoint(x: 52, y: 118 + dy * 1.8), width: 2)
        line(CGPoint(x: 170, y: 114 + dy), CGPoint(x: 204, y: 118 + dy * 1.8), width: 2)
    }

    // raised paws (drawn before desk so desk never covers them)
    if !leftDown  { drawPaw(76, down: false) }
    if !rightDown { drawPaw(180, down: false) }

    // desk
    let desk = NSBezierPath(roundedRect: NSRect(x: 14, y: 6, width: 228, height: 52), xRadius: 8, yRadius: 8)
    shape(desk, wood)
    shape(NSBezierPath(roundedRect: NSRect(x: 14, y: 40, width: 228, height: 18), xRadius: 8, yRadius: 8), woodTop)

    // down paws on top of desk
    if leftDown  { drawPaw(76, down: true) }
    if rightDown { drawPaw(180, down: true) }

    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png")
    try! png.write(to: url)
    print("wrote \(url.path)")
}

render("idle",  leftDown: false, rightDown: false)
render("left",  leftDown: true,  rightDown: false)
render("right", leftDown: false, rightDown: true)
