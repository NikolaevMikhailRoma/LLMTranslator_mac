import Foundation
import NaturalLanguage

/// High-level translation service used by the app UI.
/// It owns a provider chosen according to the current configuration
/// and exposes a minimal API: input text -> output text.
public actor TranslationService {
    private let provider: TranslationProvider
    private let languageDetector: LanguageDetector

    init(provider: TranslationProvider, languageDetector: LanguageDetector) {
        self.provider = provider
        self.languageDetector = languageDetector
    }

    public func translate(_ text: String) async throws -> (result: String, source: String, target: String) {
        let (src, dst) = languageDetector.determineLanguageDirection(for: text)
        let translated = try await provider.translate(text: text, from: src, to: dst)
        return (translated, src, dst)
    }
}

