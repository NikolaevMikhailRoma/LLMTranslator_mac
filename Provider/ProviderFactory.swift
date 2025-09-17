import Foundation

/// A factory for creating translation providers based on the app's configuration.
final class ProviderFactory {
    /// Creates and returns a `TranslationProvider` instance based on the specified configuration.
    /// - Parameter config: The application's configuration.
    /// - Returns: A concrete instance of a `TranslationProvider`.
    /// - Throws: An error if a provider cannot be created for the given mode.
    static func createProvider(for config: AppConfig) throws -> TranslationProvider {
        switch config.mode {
        case .offline:
            return LMStudioProvider()
        case .online:
            // In the future, you could implement and return an OnlineProvider here.
            // For example: return OnlineProvider(config: config.online)
            throw ProviderError.notImplemented("Online provider is not yet implemented.")
        }
    }
}

/// An error type for the ProviderFactory.
enum ProviderError: Error, LocalizedError {
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            return message
        }
    }
}
