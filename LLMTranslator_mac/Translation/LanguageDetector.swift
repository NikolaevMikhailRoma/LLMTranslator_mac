import Foundation
import RegexBuilder

class LanguageDetector {
    private let config: AppConfig

    init(config: AppConfig) {
        self.config = config
    }

    func determineLanguageDirection(for text: String) -> (source: String, target: String) {
        let languages = config.languageCodes.map { $0.lowercased() }
        guard !languages.isEmpty else { return ("en", "ru") }

        var langToRegex: [String: Regex<AnyRegexOutput>] = [:]
        for code in languages {
            let pattern: Regex<AnyRegexOutput>
            if let custom = config.languageDetectionRegexes?[code], !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pattern = try! Regex(custom)
            } else {
                switch code {
                case "ru":
                    pattern = try! Regex(#"[\p{Script=Cyrillic}]"#)
                case "en":
                    pattern = try! Regex(#"[\p{Script=Latin}]"#)
                default:
                    pattern = try! Regex(#"[\p{Script=Latin}]"#)
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
