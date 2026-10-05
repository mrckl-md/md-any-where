import Foundation

/// Shared by the macOS app, iOS app, command-line helper, and Quick Look.
/// Catalogs are packaged beside the editor, with English compiled in as a
/// fallback for damaged/missing resources and standalone command-line tests.
public enum InterfaceLocalization {
    public static let preferenceKey = "mdanywhere.interfaceLanguage"
    public static let supportedLocales = [
        "ar-SA", "bn-BD", "ca", "zh-Hans", "zh-Hant", "hr", "cs", "da", "nl-NL",
        "en-AU", "en-CA", "en-GB", "en-US", "fi", "fr-FR", "fr-CA", "de-DE", "el",
        "gu-IN", "he", "hi", "hu", "id", "it", "ja", "kn-IN", "ko", "ms", "ml-IN",
        "mr-IN", "no", "or-IN", "pl", "pt-BR", "pt-PT", "pa-IN", "ro", "ru", "sk",
        "sl-SI", "es-MX", "es-ES", "sv", "ta-IN", "te-IN", "th", "tr", "uk", "ur-PK", "vi"
    ]

    private static var defaults: UserDefaults {
        let identifier = Bundle.main.bundleIdentifier ?? ""
        if identifier == "app.mdanywhere.editor.agent" || identifier.hasPrefix("app.mdanywhere.editor.quicklook") ||
           identifier == "app.mdanywhere.editor.thumbnail" {
            return UserDefaults(suiteName: "app.mdanywhere.editor") ?? .standard
        }
        return .standard
    }

    public static var language: String {
        guard let stored = defaults.string(forKey: preferenceKey),
              stored == "system" || canonicalLanguage(stored) != nil else { return "system" }
        return stored
    }

    /// Only supported language identifiers are accepted across the message bridge.
    @discardableResult public static func setLanguage(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value == "system" || canonicalLanguage(value) != nil else { return false }
        defaults.set(value == "system" ? value : canonicalLanguage(value)!, forKey: preferenceKey)
        return true
    }

    public static var locale: String {
        resolvedLocale(language: language, systemLanguages: Locale.preferredLanguages)
    }

    public static func resolvedLocale(language: String, systemLanguages: [String]) -> String {
        if language != "system", let match = canonicalLanguage(language) { return match }
        for language in systemLanguages {
            if let match = canonicalLanguage(language) { return match }
        }
        return "en-US"
    }

    /// BCP 47 matching also accepts platform aliases and region variants not
    /// separately offered in App Store Connect (for example nb-NO and zh-TW).
    public static func canonicalLanguage(_ value: String) -> String? {
        let value = value.replacingOccurrences(of: "_", with: "-").lowercased()
        if value == "en" { return "en-US" }
        if let exact = supportedLocales.first(where: { $0.lowercased() == value }) { return exact }
        let components = value.split(separator: "-").map(String.init)
        guard let base = components.first else { return nil }
        if base == "zh" {
            // Explicit script wins over a region's usual writing system.
            if components.contains("hans") { return "zh-Hans" }
            if components.contains("hant") { return "zh-Hant" }
            return components.contains("tw") || components.contains("hk") || components.contains("mo") ? "zh-Hant" : "zh-Hans"
        }
        if base == "nb" || base == "nn" { return "no" }
        if base == "en" {
            if components.contains("au") { return "en-AU" }
            if components.contains("ca") { return "en-CA" }
            if components.contains("gb") || components.contains("nz") { return "en-GB" }
            return "en-US"
        }
        if base == "es" { return components.count == 1 || components.dropFirst().contains("es") ? "es-ES" : "es-MX" }
        if base == "fr" { return components.contains("ca") ? "fr-CA" : "fr-FR" }
        if base == "pt" { return components.contains("br") ? "pt-BR" : "pt-PT" }
        let preferred: [String: String] = ["iw": "he", "in": "id"]
        if let match = preferred[base] { return match }
        return supportedLocales.first { $0.lowercased().split(separator: "-").first.map(String.init) == base }
    }

    public static var initialJavaScript: String {
        let object: [String: Any] = ["language": language, "systemLanguages": Locale.preferredLanguages]
        let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "window.mdAnyWhereLocalePreferences = \(json);"
    }

    public static var synchronizationJavaScript: String {
        let data = try? JSONSerialization.data(withJSONObject: [language, Locale.preferredLanguages] as [Any])
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"system\",[]]"
        return "window.setInterfaceLanguage?.apply(window, \(json));"
    }

    public static func text(_ key: String, arguments: [String] = []) -> String {
        let language = locale
        let localized = catalogs.values(for: language)[key]
        let english = catalogs.values(for: "en")[key]
        let template = localized ?? english ?? englishFallback[key] ?? key
        return format(template, arguments: arguments)
    }

    /// Replace tokens in one pass so braces in user filenames/content are never
    /// interpreted again, even if a translation reorders or repeats arguments.
    public static func format(_ template: String, arguments: [String]) -> String {
        let pattern = #"\{([0-9]+)\}"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return template }
        let matches = expression.matches(in: template, range: NSRange(template.startIndex..., in: template))
        var result = template
        for match in matches.reversed() {
            guard let numberRange = Range(match.range(at: 1), in: template),
                  let number = Int(template[numberRange]), arguments.indices.contains(number),
                  let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: arguments[number])
        }
        return result
    }

    private static let catalogs = LocalizationCatalogs()
}

public func L(_ key: String, _ arguments: Any...) -> String {
    InterfaceLocalization.text(key, arguments: arguments.map { String(describing: $0) })
}

/// The lock protects only the in-memory cache. Catalogs are immutable bundle
/// resources and are never downloaded or read from user document locations.
private final class LocalizationCatalogs: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: [String: String]] = [:]
    private let directories: [URL]

    init() {
        var directories: [URL] = []
        if let resources = Bundle.main.resourceURL {
            directories.append(resources.appendingPathComponent("Editor/locales"))
            directories.append(resources.appendingPathComponent("Resources/locales"))
        }
        if let executable = Bundle.main.executableURL {
            let executableDirectory = executable.deletingLastPathComponent()
            directories.append(executableDirectory.appendingPathComponent("MDAnyWhere_MDAnyWhere.bundle/Resources/locales"))
            directories.append(executableDirectory.appendingPathComponent("MDAnyWhere_MDAnyWhere.bundle/Contents/Resources/Resources/locales"))
            var parent = executableDirectory
            for _ in 0..<7 {
                if parent.pathExtension == "app" {
                    directories.append(parent.appendingPathComponent("Contents/Resources/Editor/locales"))
                    directories.append(parent.appendingPathComponent("Editor/locales"))
                    break
                }
                parent.deleteLastPathComponent()
            }
        }
        self.directories = directories
    }

    func values(for language: String) -> [String: String] {
        lock.lock(); defer { lock.unlock() }
        if let found = cache[language] { return found }
        for directory in directories {
            let url = directory.appendingPathComponent(language).appendingPathExtension("json")
            if let data = try? Data(contentsOf: url),
               let values = try? JSONDecoder().decode([String: String].self, from: data) {
                cache[language] = values
                return values
            }
        }
        cache[language] = [:]
        return [:]
    }
}
