#if canImport(DOTMDLocalization)
import DOTMDLocalization
#endif
import UIKit
import WebKit

/// UIKit lays out the web formatter against printable paper dimensions, rather
/// than capturing the phone's narrow viewport as one unbounded PDF page.
@MainActor
final class MobilePDFRenderer: UIPrintPageRenderer {
    enum PaperSize: String {
        case a4
        case letter

        var dimensions: CGSize {
            switch self {
            case .a4: return CGSize(width: 210 * 72 / 25.4, height: 297 * 72 / 25.4)
            case .letter: return CGSize(width: 612, height: 792)
            }
        }
    }

    private let pageBounds: CGRect
    private let contentBounds: CGRect

    init(paperSize: PaperSize = .a4) {
        pageBounds = CGRect(origin: .zero, size: paperSize.dimensions)
        let margin = 20 * 72 / 25.4
        contentBounds = pageBounds.insetBy(dx: margin, dy: margin)
        super.init()
    }

    // These documented overrides avoid KVC writes to UIKit's read-only geometry.
    override var paperRect: CGRect { pageBounds }
    override var printableRect: CGRect { contentBounds }

    func makePDF(from webView: WKWebView, title: String) throws -> Data {
        webView.layoutIfNeeded()
        let formatter = webView.viewPrintFormatter()
        formatter.perPageContentInsets = .zero // Margins belong to the renderer.
        addPrintFormatter(formatter, startingAtPageAt: 0)
        let pageCount = numberOfPages
        guard pageCount > 0 else {
            throw IPadDocumentStore.fileError(422, L("native.pdf.empty"))
        }
        guard pageCount <= 2_000 else {
            throw IPadDocumentStore.fileError(413, L("native.pdf.tooLong"))
        }
        prepare(forDrawingPages: NSRange(location: 0, length: pageCount))
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: title,
                               kCGPDFContextCreator as String: "md any where"]
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)
        return renderer.pdfData { context in
            for pageIndex in 0..<pageCount {
                context.beginPage()
                UIColor.white.setFill()
                context.cgContext.fill(pageBounds)
                drawPage(at: pageIndex, in: pageBounds)
            }
        }
    }
}
