import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw NSError(domain: "NativeLocalizationTests", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: message]) }
}

@main
struct NativeLocalizationTests {
    static func main() throws {
        let expected = CommandLine.arguments.first(where: { $0.hasPrefix("--expect=") })?.dropFirst(9).description ?? "en-US"
        let cases: [(String, String)] = [
            ("zh-TW", "zh-Hant"), ("zh-HK", "zh-Hant"), ("zh-Hans-CN", "zh-Hans"),
            ("zh-Hans-HK", "zh-Hans"), ("zh-Hant-CN", "zh-Hant"),
            ("en-Latn-GB", "en-GB"), ("en-Latn-AU", "en-AU"), ("en-Latn-CA", "en-CA"),
            ("en_NZ", "en-GB"), ("en-CA", "en-CA"), ("en-IN", "en-US"),
            ("fr-BE", "fr-FR"), ("fr-CA", "fr-CA"), ("nb-NO", "no"), ("nn-NO", "no"),
            ("es-419", "es-MX"), ("es-AR", "es-MX"), ("es-ES", "es-ES"),
            ("pt", "pt-PT"), ("pt-BR", "pt-BR"), ("ar-EG", "ar-SA"), ("sl", "sl-SI"),
            ("bn-IN", "bn-BD"), ("gu", "gu-IN"), ("ur", "ur-PK"), ("iw-IL", "he")
        ]
        for (input, output) in cases {
            try require(InterfaceLocalization.resolvedLocale(language: "system", systemLanguages: [input]) == output,
                        "Locale matching failed: \(input) → \(output)")
        }
        for locale in InterfaceLocalization.supportedLocales {
            try require(InterfaceLocalization.canonicalLanguage(locale) == locale, "Exact locale lost: \(locale)")
        }
        try require(Set(InterfaceLocalization.supportedLocales).count == 50, "Expected 50 unique store locales")
        try require(InterfaceLocalization.resolvedLocale(language: "system", systemLanguages: ["xx-ZZ", "ja-JP"]) == "ja", "System preference order lost")
        try require(InterfaceLocalization.resolvedLocale(language: "system", systemLanguages: ["xx-ZZ"]) == "en-US", "English fallback failed")
        try require(InterfaceLocalization.resolvedLocale(language: "fr-CA", systemLanguages: ["zh-CN"]) == "fr-CA", "Manual preference did not override system")
        try require(InterfaceLocalization.canonicalLanguage("../../en") == nil, "Unsafe language identifier accepted")
        try require(!InterfaceLocalization.setLanguage("../../en"), "Unsafe preference persisted")
        try require(InterfaceLocalization.locale == expected, "Launch preference was not used")
        try require(InterfaceLocalization.format("{1}: {0}; {0}", arguments: ["📄 a{1}.md", "雪"]) == "雪: 📄 a{1}.md; 📄 a{1}.md", "Replacement reinterpreted user text")
        try require(InterfaceLocalization.format("{2} {0}", arguments: ["x"]) == "{2} x", "Missing argument handling changed")
        try require(L("native.save") == (expected == "zh-Hans" ? "保存" : "Save"), "Bundled native catalog was not loaded")
        try require(L("native.close.title", "a{0}😀.md").contains("a{0}😀.md"), "Filename interpolation corrupted content")
        try require(L("native.error.unknown") == "Unknown error", "Compiled English fallback failed")
        try require(InterfaceLocalization.initialJavaScript.contains("mdAnyWhereLocalePreferences"), "Initial native preferences missing")
        try require(InterfaceLocalization.synchronizationJavaScript.contains("setInterfaceLanguage"), "Language synchronization bridge missing")
        print("Native localization passed: \(expected), 50 exact locales, region aliases, fallback, safe interpolation, bundle resources.")
    }
}
