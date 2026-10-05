import AppKit
import Foundation

@main
struct NativePreviewSmokeTest {
static func main() {
let source = """
# 标题

普通段落包含 **粗体**、*斜体* 和 `代码`。

- 第一项
- 第二项

```mermaid
flowchart LR
  A[开始] --> B[结束]
```
"""

let preview = NativeMarkdownPreview.render(source: source, title: "测试.md", truncated: false)
let text = preview.string
precondition(text.contains("测试.md") && text.contains("标题"))
precondition(text.contains("粗体") && !text.contains("**粗体**"))
precondition(text.contains(L("native.quicklook.flowchart")) && text.contains("flowchart LR"))
precondition(!text.contains("<html"))
let file = FileManager.default.temporaryDirectory.appendingPathComponent("dotmd-quicklook-\(UUID().uuidString).md")
try! source.write(to: file, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: file) }
let controller = PreviewViewController()
controller.loadView()
var previewError: Error?
controller.preparePreviewOfFile(at: file) { previewError = $0 }
precondition(previewError == nil)
let textView = (controller.view as? NSScrollView)?.documentView as? NSTextView
precondition(textView?.string.contains("标题") == true, "Quick Look controller must show content")
if let samplePath = ProcessInfo.processInfo.environment["DOT_MD_QUICKLOOK_SAMPLE"] {
    let sampleController = PreviewViewController()
    sampleController.loadView()
    var sampleError: Error?
    sampleController.preparePreviewOfFile(at: URL(fileURLWithPath: samplePath)) { sampleError = $0 }
    precondition(sampleError == nil)
    let sampleText = ((sampleController.view as? NSScrollView)?.documentView as? NSTextView)?.string ?? ""
    precondition(sampleText.count > 100, "Real Markdown sample rendered blank")
}
print("Native Quick Look Markdown rendering passed.")
}
}
