#if canImport(MDAnyWhereLocalization)
import MDAnyWhereLocalization
#endif
#if canImport(AppKit)
import AppKit
#endif
import Foundation
import ImageIO

struct DocxRun: Decodable, Sendable {
    var text: String?
    var bold: Bool?
    var italic: Bool?
    var code: Bool?
    var underline: Bool?
    var superscript: Bool?
    var strike: Bool?
    var kind: String?
    var source: String?
    var alt: String?
    var math: DocxMathNode?
}

struct DocxMathNode: Decodable, Sendable {
    var type: String
    var text: String?
    var open: String?
    var close: String?
    var children: [DocxMathNode]?
}

struct DocxCell: Decodable, Sendable {
    var runs: [DocxRun]
    var header: Bool?
}

struct DocxBlock: Decodable, Sendable {
    var type: String
    var runs: [DocxRun]?
    var rows: [[DocxCell]]?
    var level: Int?
    var listID: String?
    var ordered: Bool?
    var math: DocxMathNode?
    var text: String?
}

struct DocxLayout: Decodable, Sendable {
    var bodyCjkFont: String
    var bodyLatinFont: String
    var headingCjkFont: String
    var headingLatinFont: String
    var mathCjkFont: String
    var mathLatinFont: String
    var codeFont: String
    var bodySize: Double
    var headingScale: Double
    var lineSpacing: Double
    var paragraphAfter: Double
    var firstLineIndent: Double
    var bodyAlign: String
    var headingAlign: String
    var pageSize: String
    var marginTop: Double
    var marginBottom: Double
    var marginLeft: Double
    var marginRight: Double
    var pageNumbers: Bool

    mutating func normalize() {
        func font(_ value: String, fallback: String) -> String {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                .filter { character in
                    !character.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
                }.prefix(80)
            return clean.isEmpty ? fallback : String(clean)
        }
        bodyCjkFont = font(bodyCjkFont, fallback: "宋体")
        bodyLatinFont = font(bodyLatinFont, fallback: "Times New Roman")
        headingCjkFont = font(headingCjkFont, fallback: "黑体")
        headingLatinFont = font(headingLatinFont, fallback: "Arial")
        mathCjkFont = font(mathCjkFont, fallback: "宋体")
        mathLatinFont = font(mathLatinFont, fallback: "Cambria Math")
        codeFont = font(codeFont, fallback: "Menlo")
        bodySize = bodySize.clamped(to: 8...24)
        headingScale = headingScale.clamped(to: 1.05...2.4)
        lineSpacing = lineSpacing.clamped(to: 1...3)
        paragraphAfter = paragraphAfter.clamped(to: 0...36)
        firstLineIndent = firstLineIndent.clamped(to: 0...20)
        marginTop = marginTop.clamped(to: 10...50)
        marginBottom = marginBottom.clamped(to: 10...50)
        marginLeft = marginLeft.clamped(to: 10...50)
        marginRight = marginRight.clamped(to: 10...50)
        if !["left", "center", "right", "justify"].contains(bodyAlign) { bodyAlign = "justify" }
        if !["left", "center", "right"].contains(headingAlign) { headingAlign = "left" }
        if !["letter", "a4"].contains(pageSize) { pageSize = "letter" }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        isFinite ? min(max(self, range.lowerBound), range.upperBound) : range.lowerBound
    }
}

private struct ZipEntry {
    let name: String
    let byteCount: UInt32
    let offset: UInt32
    let crc: UInt32
}

// DOCX is an OOXML ZIP package. Stored entries avoid an external dependency;
// retaining only metadata here avoids keeping duplicate image Data references.
private struct StoredZip {
    private(set) var data = Data()
    private var entries: [ZipEntry] = []

    mutating func addStoredFile(_ name: String, _ bytes: Data) throws {
        guard data.count < Int(UInt32.max), bytes.count < Int(UInt32.max),
              entries.count < Int(UInt16.max) else {
            throw NSError(domain: "MDAnyWhere.DOCX", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: L("native.docx.tooLarge")])
        }
        let nameBytes = Data(name.utf8)
        let checksum = Self.crc32(bytes)
        let offset = UInt32(data.count)
        data.appendLittleEndian(UInt32(0x04034b50))
        data.appendLittleEndian(UInt16(20))
        data.appendLittleEndian(UInt16(0x0800)) // UTF-8 file names
        data.appendLittleEndian(UInt16(0)) // stored, not compressed
        data.appendLittleEndian(UInt16(0)) // DOS time: 00:00
        data.appendLittleEndian(UInt16(0x21)) // DOS date: 1980-01-01
        data.appendLittleEndian(checksum)
        data.appendLittleEndian(UInt32(bytes.count))
        data.appendLittleEndian(UInt32(bytes.count))
        data.appendLittleEndian(UInt16(nameBytes.count))
        data.appendLittleEndian(UInt16(0))
        data.append(nameBytes)
        data.append(bytes)
        entries.append(ZipEntry(name: name, byteCount: UInt32(bytes.count), offset: offset, crc: checksum))
    }

    mutating func finalizeArchive() throws -> Data {
        guard data.count < Int(UInt32.max) else {
            throw NSError(domain: "MDAnyWhere.DOCX", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: L("native.docx.zipLimit")])
        }
        let centralOffset = UInt32(data.count)
        for entry in entries {
            let nameBytes = Data(entry.name.utf8)
            data.appendLittleEndian(UInt32(0x02014b50))
            data.appendLittleEndian(UInt16(20))
            data.appendLittleEndian(UInt16(20))
            data.appendLittleEndian(UInt16(0x0800))
            data.appendLittleEndian(UInt16(0))
            data.appendLittleEndian(UInt16(0)) // DOS time
            data.appendLittleEndian(UInt16(0x21)) // DOS date
            data.appendLittleEndian(entry.crc)
            data.appendLittleEndian(entry.byteCount)
            data.appendLittleEndian(entry.byteCount)
            data.appendLittleEndian(UInt16(nameBytes.count))
            data.appendLittleEndian(UInt16(0))
            data.appendLittleEndian(UInt16(0))
            data.appendLittleEndian(UInt16(0))
            data.appendLittleEndian(UInt16(0))
            data.appendLittleEndian(UInt32(0)) // external file attributes
            data.appendLittleEndian(entry.offset)
            data.append(nameBytes)
        }
        let centralLength = UInt32(data.count) - centralOffset
        data.appendLittleEndian(UInt32(0x06054b50))
        data.appendLittleEndian(UInt16(0))
        data.appendLittleEndian(UInt16(0))
        data.appendLittleEndian(UInt16(entries.count))
        data.appendLittleEndian(UInt16(entries.count))
        data.appendLittleEndian(centralLength)
        data.appendLittleEndian(centralOffset)
        data.appendLittleEndian(UInt16(0))
        return data
    }

    private static func crc32(_ bytes: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0) }
        }
        return ~crc
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        append(contentsOf: [UInt8(value & 0xff), UInt8((value >> 8) & 0xff)])
    }
    mutating func appendLittleEndian(_ value: UInt32) {
        append(contentsOf: (0..<4).map { UInt8((value >> ($0 * 8)) & 0xff) })
    }
}

final class DocxExporter {
    private var layout: DocxLayout
    private let sourceURL: URL?
    private var media: [(name: String, data: Data)] = []
    private var relationships: [String] = []
    private var listNumbers: [String: Int] = [:]
    private var nextListNumber = 3
    private var firstTitleUsed = false
    private var imageIndex = 0

    init(layout: DocxLayout, sourceURL: URL?) {
        var normalized = layout
        normalized.normalize()
        self.layout = normalized
        self.sourceURL = sourceURL
    }

    func exportDocument(blocks: [DocxBlock], title: String, to url: URL) throws {
        guard blocks.count <= 50_000 else {
            throw NSError(domain: "MDAnyWhere.DOCX", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: L("native.docx.tooManyParagraphs")])
        }
        let body = blocks.map(blockXML).joined()
        let section = sectionXML()
        let document = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                    xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
                    xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
                    xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                    xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
          <w:body>\(body)\(section)</w:body>
        </w:document>
        """
        if layout.pageNumbers {
            relationships.append("""
            <Relationship Id="rIdFooter" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
            """)
        }
        var zip = StoredZip()
        try zip.addStoredFile("[Content_Types].xml", utf8XMLData(contentTypes()))
        try zip.addStoredFile("_rels/.rels", utf8XMLData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """))
        try zip.addStoredFile("docProps/core.xml", utf8XMLData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
          xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>\(Self.escapeXMLText(title))</dc:title></cp:coreProperties>
        """))
        try zip.addStoredFile("docProps/app.xml", utf8XMLData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
          <Application>md any where</Application></Properties>
        """))
        try zip.addStoredFile("word/document.xml", utf8XMLData(document))
        try zip.addStoredFile("word/styles.xml", utf8XMLData(stylesXML()))
        try zip.addStoredFile("word/settings.xml", utf8XMLData(settingsXML()))
        try zip.addStoredFile("word/numbering.xml", utf8XMLData(numberingXML()))
        try zip.addStoredFile("word/_rels/document.xml.rels", utf8XMLData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        <Relationship Id="rIdSettings" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
        <Relationship Id="rIdNumbering" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
        \(relationships.joined())
        </Relationships>
        """))
        if layout.pageNumbers { try zip.addStoredFile("word/footer1.xml", utf8XMLData(footerXML())) }
        for item in media { try zip.addStoredFile("word/media/\(item.name)", item.data) }
        try zip.finalizeArchive().write(to: url, options: .atomic)
    }

    private func utf8XMLData(_ text: String) -> Data { Data(text.utf8) }
    private static func escapeXMLText(_ text: String) -> String {
        text.filter { character in
            character == "\n" || character == "\t" ||
                !character.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        }
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    private func twips(_ points: Double) -> Int { Int((points * 20).rounded()) }
    private func millimeterTwips(_ value: Double) -> Int { Int((value * 1440 / 25.4).rounded()) }
    private func halfPoints(_ value: Double) -> Int { Int((value * 2).rounded()) }

    private func contentTypes() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Default Extension="png" ContentType="image/png"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
          <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
          <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
          <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
          \(layout.pageNumbers ? "<Override PartName=\"/word/footer1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml\"/>" : "")
          <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
        </Types>
        """
    }

    private func sectionXML() -> String {
        let size = layout.pageSize == "a4" ? (11906, 16838) : (12240, 15840)
        return """
        <w:sectPr>
          \(layout.pageNumbers ? "<w:footerReference w:type=\"default\" r:id=\"rIdFooter\"/>" : "")
          <w:pgSz w:w="\(size.0)" w:h="\(size.1)"/>
          <w:pgMar w:top="\(millimeterTwips(layout.marginTop))" w:right="\(millimeterTwips(layout.marginRight))"
                   w:bottom="\(millimeterTwips(layout.marginBottom))" w:left="\(millimeterTwips(layout.marginLeft))"
                   w:header="720" w:footer="720" w:gutter="0"/>
        </w:sectPr>
        """
    }

    private func footerXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:fldSimple w:instr="PAGE"/></w:p></w:ftr>
        """
    }

    private func settingsXML() -> String {
        let mathFont = Self.escapeXMLText(layout.mathLatinFont)
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                    xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math">
          <w:compat><w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/></w:compat>
          <m:mathPr><m:mathFont m:val="\(mathFont)"/></m:mathPr>
        </w:settings>
        """
    }

    private func paragraphStyleXML(_ id: String, _ name: String, paragraph: String, run: String,
                       basedOn: String = "Normal", next: String = "Normal") -> String {
        """
        <w:style w:type="paragraph" w:styleId="\(id)">
          <w:name w:val="\(name)"/><w:basedOn w:val="\(basedOn)"/><w:next w:val="\(next)"/>
          <w:pPr>\(paragraph)</w:pPr><w:rPr>\(run)</w:rPr>
        </w:style>
        """
    }

    private func fontXML(latin: String, cjk: String) -> String {
        let safeLatin = Self.escapeXMLText(latin)
        let safeCjk = Self.escapeXMLText(cjk)
        return "<w:rFonts w:ascii=\"\(safeLatin)\" w:hAnsi=\"\(safeLatin)\" w:eastAsia=\"\(safeCjk)\" w:cs=\"\(safeLatin)\"/>"
    }

    private func fontXML(_ name: String) -> String { fontXML(latin: name, cjk: name) }

    private func stylesXML() -> String {
        let normalParagraphProperties = """
        <w:spacing w:after="\(twips(layout.paragraphAfter))"
                   w:line="\(Int((layout.lineSpacing * 240).rounded()))" w:lineRule="auto"/>
        \(layout.firstLineIndent > 0 ? "<w:ind w:firstLine=\"\(millimeterTwips(layout.firstLineIndent))\"/>" : "")
        <w:jc w:val="\(layout.bodyAlign == "justify" ? "both" : layout.bodyAlign)"/>
        """
        let normalRunProperties = "\(fontXML(latin: layout.bodyLatinFont, cjk: layout.bodyCjkFont))<w:color w:val=\"000000\"/><w:sz w:val=\"\(halfPoints(layout.bodySize))\"/>"
        let headingKeepProperties = "<w:keepNext/><w:keepLines/>"
        let headingAlignment = "<w:jc w:val=\"\(layout.headingAlign)\"/>"
        var styles = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:docDefaults><w:rPrDefault><w:rPr>\(normalRunProperties)</w:rPr></w:rPrDefault></w:docDefaults>
        <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
          <w:name w:val="Normal"/><w:pPr>\(normalParagraphProperties)</w:pPr><w:rPr>\(normalRunProperties)</w:rPr>
        </w:style>
        """
        let titleSize = min(layout.bodySize * layout.headingScale * 1.35, 40)
        styles += paragraphStyleXML("Title", "Title",
                        paragraph: headingKeepProperties + "<w:spacing w:before=\"0\" w:after=\"\(twips(16))\"/>" + headingAlignment,
                        run: fontXML(latin: layout.headingLatinFont, cjk: layout.headingCjkFont) + "<w:b/><w:color w:val=\"000000\"/><w:sz w:val=\"\(halfPoints(titleSize))\"/>")
        for level in 1...6 {
            let size = max(layout.bodySize + 0.5, layout.bodySize * (1 + (layout.headingScale - 1) * Double(7 - level) / 6))
            let before = level <= 2 ? 15.0 : 10.0
            styles += paragraphStyleXML("Heading\(level)", "heading \(level)",
                            paragraph: headingKeepProperties + "<w:spacing w:before=\"\(twips(before))\" w:after=\"\(twips(5))\"/>" + headingAlignment,
                            run: fontXML(latin: layout.headingLatinFont, cjk: layout.headingCjkFont) + "<w:b/><w:color w:val=\"000000\"/><w:sz w:val=\"\(halfPoints(size))\"/>")
        }
        styles += paragraphStyleXML("Quote", "Quote",
                        paragraph: "<w:spacing w:before=\"\(twips(4))\" w:after=\"\(twips(7))\"/><w:ind w:left=\"\(millimeterTwips(8))\" w:firstLine=\"0\"/>",
                        run: normalRunProperties)
        styles += paragraphStyleXML("Code", "Code",
                        paragraph: "<w:spacing w:after=\"\(twips(5))\" w:line=\"240\" w:lineRule=\"auto\"/><w:ind w:firstLine=\"0\"/>",
                        run: fontXML(layout.codeFont) + "<w:color w:val=\"000000\"/><w:sz w:val=\"\(halfPoints(max(8, layout.bodySize - 1)))\"/>")
        styles += paragraphStyleXML("Formula", "Formula",
                        paragraph: "<w:spacing w:before=\"\(twips(8))\" w:after=\"\(twips(8))\"/><w:jc w:val=\"center\"/>",
                        run: fontXML(latin: layout.mathLatinFont, cjk: layout.mathCjkFont) + "<w:sz w:val=\"\(halfPoints(layout.bodySize))\"/>")
        styles += paragraphStyleXML("List", "List",
                        paragraph: "<w:spacing w:after=\"\(twips(max(2, layout.paragraphAfter / 2)))\"/><w:ind w:firstLine=\"0\"/>",
                        run: normalRunProperties)
        styles += "</w:styles>"
        return styles
    }

    private func numberingXML() -> String {
        func abstract(_ id: Int, format: String, text: String) -> String {
            var levels = ""
            for level in 0...5 {
                levels += """
                <w:lvl w:ilvl="\(level)"><w:start w:val="1"/><w:numFmt w:val="\(format)"/>
                  <w:lvlText w:val="\(Self.escapeXMLText(format == "decimal" ? "%\(level + 1)." : text))"/>
                  <w:lvlJc w:val="left"/>
                  <w:pPr><w:tabs><w:tab w:val="num" w:pos="\(720 + level * 360)"/></w:tabs>
                    <w:ind w:left="\(720 + level * 360)" w:hanging="360"/></w:pPr></w:lvl>
                """
            }
            return "<w:abstractNum w:abstractNumId=\"\(id)\">\(levels)</w:abstractNum>"
        }
        let bullet = abstract(1, format: "bullet", text: "•")
        let decimal = abstract(2, format: "decimal", text: "%1.")
        let instances = listNumbers.sorted { $0.value < $1.value }.map { key, value in
            "<w:num w:numId=\"\(value)\"><w:abstractNumId w:val=\"2\"/></w:num>"
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        \(bullet)\(decimal)<w:num w:numId="1"><w:abstractNumId w:val="1"/></w:num>\(instances)
        </w:numbering>
        """
    }

    private func blockXML(_ block: DocxBlock) -> String {
        switch block.type {
        case "heading":
            let level = min(max(block.level ?? 1, 1), 6)
            let styleID: String
            if level == 1 && !firstTitleUsed {
                firstTitleUsed = true
                styleID = "Title"
            } else { styleID = "Heading\(level)" }
            return paragraphXML(block.runs ?? [], styleID: styleID)
        case "list":
            let level = min(max(block.level ?? 0, 0), 5)
            let number: Int
            if block.ordered == true {
                let key = block.listID ?? "list-\(nextListNumber)"
                if let known = listNumbers[key] { number = known }
                else { number = nextListNumber; listNumbers[key] = number; nextListNumber += 1 }
            } else { number = 1 }
            let extra = "<w:numPr><w:ilvl w:val=\"\(level)\"/><w:numId w:val=\"\(number)\"/></w:numPr>"
            return paragraphXML(block.runs ?? [], styleID: "List", extra: extra)
        case "quote": return paragraphXML(block.runs ?? [], styleID: "Quote")
        case "task":
            return paragraphXML(block.runs ?? [], styleID: "List",
                                extra: "<w:ind w:left=\"\(millimeterTwips(8))\" w:firstLine=\"0\"/>")
        case "code":
            let run = DocxRun(text: block.text ?? "", code: true)
            return paragraphXML([run], styleID: "Code")
        case "math":
            guard let math = block.math else { return paragraphXML(block.runs ?? []) }
            let xml = serializeMathNodeXML(math)
            return "<w:p><w:pPr><w:pStyle w:val=\"Formula\"/></w:pPr><m:oMathPara><m:oMathParaPr><m:jc m:val=\"center\"/></m:oMathParaPr><m:oMath>\(xml)</m:oMath></m:oMathPara></w:p>"
        case "table": return tableXML(block.rows ?? [])
        case "rule":
            return "<w:p><w:pPr><w:pBdr><w:bottom w:val=\"single\" w:sz=\"4\" w:color=\"D9D9D9\"/></w:pBdr></w:pPr></w:p>"
        default: return paragraphXML(block.runs ?? [])
        }
    }

    private func paragraphXML(_ runs: [DocxRun], styleID: String = "Normal", extra: String = "") -> String {
        "<w:p><w:pPr><w:pStyle w:val=\"\(styleID)\"/>\(extra)</w:pPr>\(runs.map(runXML).joined())</w:p>"
    }

    private func runXML(_ run: DocxRun) -> String {
        if run.kind == "math", let node = run.math {
            return "<m:oMath>\(serializeMathNodeXML(node))</m:oMath>"
        }
        if run.kind == "image" {
            if let drawing = imageXML(run) { return drawing }
            let name = run.alt?.isEmpty == false ? run.alt! : (run.source ?? L("native.image"))
            return textXML(L("native.docx.imagePlaceholder", name), properties: "")
        }
        // CT_RPr has a fixed child order. Word rejects runs that put font or
        // size after underline/vertical alignment even when the XML parses.
        let props = (run.code == true ? fontXML(layout.codeFont) : "")
            + (run.bold == true ? "<w:b/>" : "")
            + (run.italic == true ? "<w:i/>" : "")
            + (run.strike == true ? "<w:strike/>" : "")
            + (run.code == true ? "<w:sz w:val=\"\(halfPoints(max(8, layout.bodySize - 1)))\"/>" : "")
            + (run.underline == true ? "<w:u w:val=\"single\"/>" : "")
            + (run.superscript == true ? "<w:vertAlign w:val=\"superscript\"/>" : "")
        return textXML(run.text ?? "", properties: props)
    }

    private func textXML(_ text: String, properties: String) -> String {
        let lines = text.components(separatedBy: "\n")
        return lines.enumerated().map { index, segment in
            let breakTag = index > 0 ? "<w:br/>" : ""
            let value = segment.isEmpty ? "" : "<w:t xml:space=\"preserve\">\(Self.escapeXMLText(segment))</w:t>"
            return "<w:r>\(properties.isEmpty ? "" : "<w:rPr>\(properties)</w:rPr>")\(breakTag)\(value)</w:r>"
        }.joined()
    }

    private func tableXML(_ rows: [[DocxCell]]) -> String {
        guard !rows.isEmpty else { return "" }
        let columns = min(max(rows.map(\.count).max() ?? 1, 1), 12)
        let pageWidth = layout.pageSize == "a4" ? 11906 : 12240
        let available = pageWidth - millimeterTwips(layout.marginLeft + layout.marginRight)
        let width = max(600, available / columns)
        let grid = (0..<columns).map { _ in "<w:gridCol w:w=\"\(width)\"/>" }.joined()
        let border = "<w:top/><w:left/><w:bottom/><w:right/><w:insideH/><w:insideV/>"
            .replacingOccurrences(of: "/>", with: " w:val=\"single\" w:sz=\"4\" w:color=\"D9D9D9\"/>")
        let rowsXML = rows.map { row in
            let cells = (0..<columns).map { index in
                let cell = index < row.count ? row[index] : DocxCell(runs: [])
                let shade = cell.header == true ? "<w:shd w:val=\"clear\" w:fill=\"E7EDF4\"/>" : ""
                let tcPr = "<w:tcPr><w:tcW w:w=\"\(width)\" w:type=\"dxa\"/>\(shade)<w:vAlign w:val=\"center\"/></w:tcPr>"
                let runs = cell.header == true ? cell.runs.map { item -> DocxRun in
                    var result = item
                    result.bold = true
                    return result
                } : cell.runs
                return "<w:tc>\(tcPr)\(paragraphXML(runs, extra: "<w:ind w:firstLine=\"0\"/>"))</w:tc>"
            }.joined()
            return "<w:tr>\(row.first?.header == true ? "<w:trPr><w:tblHeader/></w:trPr>" : "")\(cells)</w:tr>"
        }.joined()
        return "<w:tbl><w:tblPr><w:tblW w:w=\"\(available)\" w:type=\"dxa\"/><w:tblBorders>\(border)</w:tblBorders><w:tblCellMar><w:top w:w=\"100\" w:type=\"dxa\"/><w:left w:w=\"100\" w:type=\"dxa\"/><w:bottom w:w=\"100\" w:type=\"dxa\"/><w:right w:w=\"100\" w:type=\"dxa\"/></w:tblCellMar></w:tblPr><w:tblGrid>\(grid)</w:tblGrid>\(rowsXML)</w:tbl>"
    }

    private func imageXML(_ run: DocxRun) -> String? {
        guard let source = run.source, !source.isEmpty, let bytes = loadDocumentImage(source),
              let imageSource = CGImageSourceCreateWithData(bytes as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let sourceWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let sourceHeight = properties[kCGImagePropertyPixelHeight] as? Int,
              sourceWidth > 0, sourceHeight > 0,
              Double(sourceWidth) * Double(sourceHeight) <= 80_000_000,
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400,
                kCGImageSourceShouldCacheImmediately: false
              ] as CFDictionary) else { return nil }
        #if canImport(AppKit)
        let bitmap = NSBitmapImageRep(cgImage: thumbnail)
        guard
              let png = bitmap.representation(using: .png, properties: [:]),
              bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 else { return nil }
        let pixelWidth = bitmap.pixelsWide
        let pixelHeight = bitmap.pixelsHigh
        #else
        let pngData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(pngData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, thumbnail, nil)
        guard CGImageDestinationFinalize(destination), thumbnail.width > 0, thumbnail.height > 0 else { return nil }
        let png = pngData as Data
        let pixelWidth = thumbnail.width
        let pixelHeight = thumbnail.height
        #endif
        imageIndex += 1
        let name = "image\(imageIndex).png"
        let id = "rIdImage\(imageIndex)"
        media.append((name, png))
        relationships.append("<Relationship Id=\"\(id)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/\(name)\"/>")
        let pageWidth = layout.pageSize == "a4" ? 11906 : 12240
        let widthTwips = pageWidth - millimeterTwips(layout.marginLeft + layout.marginRight)
        let maxEMU = Int64(Double(widthTwips) / 1440 * 914400)
        let preferred = Int64(Double(pixelWidth) / 96 * 914400)
        let cx = min(maxEMU, max(180_000, preferred))
        let cy = max(180_000, Int64(Double(cx) * Double(pixelHeight) / Double(pixelWidth)))
        let description = Self.escapeXMLText(run.alt ?? "")
        return """
        <w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">
          <wp:extent cx="\(cx)" cy="\(cy)"/><wp:docPr id="\(imageIndex)" name="Picture \(imageIndex)" descr="\(description)"/>
          <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="\(name)"/><pic:cNvPicPr/></pic:nvPicPr>
              <pic:blipFill><a:blip r:embed="\(id)"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
              <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
            </pic:pic>
          </a:graphicData></a:graphic>
        </wp:inline></w:drawing></w:r>
        """
    }

    private func loadDocumentImage(_ source: String) -> Data? {
        let maxImageBytes = 20 * 1024 * 1024
        if source.hasPrefix("data:image/"),
           let comma = source.firstIndex(of: ","),
           source[..<comma].lowercased().contains(";base64") {
            let encoded = source[source.index(after: comma)...]
            guard encoded.utf8.count <= maxImageBytes * 4 / 3 + 4,
                  let bytes = Data(base64Encoded: String(encoded)),
                  bytes.count <= maxImageBytes else { return nil }
            return bytes
        }
        guard !source.contains("://"), !source.hasPrefix("//"),
              !source.hasPrefix("/"), let sourceURL else { return nil }
        let path = source.removingPercentEncoding ?? source
        let baseURL = sourceURL.deletingLastPathComponent().standardizedFileURL
        let url = URL(fileURLWithPath: path, relativeTo: baseURL).standardizedFileURL
        guard url.isFileURL,
              url.path.hasPrefix(baseURL.path + "/"),
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maxImageBytes else { return nil }
        return try? Data(contentsOf: url)
    }

    private func serializeMathNodeXML(_ node: DocxMathNode) -> String {
        let children = node.children ?? []
        func at(_ index: Int) -> String { index < children.count ? serializeMathNodeXML(children[index]) : "" }
        func mathTextXML(_ value: String) -> String {
            let fonts = fontXML(latin: layout.mathLatinFont, cjk: layout.mathCjkFont)
            return "<m:r><w:rPr>\(fonts)</w:rPr><m:t xml:space=\"preserve\">\(Self.escapeXMLText(value))</m:t></m:r>"
        }
        let inner = children.map(serializeMathNodeXML).joined()
        switch node.type {
        case "math", "mrow", "semantics", "mstyle", "mpadded", "menclose", "mphantom": return inner
        case "annotation", "annotation-xml": return ""
        case "mi", "mn", "mo", "mtext":
            let value = node.text ?? ""
            if value == "\u{2062}" || value == "\u{2061}" { return "" }
            return mathTextXML(value)
        case "mspace": return mathTextXML(" ")
        case "mfrac": return "<m:f><m:num>\(at(0))</m:num><m:den>\(at(1))</m:den></m:f>"
        case "msup": return "<m:sSup><m:e>\(at(0))</m:e><m:sup>\(at(1))</m:sup></m:sSup>"
        case "msub": return "<m:sSub><m:e>\(at(0))</m:e><m:sub>\(at(1))</m:sub></m:sSub>"
        case "msubsup": return "<m:sSubSup><m:e>\(at(0))</m:e><m:sub>\(at(1))</m:sub><m:sup>\(at(2))</m:sup></m:sSubSup>"
        case "msqrt": return "<m:rad><m:radPr><m:degHide m:val=\"1\"/></m:radPr><m:deg/><m:e>\(inner)</m:e></m:rad>"
        case "mroot": return "<m:rad><m:deg>\(at(1))</m:deg><m:e>\(at(0))</m:e></m:rad>"
        case "mover": return "<m:limUpp><m:e>\(at(0))</m:e><m:lim>\(at(1))</m:lim></m:limUpp>"
        case "munder": return "<m:limLow><m:e>\(at(0))</m:e><m:lim>\(at(1))</m:lim></m:limLow>"
        case "munderover":
            return "<m:limUpp><m:e><m:limLow><m:e>\(at(0))</m:e><m:lim>\(at(1))</m:lim></m:limLow></m:e><m:lim>\(at(2))</m:lim></m:limUpp>"
        case "mfenced":
            let open = Self.escapeXMLText(node.open ?? "("), close = Self.escapeXMLText(node.close ?? ")")
            return "<m:d><m:dPr><m:begChr m:val=\"\(open)\"/><m:endChr m:val=\"\(close)\"/></m:dPr><m:e>\(inner)</m:e></m:d>"
        case "mtable": return "<m:m>\(inner)</m:m>"
        case "mtr": return "<m:mr>\(inner)</m:mr>"
        case "mtd": return "<m:e>\(inner)</m:e>"
        default:
            if children.isEmpty, let text = node.text, !text.isEmpty {
                return mathTextXML(text)
            }
            return inner
        }
    }
}
