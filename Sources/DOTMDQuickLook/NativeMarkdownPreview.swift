import AppKit
import Foundation

/// A small, offline Quick Look renderer. It deliberately uses AppKit rather
/// than a web view: WebKit's child process can fail to launch inside Finder's
/// sandboxed preview host, leaving an otherwise valid document entirely blank.
enum NativeMarkdownPreview {
    private static let inlinePattern = try! NSRegularExpression(pattern:
        #"\*\*(.+?)\*\*|(?<!\*)\*([^*]+)\*(?!\*)|`([^`]+)`|\[([^\]]+)\]\([^)]+\)"#)

    static func render(source: String, title: String, truncated: Bool) -> NSAttributedString {
        let output = NSMutableAttributedString()
        append(title, to: output, size: 24, weight: .bold, spacing: 17)
        if truncated {
            append("仅显示前 1 MiB；请在 DOT MD 中打开完整文稿。", to: output,
                   size: 13, color: .secondaryLabelColor)
        }

        var insideFence = false
        var fenceLanguage = ""
        for rawLine in source.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if insideFence {
                    insideFence = false
                    fenceLanguage = ""
                    append("", to: output, size: 6, spacing: 5)
                } else {
                    insideFence = true
                    fenceLanguage = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    if fenceLanguage.lowercased() == "mermaid" {
                        append("流程图 · 完整图形请在 DOT MD 中查看", to: output,
                               size: 13, weight: .semibold, color: .secondaryLabelColor)
                    }
                }
                continue
            }
            if insideFence {
                append(rawLine, to: output, size: 13, monospaced: true, spacing: 1)
                continue
            }
            if trimmed.isEmpty {
                append("", to: output, size: 7, spacing: 0)
                continue
            }
            let headingMarks = trimmed.prefix { $0 == "#" }.count
            if (1...6).contains(headingMarks),
               trimmed.dropFirst(headingMarks).first == " " {
                let text = String(trimmed.dropFirst(headingMarks + 1))
                let size: CGFloat = [25, 21, 18, 16, 15, 14][headingMarks - 1]
                append(text, to: output, size: size, weight: .bold, spacing: 12, inline: true)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                append("• " + String(trimmed.dropFirst(2)), to: output, size: 15,
                       spacing: 4, indent: 21, inline: true)
            } else if trimmed.hasPrefix("> ") {
                append("▏ " + String(trimmed.dropFirst(2)), to: output, size: 15,
                       color: .secondaryLabelColor, spacing: 7, indent: 20, inline: true)
            } else if trimmed == "---" || trimmed == "***" {
                append("────────────────────────────", to: output, size: 12,
                       color: .tertiaryLabelColor, spacing: 8)
            } else {
                append(trimmed, to: output, size: 15, spacing: 7, inline: true)
            }
        }
        return output
    }

    private static func append(_ text: String, to output: NSMutableAttributedString,
                               size: CGFloat, weight: NSFont.Weight = .regular,
                               color: NSColor = .labelColor, monospaced: Bool = false,
                               spacing: CGFloat = 7, indent: CGFloat = 0,
                               inline: Bool = false) {
        let font = monospaced ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
                              : NSFont.systemFont(ofSize: size, weight: weight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = monospaced ? 1 : 4
        paragraph.paragraphSpacing = spacing
        paragraph.firstLineHeadIndent = 0
        paragraph.headIndent = indent
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ]
        if inline {
            appendInline(text, to: output, attributes: attributes, size: size)
        } else {
            output.append(NSAttributedString(string: text, attributes: attributes))
        }
        output.append(NSAttributedString(string: "\n", attributes: attributes))
    }

    private static func appendInline(_ text: String, to output: NSMutableAttributedString,
                                     attributes: [NSAttributedString.Key: Any], size: CGFloat) {
        let matches = inlinePattern.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
        var cursor = text.startIndex
        for match in matches {
            guard let full = Range(match.range, in: text), full.lowerBound >= cursor else { continue }
            output.append(NSAttributedString(string: String(text[cursor..<full.lowerBound]), attributes: attributes))
            var styled = attributes
            for group in 1...4 where match.range(at: group).location != NSNotFound {
                guard let range = Range(match.range(at: group), in: text) else { continue }
                switch group {
                case 1: styled[.font] = NSFont.systemFont(ofSize: size, weight: .bold)
                case 2: styled[.font] = NSFontManager.shared.convert(NSFont.systemFont(ofSize: size), toHaveTrait: .italicFontMask)
                case 3:
                    styled[.font] = NSFont.monospacedSystemFont(ofSize: size - 1, weight: .regular)
                    styled[.backgroundColor] = NSColor.quaternaryLabelColor.withAlphaComponent(0.14)
                case 4:
                    styled[.foregroundColor] = NSColor.linkColor
                    styled[.underlineStyle] = NSUnderlineStyle.single.rawValue
                default: break
                }
                output.append(NSAttributedString(string: String(text[range]), attributes: styled))
                break
            }
            cursor = full.upperBound
        }
        output.append(NSAttributedString(string: String(text[cursor...]), attributes: attributes))
    }
}
