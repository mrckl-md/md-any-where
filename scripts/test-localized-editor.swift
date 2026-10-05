// Runs the shipped mobile editor in WebKit without opening or activating a window.
// Native iOS keyboard, safe-area and touch behavior still require device testing.
import AppKit
import WebKit

final class LocalizedEditorTest: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let window: NSWindow
    let resourceURL: URL
    var failures: [String] = []
    var completed = false
    let scenarios: [(Int, Int, String)] = ["en-US", "zh-Hans", "de-DE", "fr-FR", "ja", "ar-SA", "he", "ur-PK", "ta-IN"].flatMap { locale in
        [(320, 568, locale), (430, 932, locale), (768, 1024, locale)]
    }

    init(resourceURL: URL) {
        self.resourceURL = resourceURL
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 393, height: 852), configuration: configuration)
        window = NSWindow(contentRect: webView.frame, styleMask: [], backing: .buffered, defer: false)
        super.init()
        window.contentView = webView
        // Print must stay white even when the device is using Dark Mode.
        webView.appearance = NSAppearance(named: .darkAqua)
        webView.navigationDelegate = self
    }

    func run() {
        webView.loadFileURL(resourceURL.appendingPathComponent("index.html"), allowingReadAccessTo: resourceURL)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(error.localizedDescription) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(error.localizedDescription) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        do {
            let fixture = try String(contentsOf: resourceURL.appendingPathComponent("mobile-demo.md"), encoding: .utf8)
            let json = String(data: try JSONSerialization.data(withJSONObject: [fixture]), encoding: .utf8)!
            evaluate("window.dotmd.configureAgents([{id:'layout-test',name:'测试 Agent',kind:'openai-chat',endpoint:'https://example.invalid/v1',model:'test-model',enabled:true,keyPresent:false}]); window.dotmd.setContent(\(json)[0]); true") { self.evaluate(self.dataPreservationSetup) { self.testSize(at: 0) } }
        } catch { finish(error.localizedDescription) }
    }

    func evaluate(_ source: String, then completion: @escaping () -> Void) {
        webView.evaluateJavaScript(source) { value, error in
            if let error { self.failures.append(error.localizedDescription) }
            if let values = value as? [String] { self.failures.append(contentsOf: values) }
            completion()
        }
    }

    func testSize(at index: Int) {
        guard index < scenarios.count else { finish(nil); return }
        let (width, height, locale) = scenarios[index]
        window.setContentSize(NSSize(width: width, height: height))
        webView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        // WebKit resize/visualViewport events and editor refresh complete asynchronously.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.evaluate(self.layoutAssertions(width: width, height: height, locale: locale)) {
                print("Checked localized WebKit \(locale) \(width)×\(height)")
                self.testSize(at: index + 1)
            }
        }
    }

    func layoutAssertions(width: Int, height: Int, locale: String) -> String {
        #"""
        (() => {
          const problems = [];
          const prefix = '\#(locale) \#(width)×\#(height): ';
          const expect = (condition, message) => { if (!condition) problems.push(prefix + message); };
          const rect = element => element.getBoundingClientRect();
          const visible = element => !!element && rect(element).width > 0 && rect(element).height > 0 && getComputedStyle(element).visibility !== 'hidden';
          const fitsWidth = (element, container) => rect(element).left >= rect(container).left - 1 && rect(element).right <= rect(container).right + 1;
          const body = document.body;
          window.DotMDI18n.setLanguage('\#(locale)');
          expect(document.documentElement.lang === '\#(locale)', 'document locale is incorrect');
          expect(document.documentElement.dir === (/^(ar|he|ur)/.test('\#(locale)') ? 'rtl' : 'ltr'), 'interface direction is incorrect');
          expect(window.dotmd.getContent() === window.__localizationDocument, 'language switch changed document text');
          expect(JSON.stringify(document.querySelector('.CodeMirror').CodeMirror.getHistory()) === window.__localizationHistory, 'language switch changed undo history');
          expect(document.querySelector('#agent-profiles .key').value === 'localization-test-placeholder', 'language switch cleared an unsaved agent field');
          expect(getComputedStyle(document.querySelector('.CodeMirror')).direction === 'ltr', 'code editor inherited interface RTL direction');
          expect(innerWidth === \#(width), 'WebKit viewport must match the scenario');
          expect(body.scrollWidth <= innerWidth + 1, 'document must not scroll horizontally');
          document.querySelectorAll('.ipad-file-tools button, .view-switch button').forEach(button => {
            if (visible(button)) expect(fitsWidth(button, body), 'topbar action outside viewport: ' + button.textContent);
          });
          const formatTools = document.querySelector('.format-tools');
          if (visible(formatTools)) {
            expect(fitsWidth(formatTools, body), 'format toolbar extends beyond viewport');
            formatTools.scrollLeft = getComputedStyle(formatTools).direction === 'rtl' ? -formatTools.scrollWidth : formatTools.scrollWidth;
            expect(fitsWidth(formatTools.lastElementChild, formatTools), 'last format action cannot be reached by horizontal scroll');
            formatTools.scrollLeft = 0;
          }
          ['editor', 'preview', 'split'].forEach(mode => {
            window.dotmd.setMode(mode);
            const editor = document.getElementById('editor-pane');
            const preview = document.getElementById('preview-pane');
            expect(visible(editor) === (mode !== 'preview'), mode + ': editor visibility');
            expect(visible(preview) === (mode !== 'editor'), mode + ': preview visibility');
            [editor, preview].filter(visible).forEach(pane => {
              expect(fitsWidth(pane, body), mode + ': pane width exceeds viewport');
              expect(rect(pane).height >= 40, mode + ': writing area is too short');
            });
          });
          window.dotmd.setMode('preview');
          const previewPane = document.getElementById('preview-pane');
          const diagram = document.querySelector('.dotmd-flowchart-svg');
          expect(!!diagram, 'public fixture flowchart must render');
          if (diagram) {
            const chart = diagram.closest('.dotmd-mermaid');
            expect(rect(diagram).width <= chart.clientWidth + 1, 'flowchart must fit without clipping nodes');
            expect(chart.scrollWidth <= chart.clientWidth + 1, 'flowchart requires unexpected horizontal scrolling');
          }
          previewPane.style.scrollBehavior = 'auto';
          previewPane.scrollTop = previewPane.scrollHeight;
          expect(rect(document.getElementById('preview').lastElementChild).bottom <= rect(previewPane).bottom + 1,
            'preview must reach the final fixture paragraph by scrolling');
          previewPane.scrollTop = 0;
          previewPane.style.scrollBehavior = '';
          if (body.classList.contains('mobile-compact-height')) {
            const toggle = document.getElementById('mobile-format-toggle');
            expect(visible(toggle), 'short viewport requires a format toggle');
            toggle.click();
            expect(visible(formatTools), 'format toggle must reveal toolbar');
            toggle.click();
          }
          const dialogs = ['ipad-file-menu','settings-dialog','formula-dialog','search-dialog','agent-dialog','history-dialog','privacy-policy','docx-dialog'];
          dialogs.forEach(id => {
            const dialog = document.getElementById(id);
            dialog.showModal();
            if (id === 'agent-dialog') {
              const mode = document.getElementById('cluster-mode');
              mode.value = 'workflow'; mode.dispatchEvent(new Event('change'));
              document.getElementById('workflow-template').click();
            }
            expect(fitsWidth(dialog, body), id + ': dialog exceeds viewport width');
            expect(rect(dialog).top >= -1 && rect(dialog).bottom <= innerHeight + 1, id + ': dialog exceeds available height');
            const overflowing = [...dialog.querySelectorAll('*')].filter(element => visible(element) && (!fitsWidth(element, dialog) || element.scrollWidth > element.clientWidth + 1))
              .map(element => `${element.tagName}#${element.id}.${element.className} (${element.clientWidth}/${element.scrollWidth}px, ${Math.round(rect(element).left)}..${Math.round(rect(element).right)}) ${element.textContent.slice(0,60)}`).slice(0,12);
            expect(dialog.scrollWidth <= dialog.clientWidth + 1, id + `: dialog content overflows horizontally (${dialog.clientWidth}/${dialog.scrollWidth}): ` + overflowing.join(' | '));
            const scroll = dialog.querySelector('.docx-layout');
            if (scroll) scroll.scrollTop = scroll.scrollHeight;
            dialog.scrollTop = dialog.scrollHeight;
            const actions = [...dialog.querySelectorAll('button')].filter(visible);
            const last = actions.at(-1);
            if (last) {
              last.scrollIntoView({block:'nearest'});
              expect(rect(last).bottom <= rect(dialog).bottom + 1, id + ': final action cannot be reached');
            }
            dialog.close();
          });
          window.dotmd.setMode('editor');
          window.dotmd.preparePrint();
          expect(visible(document.getElementById('preview-pane')), 'PDF preview must be visible from editor mode');
          expect(document.getElementById('preview').textContent.includes('md any where'), 'PDF preview is missing document content');
          expect(getComputedStyle(body).backgroundColor === 'rgb(255, 255, 255)',
            'PDF must have a white background in Dark Mode; got ' + getComputedStyle(body).backgroundColor);
          if (diagram) expect(rect(diagram).width <= rect(document.getElementById('preview')).width + 1,
            'printed flowchart is wider than the page');
          window.dotmd.finishPrint();
          return problems;
        })();
        """#
    }

    var dataPreservationSetup: String {
        #"""
        (() => {
          const problems = [];
          const editor = document.querySelector('.CodeMirror').CodeMirror;
          editor.replaceRange('Localization test\n', {line:1,ch:0});
          window.__localizationDocument = editor.getValue();
          window.__localizationHistory = JSON.stringify(editor.getHistory());
          document.querySelector('#agent-profiles .key').value = 'localization-test-placeholder';
          // Accepting a suggestion clears pending state while its hidden UI remains
          // mounted; language bindings must not read that cleared state again.
          document.getElementById('workflow-goal').value = 'Keep my workflow goal {p0}';
          window.dotmd.showWorkflowProposal(JSON.stringify({title:'My preserved workflow',stages:[{
            title:'My step',prompt:'Preserve this user instruction {0}',mode:'single',profileIDs:['layout-test']
          }]}), '');
          document.querySelector('#workflow-proposal button').click();
          const savedWorkflow = localStorage.getItem('agentWorkflow.v1');
          if (!savedWorkflow || JSON.parse(savedWorkflow).stages[0].prompt !== 'Preserve this user instruction {0}') problems.push('Workflow suggestion was not accepted');
          const expected = window.DotMDI18n.languages.map(item => item.code);
          for (const locale of expected) {
            window.DotMDI18n.setLanguage(locale);
            const catalog = window.DotMDLocaleCatalogs[locale] || (locale.startsWith('en-') ? window.DotMDLocaleCatalogs.en : null);
            if (!catalog) { problems.push(locale + ': missing shipped translation'); continue; }
            if (document.getElementById('interface-language').getAttribute('aria-label') !== catalog['language.label']) problems.push(locale + ': language control was not translated');
            if (window.dotmd.getContent() !== window.__localizationDocument) problems.push(locale + ': document was modified');
            if (JSON.stringify(editor.getHistory()) !== window.__localizationHistory) problems.push(locale + ': undo history was modified');
            if (localStorage.getItem('agentWorkflow.v1') !== savedWorkflow) problems.push(locale + ': accepted workflow was modified');
            if (document.getElementById('workflow-goal').value !== 'Keep my workflow goal {p0}') problems.push(locale + ': workflow goal was modified');
            if (document.querySelector('#agent-profiles .key').value !== 'localization-test-placeholder') problems.push(locale + ': unsaved API Key was cleared');
          }
          window.DotMDI18n.setLanguage('en-US');
          return problems;
        })();
        """#
    }

    func finish(_ error: String?) {
        guard !completed else { return }
        completed = true
        if let error { failures.append(error) }
        if failures.isEmpty { print("Localized editor WebKit regression passed.") }
        else { failures.forEach { fputs("FAIL: \($0)\n", stderr) } }
        CFRunLoopStop(CFRunLoopGetMain())
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
guard CommandLine.arguments.count == 2 else { fatalError("Usage: test-mobile-layout <copied Editor resources>") }
let test = LocalizedEditorTest(resourceURL: URL(fileURLWithPath: CommandLine.arguments[1]))
test.run()
DispatchQueue.main.asyncAfter(deadline: .now() + 150) { test.finish("WebKit test timed out") }
CFRunLoopRun()
exit(test.failures.isEmpty ? 0 : 1)
