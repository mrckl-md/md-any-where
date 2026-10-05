// Tests the shipped editor and CodeMirror in a private WebKit store. The bridge
// only records requests: no API calls, user files, keychain or visible windows.
import AppKit
import WebKit

final class EditorSafetyTest: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let webView: WKWebView
    let window: NSWindow
    let resourceURL: URL
    var failures: [String] = []
    var completed = false

    init(resourceURL: URL) {
        self.resourceURL = resourceURL
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.addUserScript(WKUserScript(source: "window.__testRequests = [];", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1024, height: 768), configuration: configuration)
        window = NSWindow(contentRect: webView.frame, styleMask: [], backing: .buffered, defer: false)
        super.init()
        configuration.userContentController.add(self, name: "editor")
        window.contentView = webView
        webView.navigationDelegate = self
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String,
              ["agentRun", "agentWorkflowRun"].contains(type),
              let data = try? JSONSerialization.data(withJSONObject: body),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.__testRequests.push(\(json));", completionHandler: nil)
    }

    func run() { webView.loadFileURL(resourceURL.appendingPathComponent("index.html"), allowingReadAccessTo: resourceURL) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(error.localizedDescription) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(error.localizedDescription) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        do {
            let script = try String(contentsOf: resourceURL.appendingPathComponent("editor-safety.js"), encoding: .utf8)
            webView.callAsyncJavaScript(script, arguments: [:], in: nil, in: .page) { result in
                switch result {
                case .success(let value):
                    if let failures = value as? [String] { self.failures.append(contentsOf: failures) }
                    else { self.failures.append("Regression script did not return its assertions") }
                case .failure(let error): self.failures.append(error.localizedDescription)
                }
                self.finish(nil)
            }
        } catch { finish(error.localizedDescription) }
    }

    func finish(_ error: String?) {
        guard !completed else { return }
        completed = true
        if let error { failures.append(error) }
        if failures.isEmpty { print("Editor data-safety and untrusted Markdown WebKit regressions passed.") }
        else { failures.forEach { fputs("FAIL: \($0)\n", stderr) } }
        CFRunLoopStop(CFRunLoopGetMain())
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
guard CommandLine.arguments.count == 2 else { fatalError("Usage: test-editor-safety <copied Editor resources>") }
let test = EditorSafetyTest(resourceURL: URL(fileURLWithPath: CommandLine.arguments[1]))
test.run()
DispatchQueue.main.asyncAfter(deadline: .now() + 90) { test.finish("WebKit test timed out") }
CFRunLoopRun()
exit(test.failures.isEmpty ? 0 : 1)
