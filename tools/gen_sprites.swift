// Generates the placeholder cat sprites (idle/left/right) as 256x256 transparent PNGs.
// Usage: swift tools/gen_sprites.swift [output_root]
// Default root: Sources/CatCompanionOverlay/sprites
// Layout: the orange cat is written directly into the root (what the app loads today);
// the other skins go in <root>/<skin name>/ (gray_tabby, tortie, calico) and are not loaded by the app yet.
import AppKit

let size = 256
let outRoot = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Sources/CatCompanionOverlay/sprites"

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
}

/// Everything that differs between cats. Layout/pose code is shared.
struct Skin {
    let name: String
    let dir: String            // "" = root
    let fur: NSColor
    let cream: NSColor         // paws + muzzle
    let nose: NSColor
    let innerEar: NSColor
    let iris: NSColor?         // nil = plain dark eyes (original orange cat)
    let tabby: NSColor?        // stripe colour; nil = forehead stripes in ink only
    let patches: [(NSColor, NSBezierPath)]  // tortie colour patches, clipped to the head
    var earLeft: NSColor? = nil   // nil = same as fur (calico has coloured ears)
    var earRight: NSColor? = nil
    var stripes = true            // forehead stripes in ink (off for calico)
}

let ink     = rgb(0.20, 0.13, 0.12)
let wood    = NSColor(calibratedRed: 0.55, green: 0.38, blue: 0.26, alpha: 1)
let woodTop = NSColor(calibratedRed: 0.68, green: 0.48, blue: 0.33, alpha: 1)

let orange = Skin(name: "orange", dir: "", fur: rgb(0.96, 0.64, 0.30), cream: rgb(1.00, 0.90, 0.75),
                  nose: rgb(0.98, 0.62, 0.66), innerEar: rgb(0.98, 0.62, 0.66),
                  iris: nil, tabby: nil, patches: [])

// Gray DSH tabby: pink nose, amber eyes.
let grayTabby = Skin(name: "gray_tabby", dir: "gray_tabby", fur: rgb(0.40, 0.42, 0.46), cream: rgb(0.66, 0.67, 0.70),
                     nose: rgb(0.98, 0.62, 0.66), innerEar: rgb(0.98, 0.62, 0.66),
                     iris: rgb(0.96, 0.66, 0.12), tabby: rgb(0.25, 0.27, 0.31), patches: [])

// Tortie DSH: black nose, yellow-green eyes. "Black" is a soft charcoal so the ink outline stays visible.
let tortieBlack = rgb(0.24, 0.22, 0.23)
let tortieOrange = rgb(0.93, 0.52, 0.20)
let tortie = Skin(name: "tortie", dir: "tortie", fur: tortieBlack, cream: rgb(0.95, 0.72, 0.45),
                  nose: rgb(0.10, 0.08, 0.08), innerEar: rgb(0.45, 0.32, 0.33),
                  iris: rgb(0.74, 0.86, 0.24), tabby: nil,
                  patches: [
                    // orange blaze down the right side of the face, orange right ear, orange cheek, black-ish left
                    (tortieOrange, NSBezierPath(ovalIn: NSRect(x: 128, y: 120, width: 90, height: 100))),
                    (tortieOrange, NSBezierPath(ovalIn: NSRect(x: 40, y: 100, width: 52, height: 40))),
                    (tortieOrange, NSBezierPath(ovalIn: NSRect(x: 150, y: 190, width: 60, height: 50))),
                  ])

// Calico DSH: white with orange and black patches, pink nose. Eye colour wasn't specified; green is a
// common calico eye colour and keeps it distinct from the amber gray tabby.
let calico = Skin(name: "calico", dir: "calico", fur: rgb(0.95, 0.88, 0.76), cream: rgb(0.97, 0.84, 0.71),
                  nose: rgb(0.98, 0.62, 0.66), innerEar: rgb(0.98, 0.62, 0.66),
                  iris: rgb(0.42, 0.74, 0.38), tabby: nil,
                  patches: [
                    (rgb(0.31, 0.31, 0.33), NSBezierPath(ovalIn: NSRect(x: 38, y: 138, width: 76, height: 80))),  // black, upper left
                    (rgb(0.93, 0.52, 0.20), NSBezierPath(ovalIn: NSRect(x: 132, y: 168, width: 70, height: 56))),  // orange, upper right
                    (rgb(0.93, 0.52, 0.20), NSBezierPath(ovalIn: NSRect(x: 156, y: 96, width: 64, height: 60))),  // orange, right cheek
                  ],
                  earLeft: rgb(0.31, 0.31, 0.33), earRight: rgb(0.93, 0.52, 0.20), stripes: false)

var fur = orange.fur, cream = orange.cream

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
func line(_ a: CGPoint, _ b: CGPoint, width: CGFloat = 3, color: NSColor = ink) {
    let p = NSBezierPath(); p.move(to: a); p.line(to: b)
    p.lineWidth = width; p.lineCapStyle = .round; color.setStroke(); p.stroke()
}

func drawPaw(_ x: CGFloat, down: Bool) {
    let y: CGFloat = down ? 66 : 112
    shape(oval(x, y, 50, down ? 34 : 44), cream)
    // toe lines
    for dx: CGFloat in [-8, 0, 8] {
        line(CGPoint(x: x + dx, y: y - 2), CGPoint(x: x + dx, y: y - (down ? 9 : 12)), width: 2)
    }
}

func render(_ skin: Skin, _ name: String, leftDown: Bool, rightDown: Bool) {
    fur = skin.fur; cream = skin.cream
    let outDir = skin.dir.isEmpty ? outRoot : outRoot + "/" + skin.dir
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
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
    shape(tri(CGPoint(x: 62, y: 150), CGPoint(x: 72, y: 214), CGPoint(x: 112, y: 168)), skin.earLeft ?? fur)
    shape(tri(CGPoint(x: 194, y: 150), CGPoint(x: 184, y: 214), CGPoint(x: 144, y: 168)), skin.earRight ?? fur)
    shape(tri(CGPoint(x: 74, y: 162), CGPoint(x: 78, y: 196), CGPoint(x: 99, y: 170)), skin.innerEar, stroke: false)
    shape(tri(CGPoint(x: 182, y: 162), CGPoint(x: 178, y: 196), CGPoint(x: 157, y: 170)), skin.innerEar, stroke: false)
    // head
    let head = oval(128, 140, 150, 112)
    shape(head, fur)
    if !skin.patches.isEmpty {
        // tortie patches: clipped to the head, then outline redrawn on top
        NSGraphicsContext.saveGraphicsState()
        head.addClip()
        for (color, path) in skin.patches { color.setFill(); path.fill() }
        NSGraphicsContext.restoreGraphicsState()
        ink.setStroke(); head.lineWidth = 4; head.stroke()
    }
    // forehead stripes (tabby: coloured, plus cheek stripes)
    if skin.stripes {
        for dx: CGFloat in [-14, 0, 14] {
            line(CGPoint(x: 128 + dx, y: 192), CGPoint(x: 128 + dx, y: 178), width: 4,
                 color: skin.tabby ?? ink)
        }
    }
    if let stripe = skin.tabby {
        for dy: CGFloat in [0, 12, 24] {
            line(CGPoint(x: 56, y: 132 + dy), CGPoint(x: 76, y: 130 + dy), width: 4, color: stripe)
            line(CGPoint(x: 200, y: 132 + dy), CGPoint(x: 180, y: 130 + dy), width: 4, color: stripe)
        }
    }
    // eyes: happy arcs while typing, round when idle
    let typing = leftDown || rightDown
    for ex: CGFloat in [100, 156] {
        if typing {
            let p = NSBezierPath()
            p.appendArc(withCenter: CGPoint(x: ex, y: 138), radius: 11, startAngle: 20, endAngle: 160)
            p.lineWidth = 4; p.lineCapStyle = .round; ink.setStroke(); p.stroke()
        } else {
            if let iris = skin.iris {
                shape(oval(ex, 140, 26, 28), iris, stroke: false)
                shape(oval(ex, 140, 10, 22), ink, stroke: false)  // slit-ish pupil
                shape(oval(ex + 4, 147, 7, 8), .white, stroke: false)
            } else {
                shape(oval(ex, 140, 20, 24), ink, stroke: false)
                shape(oval(ex + 3, 146, 7, 8), .white, stroke: false)
            }
        }
    }
    // muzzle, nose, mouth, whiskers
    shape(oval(128, 112, 44, 28), cream, stroke: false)
    shape(tri(CGPoint(x: 120, y: 122), CGPoint(x: 136, y: 122), CGPoint(x: 128, y: 113)), skin.nose)
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

for skin in [orange, grayTabby, tortie, calico] {
    render(skin, "idle",  leftDown: false, rightDown: false)
    render(skin, "left",  leftDown: true,  rightDown: false)
    render(skin, "right", leftDown: false, rightDown: true)
}
