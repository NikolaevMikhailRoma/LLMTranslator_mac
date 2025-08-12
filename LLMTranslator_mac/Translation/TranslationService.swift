import Foundation
import NaturalLanguage

/// High-level translation service used by the app UI.
/// It owns a provider chosen according to the current configuration
/// and exposes a minimal API: input text -> output text.
public actor TranslationService {
    public static let shared = TranslationService()

    private var provider: TranslationProvider

    private init() {
        // Pick provider based on the current configuration mode.
        switch SettingsStore.shared.config.mode {
        case .offline:
            self.provider = LMStudioProvider()
        case .online:
            // For now, reuse LMStudioProvider interface targeting online endpoint.
            self.provider = LMStudioProvider()
        }
    }

    /// Updates the underlying provider if configuration changes require it.
    /// This can be called from settings UI after the user changes the engine.
    public func reloadProviderIfNeeded() {
        // Currently both modes use the same provider class but different endpoints.
        // If in the future we add a dedicated OnlineProvider, switch here.
        switch SettingsStore.shared.config.mode {
        case .offline:
            self.provider = LMStudioProvider()
        case .online:
            self.provider = LMStudioProvider()
        }
    }

    /// Translates text using the selected provider.
    /// - Parameter text: Input text.
    /// - Returns: Translated text.
    public func translate(_ text: String) async throws -> (result: String, source: String, target: String) {
        let (src, dst) = determineLanguageDirectionByCounting(for: text)
        let translated = try await provider.translate(text: text, from: src, to: dst)
        return (translated, src, dst)
    }

    /// Determines source and target language codes by counting characters per language.
    /// Rules:
    /// - Count characters using regex patterns from settings (or built-in defaults).
    /// - Source is the language with the highest count among supported languages.
    /// - Target is the first language in settings different from the source; if none, fallback to the other if available.
    private func determineLanguageDirectionByCounting(for text: String) -> (String, String) {
        let cfg = SettingsStore.shared.config
        let languages = cfg.languageCodes.map { $0.lowercased() }
        guard !languages.isEmpty else { return ("en", "ru") }

        // Build regexes map (language -> NSRegularExpression)
        var langToRegex: [String: NSRegularExpression] = [:]
        for code in languages {
            let pattern: String
            if let custom = cfg.languageDetectionRegexes?[code], !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pattern = custom
            } else {
                // Built-in defaults for common languages
                switch code {
                case "ru": pattern = "[\\p{Cyrillic}]" // Cyrillic script
                case "en": pattern = "[A-Za-z]" // Latin letters
                default: pattern = "[A-Za-z\\p{Cyrillic}]" // fallback covers en/ru mix
                }
            }
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                langToRegex[code] = regex
            }
        }

        // Count matches per language
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var bestLang = languages.first!
        var bestCount = -1
        for code in languages {
            guard let regex = langToRegex[code] else { continue }
            let count = regex.numberOfMatches(in: text, options: [], range: fullRange)
            if count > bestCount { bestCount = count; bestLang = code }
        }

        let source = bestLang
        // Target: the first language in settings different from source
        let target = languages.first(where: { $0 != source }) ?? (languages.count > 1 ? languages[1] : (source == "en" ? "ru" : "en"))
        return (source, target)
    }
}

