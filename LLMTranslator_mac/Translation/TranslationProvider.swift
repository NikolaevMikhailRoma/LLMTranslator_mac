import Foundation

/// Abstraction for translation engines.
/// Implementations can route to local models, remote HTTP APIs, etc.
public protocol TranslationProvider: AnyObject {
    /// Translates the provided text from `sourceLanguageCode` to `targetLanguageCode`.
    /// - Parameters:
    ///   - text: Input text to translate.
    ///   - sourceLanguageCode: BCP-47 language code of the source text (e.g., "en", "ru").
    ///   - targetLanguageCode: BCP-47 language code of the desired output.
    /// - Returns: The translated text, without extra commentary.
    func translate(text: String, from sourceLanguageCode: String, to targetLanguageCode: String) async throws -> String
}

