import Foundation
import Combine

/// App configuration model and settings store.
/// Stores defaults in UserDefaults and exposes a shared observable store
/// which can be bound to future Settings UI.
public struct AppConfig: Codable, Equatable {
    /// List of language codes (e.g., ["ru", "en"]).
    /// The first element should be the user's native language.
    public var languageCodes: [String]

    /// Base server URL string, e.g., "http://127.0.0.1:1234".
    public var serverBaseURLString: String

    /// Model name (from LM Studio), e.g., "qwen/qwen3-1.7b".
    public var modelName: String

    /// Double-copy gap in seconds used to detect the keyboard gesture.
    public var doubleCopyGapSeconds: Double

    /// OpenAI-compatible Chat Completions path.
    public var chatCompletionsPath: String

    /// Builds full Chat Completions endpoint URL.
    public var chatCompletionsURL: URL? {
        let trimmedBase = serverBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBase.isEmpty else { return nil }
        let full = trimmedBase.hasSuffix("/") ? (trimmedBase + chatCompletionsPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
                                               : (trimmedBase + "/" + chatCompletionsPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        return URL(string: full)
    }
}

public extension AppConfig {
    /// Returns an AppConfig with sensible defaults based on the current system locale.
    static func makeDefault() -> AppConfig {
        let native = Self.primaryLanguageCode()
        let orderedLanguages = Self.defaultLanguages(nativeFirst: native)
        return AppConfig(
            languageCodes: orderedLanguages,
            serverBaseURLString: "http://127.0.0.1:1234",
            modelName: "qwen/qwen3-1.7b",
            doubleCopyGapSeconds: 0.30,
            chatCompletionsPath: "/v1/chat/completions"
        )
    }

    /// Attempts to infer user's primary language code (BCP-47 like "ru" or "en").
    /// Falls back to "en" if not available.
    static func primaryLanguageCode() -> String {
        // Prefer preferredLanguages (e.g., ["ru-RU", "en-US"]).
        if let tag = Locale.preferredLanguages.first, !tag.isEmpty {
            let code = tag.split(separator: "-").first.map(String.init) ?? tag
            return code.lowercased()
        }
        // Fallback to Locale.current
        if let code = Locale.current.languageCode, !code.isEmpty {
            return code.lowercased()
        }
        return "en"
    }

    /// Produces a de-duplicated, lowercased languages array with the native language first.
    static func defaultLanguages(nativeFirst native: String) -> [String] {
        let candidates = [native.lowercased(), "en", "ru"]
        var seen = Set<String>()
        var result: [String] = []
        for lang in candidates {
            if !lang.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !seen.contains(lang) {
                seen.insert(lang)
                result.append(lang)
            }
        }
        return result
    }
}

/// Observable settings store backed by UserDefaults.
/// Provides read/write APIs and publishes changes for SwiftUI bindings.
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    /// Published configuration used by the app.
    @Published public private(set) var config: AppConfig

    private let defaults: UserDefaults
    private let storageKey = "app.config.v1"

    /// Initializes the settings store and loads configuration from UserDefaults.
    public init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        if let stored: AppConfig = defaults.codable(forKey: storageKey) {
            self.config = stored
        } else {
            self.config = AppConfig.makeDefault()
            persist()
        }
    }

    /// Atomically updates the configuration and persists it to UserDefaults.
    /// - Parameter mutate: A closure that can mutate the current configuration in-place.
    public func updateConfig(_ mutate: (inout AppConfig) -> Void) {
        var copy = config
        mutate(&copy)
        config = copy
        persist()
    }

    /// Resets configuration to default values based on the current locale.
    public func resetToDefaults() {
        config = AppConfig.makeDefault()
        persist()
    }

    /// Persists the current configuration to UserDefaults.
    private func persist() {
        defaults.setCodable(config, forKey: storageKey)
    }
}

// MARK: - UserDefaults + Codable helpers

private extension UserDefaults {
    /// Reads a Codable value from UserDefaults using JSON encoding.
    func codable<T: Decodable>(forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    /// Writes a Codable value to UserDefaults using JSON encoding.
    func setCodable<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            set(data, forKey: key)
        } catch {
            // Swallow encoding errors; caller may handle via separate logging if needed.
        }
    }
}

