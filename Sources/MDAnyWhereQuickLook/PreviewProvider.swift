import AppKit
import Foundation
import QuickLookUI

final class MDAnyWherePreviewViewController: NSViewController, QLPreviewingController {
    private var previewView: NSTextView!

    override func loadView() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 900, height: 1100))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 42, height: 36)
        textView.drawsBackground = false
        scrollView.documentView = textView
        previewView = textView
        view = scrollView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            // Bound both file I/O and native text layout inside Finder's preview host.
            let limit = 1024 * 1024
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let bytes = try handle.read(upToCount: limit + 1) ?? Data()
            let truncated = bytes.count > limit
            let source = String(decoding: bytes.prefix(limit), as: UTF8.self)
            previewView.textStorage?.setAttributedString(
                NativeMarkdownPreview.render(source: source, title: url.lastPathComponent,
                                             truncated: truncated))
            previewView.scrollToBeginningOfDocument(nil)
            handler(nil)
        } catch {
            handler(error)
        }
    }
}
