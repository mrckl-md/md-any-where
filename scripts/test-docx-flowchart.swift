import AppKit
import WebKit

// Exercise the shipped WebKit export button and feed its real JSON into Swift.
// This uses an invisible window and never accesses a connected device.
@MainActor
final class DocxFlowchartTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let webView: WKWebView
    let window: NSWindow
    let resources: URL
    let destination: URL
    var completed = false
    var failure: String?

    init(resources: URL, destination: URL) {
        self.resources = resources
        self.destination = destination
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 393, height: 852), configuration: configuration)
        window = NSWindow(contentRect: webView.frame, styleMask: [], backing: .buffered, defer: false)
        super.init()
        window.contentView = webView
        webView.appearance = NSAppearance(named: .darkAqua)
        webView.navigationDelegate = self
        configuration.userContentController.add(self, name: "editor")
        configuration.userContentController.add(self, name: "testResult")
    }

    func start() {
        webView.loadFileURL(resources.appendingPathComponent("index.html"), allowingReadAccessTo: resources)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(error.localizedDescription) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(error.localizedDescription) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        do {
            let fixture = try String(contentsOf: resources.appendingPathComponent("mobile-demo.md"), encoding: .utf8)
            let json = String(data: try JSONSerialization.data(withJSONObject: [fixture]), encoding: .utf8)!
            let script = #"""
            void (async () => {
              const expect = (condition, message) => { if (!condition) throw new Error(message); };
              window.dotmd.setContent(\#(json)[0]);
              window.dotmd.setMode('editor');
              const article = document.getElementById('preview');
              const original = article.innerHTML;
              const synchronous = window.dotmdDocx.collectBlocks(article);
              expect(synchronous.some(block => block.type === 'code' && block.text.includes('A[写作]')),
                'Synchronous export must retain editable diagram source');
              const result = await window.dotmdDocx.prepareBlocks(article);
              expect(result.fallbackCount === 0, 'Valid flowchart must rasterize in WebKit');
              const images = result.blocks.flatMap(block => block.runs || []).filter(run => run.kind === 'image');
              expect(images.length === 1 && images[0].source.startsWith('data:image/png;base64,'), 'Fixture needs exactly one PNG');
              expect(article.innerHTML === original, 'Export must not mutate the preview');
              const chartIndex = result.blocks.findIndex(block => (block.runs || []).some(run => run.kind === 'image'));
              expect(result.blocks.slice(0, chartIndex).some(block => block.type === 'math'), 'Formula before chart must survive');
              expect(result.blocks.slice(chartIndex + 1).some(block => block.type === 'table'), 'Table after chart must survive');
              const broken = document.createElement('article');
              const diagram = document.createElement('div');
              diagram.className = 'dotmd-mermaid';
              diagram.dataset.mermaidSource = 'unsupported syntax and important user content';
              broken.append(diagram);
              const fallback = await window.dotmdDocx.prepareBlocks(broken);
              expect(fallback.fallbackCount === 1 && fallback.blocks[0].text === diagram.dataset.mermaidSource,
                'Invalid flowchart must preserve its exact source');
              const nested = document.createElement('article');
              nested.innerHTML = '<ul><li>Nested diagram</li></ul>';
              nested.querySelector('li').append(article.querySelector('.dotmd-mermaid').cloneNode(true));
              const nestedResult = await window.dotmdDocx.prepareBlocks(nested);
              expect(nestedResult.blocks[0].runs.some(run => run.kind === 'image'), 'List must preserve its nested diagram');
              // Exercise the button, fresh preview render and native message contract.
              await document.getElementById('docx-export').onclick();
            })().catch(error => window.webkit.messageHandlers.testResult.postMessage(String(error)));
            """#
            webView.evaluateJavaScript(script) { _, error in
                if let error { self.finish(error.localizedDescription) }
            }
        } catch { finish(error.localizedDescription) }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "testResult" { finish(String(describing: message.body)); return }
        guard let body = message.body as? [String: Any], body["type"] as? String == "exportDOCX" else { return }
        do {
            let decoder = JSONDecoder()
            let blocks = try decoder.decode([DocxBlock].self, from: JSONSerialization.data(withJSONObject: body["blocks"]!))
            let layout = try decoder.decode(DocxLayout.self, from: JSONSerialization.data(withJSONObject: body["settings"]!))
            let images = blocks.flatMap { $0.runs ?? [] }.filter { $0.kind == "image" }
            guard images.count == 1, let source = images.first?.source,
                  let encoded = source.split(separator: ",").last,
                  let png = Data(base64Encoded: String(encoded)), let bitmap = NSBitmapImageRep(data: png),
                  bitmap.pixelsWide > 300, bitmap.pixelsHigh > 100 else {
                finish("Native export is missing the flowchart PNG"); return
            }
            var ink = 0
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
                for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
                    if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                       min(color.redComponent, color.greenComponent, color.blueComponent) < 0.7 { ink += 1 }
                }
            }
            guard ink > 100 else { finish("Flowchart PNG is blank or missing its shapes and labels"); return }
            try DocxExporter(layout: layout, sourceURL: nil).exportDocument(blocks: blocks, title: "Mobile flowchart fixture", to: destination)
            print("WebKit exported one nonblank \(bitmap.pixelsWide)×\(bitmap.pixelsHigh) flowchart PNG; native DOCX written.")
            finish(nil)
        } catch { finish(error.localizedDescription) }
    }

    func finish(_ error: String?) {
        guard !completed else { return }
        completed = true
        failure = error
        if let error { fputs("FAIL: \(error)\n", stderr) }
        CFRunLoopStop(CFRunLoopGetMain())
    }
}

@main
@MainActor
struct RunDocxFlowchartTest {
    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        guard CommandLine.arguments.count == 3 else { fatalError("Usage: test-docx-flowchart <Editor resources> <output.docx>") }
        let test = DocxFlowchartTest(resources: URL(fileURLWithPath: CommandLine.arguments[1]), destination: URL(fileURLWithPath: CommandLine.arguments[2]))
        test.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 35) { test.finish("WebKit export timed out") }
        CFRunLoopRun()
        exit(test.failure == nil ? 0 : 1)
    }
}
