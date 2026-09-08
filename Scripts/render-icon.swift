import AppKit

let output = CommandLine.arguments[1]
func render(_ size: Int, to name: String) {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let bg = NSColor(srgbRed: 0.035, green: 0.065, blue: 0.095, alpha: 1)
    let mint = NSColor(srgbRed: 0.46, green: 0.94, blue: 0.79, alpha: 1)
    let gold = NSColor(srgbRed: 1, green: 0.79, blue: 0.43, alpha: 1)
    bg.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
    for y in 0..<4 { for x in 0..<4 {
        NSColor(srgbRed: 0.09, green: 0.145, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 138 + x * 190, y: 138 + y * 190, width: 178, height: 178), xRadius: 28, yRadius: 28).fill()
    } }
    let line = NSBezierPath()
    line.move(to: NSPoint(x: 227, y: 227)); line.line(to: NSPoint(x: 607, y: 227)); line.line(to: NSPoint(x: 607, y: 607))
    line.lineWidth = 28; line.lineCapStyle = .round; line.lineJoinStyle = .round
    mint.withAlphaComponent(0.5).setStroke(); line.stroke()
    mint.setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: 565, y: 185, width: 84, height: 84)); ring.lineWidth = 10; ring.stroke()
    let gem = NSBezierPath()
    gem.move(to: NSPoint(x: 417, y: 285)); gem.line(to: NSPoint(x: 460, y: 227)); gem.line(to: NSPoint(x: 417, y: 169)); gem.line(to: NSPoint(x: 374, y: 227)); gem.close()
    gold.setFill(); gem.fill()
    mint.setFill(); NSBezierPath(ovalIn: NSRect(x: 539, y: 539, width: 136, height: 136)).fill()
    bg.setFill()
    let star = NSBezierPath()
    for i in 0..<8 {
        let angle = Double(i) * .pi / 4
        let radius = i % 2 == 0 ? 44.0 : 12.0
        let p = NSPoint(x: 607 + cos(angle) * radius, y: 607 + sin(angle) * radius)
        if i == 0 { star.move(to: p) } else { star.line(to: p) }
    }
    star.close(); star.fill()
    NSGraphicsContext.restoreGraphicsState()
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output).appendingPathComponent(name))
}
var images: [[String: String]] = [["filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]]
render(1024, to: "icon-1024.png")
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "mac-\(size)-\(scale).png"
        render(size * scale, to: filename)
        images.append(["filename": filename, "idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: URL(fileURLWithPath: output).appendingPathComponent("Contents.json"))
