import Foundation
import Foundation

/// Handles translation requests by orchestrating a provider and a language detector.
public final class TranslationService {
    private let provider: TranslationProvider
    private let languageDetector: LanguageDetector

    public init(provider: TranslationProvider, languageDetector: LanguageDetector) {
        self.provider = provider
        self.languageDetector = languageDetector
    }

    /// Translates a given text string.
    /// - Parameter text: The text to translate.
    /// - Returns: A tuple containing the source language, target language, and translated text.
    /// - Throws: An error if translation fails.
    public func translate(_ text: String) async throws -> (source: String, target: String, result: String) {
        let (sourceLang, targetLang) = languageDetector.determineLanguageDirection(for: text)

        let result = try await provider.translate(text: text, from: sourceLang, to: targetLang)
        return (sourceLang, targetLang, result)
    }
}

