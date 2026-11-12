// Local App Store tooling. Never included in the application target.
import Foundation
import CoreGraphics
import ImageIO

var failed = false
for path in CommandLine.arguments.dropFirst() {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8,
                                  bytesPerRow: 256, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fputs("Cannot inspect screenshot: \(path)\n", stderr)
        failed = true
        continue
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
    let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
    var visible = 0
    // Ignore the top and right status areas: Duo may render those over an
    // otherwise black launch frame, which passes a whole-image black check.
    // The actual Glintwake background and panels exceed this brightness.
    for y in 13..<51 {
        for x in 0..<51 {
            let offset = (y * 64 + x) * 4
            if max(pixels[offset], pixels[offset + 1], pixels[offset + 2]) > 12 { visible += 1 }
        }
    }
    if visible < 194 { // Less than ten percent of the central-left app area.
        fputs("Empty app content (possibly status-only launch frame): \(path)\n", stderr)
        failed = true
    }
}
exit(failed ? 1 : 0)
