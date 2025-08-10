import Foundation
import NaturalLanguage

/// High-level translation service used by the app UI.
/// It owns a provider chosen according to the current configuration
/// and exposes a minimal API: input text -> output text.
public actor TranslationService {
    public static let shared = TranslationService()

    private var provider: TranslationProvider

    private init() {
        // For now, always use LM Studio provider.
        // In the future, pick based on SettingsStore.shared.config.
        self.provider = LMStudioProvider()
    }

    /// Updates the underlying provider if configuration changes require it.
    /// This can be called from settings UI after the user changes the engine.
    public func reloadProviderIfNeeded() {
        // Placeholder for future multi-engine support.
        // Currently always LMStudioProvider; no-op.
    }

    /// Translates text using the selected provider.
    /// - Parameter text: Input text.
    /// - Returns: Translated text.
    public func translate(_ text: String) async throws -> String {
        let (src, dst) = determineLanguageDirection(for: text)
        return try await provider.translate(text: text, from: src, to: dst)
    }

    /// Determines source and target language codes using NLLanguageRecognizer and app configuration.
    private func determineLanguageDirection(for text: String) -> (String, String) {
        let cfg = SettingsStore.shared.config
        let languages = cfg.languageCodes
        guard let native = languages.first else {
            return ("en", "ru")
        }

        // Detect language
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let detected = recognizer.dominantLanguage?.rawValue.lowercased()

        // Choose target: if detected == native -> target is the first non-native in list (fallback to "en")
        // else target is native.
        let targetNonNative = languages.first(where: { $0.lowercased() != native.lowercased() }) ?? "en"

        if let detected = detected, detected == native.lowercased() {
            return (native.lowercased(), targetNonNative.lowercased())
        } else {
            // If detection failed or is not native, translate to native.
            let src = detected ?? targetNonNative
            return (src.lowercased(), native.lowercased())
        }
    }
}

