import Foundation
import RegexBuilder
import os.log

public class LanguageDetector {
    private let config: AppConfig

    init(config: AppConfig) {
        self.config = config
    }

    func determineLanguageDirection(for text: String) -> (source: String, target: String) {
        let languages = config.languageCodes.map { $0.lowercased() }
        guard !languages.isEmpty else { return ("en", "ru") }

        var langToRegex: [String: Regex<AnyRegexOutput>] = [:]
        let defaultPattern = try! Regex(#"[\p{Script=Latin}]"#) // Known to be safe

        for code in languages {
            var pattern: Regex<AnyRegexOutput>
            if let customPatternString = config.languageDetectionRegexes?[code], !customPatternString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                do {
                    pattern = try Regex(customPatternString)
                } catch {
                    os_log("Invalid regex for language '%@': %@. Falling back to default.", type: .error, code, String(describing: error))
                    pattern = defaultPattern
                }
            } else {
                switch code {
                case "ru":
                    // This regex is known to be safe, so try! is acceptable here.
                    pattern = try! Regex(#"[\p{Script=Cyrillic}]"#)
                case "en":
                    pattern = defaultPattern
                default:
                    pattern = defaultPattern
                }
            }
            langToRegex[code] = pattern
        }

        let fullRange = text.startIndex..<text.endIndex
        var bestLang = languages.first!
        var bestCount = -1
        for code in languages {
            guard let regex = langToRegex[code] else { continue }
            let count = text.matches(of: regex).count
            if count > bestCount { bestCount = count; bestLang = code }
        }

        let source = bestLang
        let target = languages.first(where: { $0 != source }) ?? (languages.count > 1 ? languages[1] : (source == "en" ? "ru" : "en"))
        return (source, target)
    }
}
