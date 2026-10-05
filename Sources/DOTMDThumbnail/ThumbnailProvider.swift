import AppKit
import Foundation
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        do {
            // Finder can request hundreds of small icons at once. Only the first
            // 256 KiB can contribute to the heading and seven preview lines.
            let handle = try FileHandle(forReadingFrom: request.fileURL)
            defer { try? handle.close() }
            let source = String(decoding: try handle.read(upToCount: 256 * 1024) ?? Data(), as: UTF8.self)
            let lines = source.split(whereSeparator: \Character.isNewline)
            let heading = lines.first { $0.range(of: #"^#{1,6}\s+"#, options: .regularExpression) != nil }?
                .replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression) ?? request.fileURL.deletingPathExtension().lastPathComponent
            let summary = lines.lazy.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.isEmpty && !trimmed.hasPrefix("#") && !trimmed.hasPrefix("```") && !trimmed.hasPrefix("flowchart")
            }.prefix(7).joined(separator: "\n")
            let size = request.maximumSize
            let reply = QLThumbnailReply(contextSize: size, currentContextDrawing: {
                let canvas = NSRect(origin: .zero, size: size)
                NSColor(calibratedRed: 0.985, green: 0.976, blue: 0.958, alpha: 1).setFill()
                NSBezierPath(roundedRect: canvas.insetBy(dx: 2, dy: 2), xRadius: max(7, size.width * 0.04), yRadius: max(7, size.width * 0.04)).fill()
                NSColor(calibratedRed: 0.92, green: 0.44, blue: 0.31, alpha: 1).setFill()
                NSRect(x: 0, y: 0, width: max(5, size.width * 0.045), height: size.height).fill()
                let inset = max(12, size.width * 0.09)
                let titleFont = NSFont.systemFont(ofSize: max(12, size.width * 0.09), weight: .bold)
                let bodyFont = NSFont.systemFont(ofSize: max(8, size.width * 0.046), weight: .regular)
                let titleStyle = NSMutableParagraphStyle(); titleStyle.lineBreakMode = .byTruncatingTail
                let bodyStyle = NSMutableParagraphStyle(); bodyStyle.lineBreakMode = .byTruncatingTail; bodyStyle.lineSpacing = max(1, size.height * 0.008)
                (heading as NSString).draw(in: NSRect(x: inset, y: size.height * 0.69, width: size.width - inset * 1.6, height: size.height * 0.2),
                                           withAttributes: [.font:titleFont, .foregroundColor:NSColor(calibratedWhite:0.12, alpha:1), .paragraphStyle:titleStyle])
                (summary as NSString).draw(in: NSRect(x: inset, y: size.height * 0.13, width: size.width - inset * 1.6, height: size.height * 0.5),
                                           withAttributes: [.font:bodyFont, .foregroundColor:NSColor(calibratedWhite:0.34, alpha:1), .paragraphStyle:bodyStyle])
                return true
            })
            reply.extensionBadge = "MD"
            handler(reply, nil)
        } catch {
            handler(nil, error)
        }
    }
}
