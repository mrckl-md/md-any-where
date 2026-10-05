import AppKit
import Foundation

// Rasterize the vector mark at every macOS icon size. Each image is rendered
// directly from the SVG so the small Dock variants remain sharp.
let arguments = CommandLine.arguments
guard arguments.count == 3,
      let mark = NSImage(contentsOfFile: arguments[1]) else {
    fputs("Usage: render-icon.swift <mark.svg> <output.iconset>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for variant in variants {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: variant.pixels,
        pixelsHigh: variant.pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fputs("Unable to create \(variant.pixels) px icon bitmap\n", stderr)
        exit(1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    mark.draw(
        in: CGRect(x: 0, y: 0, width: variant.pixels, height: variant.pixels),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Unable to encode \(variant.name)\n", stderr)
        exit(1)
    }
    try png.write(to: outputDirectory.appendingPathComponent(variant.name))
}
