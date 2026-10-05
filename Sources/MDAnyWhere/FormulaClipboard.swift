import AppKit

@MainActor
enum FormulaClipboard {
    static func copyFormulaToPasteboard(latex: String, mathML: String, svg: String, target: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let linearFormula = latexToUnicodeMath(latex)
        let plain: String
        switch target {
        case "latex": plain = latex
        case "mathml": plain = mathML
        case "svg": plain = svg
        case "word", "wps": plain = latex
        default: plain = linearFormula
        }
        let html = "<html><body><span class=\"md-any-where-equation\">\(mathML)</span></body></html>"
        var types: [NSPasteboard.PasteboardType] = [.string, .html]
        let mathMLType = NSPasteboard.PasteboardType("application/mathml+xml")
        types.append(mathMLType)
        if !svg.isEmpty { types.append(.init("public.svg-image")) }
        pasteboard.declareTypes(types, owner: nil)
        pasteboard.setString(plain, forType: .string)
        pasteboard.setString(html, forType: .html)
        pasteboard.setString(mathML, forType: mathMLType)
        if !svg.isEmpty { pasteboard.setString(svg, forType: .init("public.svg-image")) }
    }

    private static func latexToUnicodeMath(_ latex: String) -> String {
        latex
            .replacingOccurrences(of: "\\cdot", with: "⋅")
            .replacingOccurrences(of: "\\times", with: "×")
            .replacingOccurrences(of: "\\leq", with: "≤")
            .replacingOccurrences(of: "\\geq", with: "≥")
            .replacingOccurrences(of: "\\neq", with: "≠")
            .replacingOccurrences(of: "\\infty", with: "∞")
            .replacingOccurrences(of: "\\pi", with: "π")
            .replacingOccurrences(of: "\\alpha", with: "α")
            .replacingOccurrences(of: "\\beta", with: "β")
            .replacingOccurrences(of: "\\gamma", with: "γ")
            .replacingOccurrences(of: "\\theta", with: "θ")
            .replacingOccurrences(of: "\\sum", with: "∑")
            .replacingOccurrences(of: "\\int", with: "∫")
            .replacingOccurrences(of: "\\sqrt", with: "√")
            .replacingOccurrences(of: "\\left", with: "")
            .replacingOccurrences(of: "\\right", with: "")
    }
}
