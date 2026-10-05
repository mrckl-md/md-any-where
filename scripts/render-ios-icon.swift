import AppKit
import Foundation
import ImageIO

// Reuse the shared vector mark with an opaque, full-bleed iOS background.
// The system supplies the final icon corner mask.
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: render-ios-icon.swift <shared-mark.svg> <AppIcon.png>")
}
var svg = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
svg = svg.replacingOccurrences(
    of: #"<rect x="76" y="76" width="872" height="872" rx="222" fill="url(#surface)" filter="url(#tileShadow)"/>"#,
    with: #"<rect width="1024" height="1024" fill="url(#surface)"/>"#)
svg = svg.replacingOccurrences(
    of: ##"<rect x="91" y="91" width="842" height="842" rx="207" fill="url(#light)" stroke="#FFF" stroke-opacity=".26" stroke-width="8"/>"##,
    with: #"<rect width="1024" height="1024" fill="url(#light)"/>"#)
let temporarySVG = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".svg")
try svg.write(to: temporarySVG, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: temporarySVG) }
guard let image = NSImage(contentsOf: temporarySVG),
      let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                              bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Unable to render iOS app icon")
}
let graphics = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
image.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), from: .zero,
           operation: .sourceOver, fraction: 1)
graphics.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let rendered = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("Unable to encode iOS app icon")
}
CGImageDestinationAddImage(destination, rendered, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Unable to save iOS app icon") }
