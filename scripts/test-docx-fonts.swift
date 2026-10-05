import Foundation

@main
@MainActor
struct DocxFontFixture {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fatalError("Usage: test-docx-fonts <sample.docx>")
        }
        let layoutJSON = #"{"bodyCjkFont":"宋体","bodyLatinFont":"Times New Roman","headingCjkFont":"黑体","headingLatinFont":"Arial","mathCjkFont":"宋体","mathLatinFont":"Times New Roman","codeFont":"Menlo","bodySize":12,"headingScale":1.5,"lineSpacing":1.5,"paragraphAfter":8,"firstLineIndent":0,"bodyAlign":"justify","headingAlign":"center","pageSize":"a4","marginTop":25,"marginBottom":25,"marginLeft":25,"marginRight":25,"pageNumbers":true}"#
        let blocksJSON = #"""
        [
          {"type":"heading","level":1,"runs":[{"text":"中文 English"}]},
          {"type":"heading","level":2,"runs":[{"text":"第二级标题"}]},
          {"type":"paragraph","runs":[{"text":"中文 English"},{"text":"加粗代码上标","bold":true,"italic":true,"code":true,"underline":true,"strike":true,"superscript":true}]},
          {"type":"quote","runs":[{"text":"引用"}]},
          {"type":"code","text":"let x = 1"},
          {"type":"list","ordered":true,"listID":"sample-list","level":0,"runs":[{"text":"第一项"}]},
          {"type":"task","runs":[{"text":"任务"}]},
          {"type":"table","rows":[[{"header":true,"runs":[{"text":"表头"}]},{"header":true,"runs":[{"text":"Header"}]}],[{"runs":[{"text":"数据"}]},{"runs":[{"text":"Data"}]}]]},
          {"type":"math","math":{"type":"math","children":[{"type":"mfrac","children":[{"type":"mi","text":"x"},{"type":"msup","children":[{"type":"mi","text":"y"},{"type":"mn","text":"2"}]}]},{"type":"mtable","children":[{"type":"mtr","children":[{"type":"mtd","children":[{"type":"mi","text":"a"}]}]}]}]}},
          {"type":"paragraph","runs":[{"kind":"math","math":{"type":"math","children":[{"type":"mi","text":"中文"},{"type":"mi","text":"x"}]}}]}
        ]
        """#
        let decoder = JSONDecoder()
        let layout = try decoder.decode(DocxLayout.self, from: Data(layoutJSON.utf8))
        let blocks = try decoder.decode([DocxBlock].self, from: Data(blocksJSON.utf8))
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        try DocxExporter(layout: layout, sourceURL: nil)
            .exportDocument(blocks: blocks, title: "字体测试", to: destination)
    }
}
