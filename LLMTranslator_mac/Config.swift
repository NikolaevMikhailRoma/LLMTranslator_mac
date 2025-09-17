import Foundation
import Combine

// MARK: - Models

public struct RequestBody: Codable, Equatable {
    public var temperature: Double
    public var max_tokens: Int
    public var stream: Bool
    public var tool_choice: String
    public var enable_thinking: Bool

    func toDictionary() -> [String: Any] {
        return [
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": stream,
            "tool_choice": tool_choice,
            "enable_thinking": enable_thinking
        ]
    }
}

/// Minimal app configuration loaded from a single JSON file.
public struct AppConfig: Codable, Equatable {
    /// The base URL of the OpenAI-compatible API.
    public var baseURL: String
    /// The API key for the service. Optional, as local servers may not require one.
    public var apiKey: String?
    /// The identifier of the model to use. Optional, will rely on server's default if not provided.
    public var modelIdentifier: String?

    /// Language codes with the first treated as the user's initial language.
    public var languageCodes: [String]
    /// Optional regex rules for counting characters per language to detect source language.
    public var languageDetectionRegexes: [String: String]? = nil
    /// Time window in seconds to detect a double copy gesture.
    public var doubleCopyGapSeconds: Double
    /// Request body parameters.
    public var requestBody: RequestBody
    /// Maximum line length for the translated text.
    public var maxLineLength: Int?

    enum CodingKeys: String, CodingKey {
        case baseURL, apiKey, modelIdentifier, languageCodes, languageDetectionRegexes, doubleCopyGapSeconds, requestBody
        case maxLineLength
    }
}

// MARK: - Settings store (read-only)

/// Loads `settings.json` from the app bundle on startup. No fallbacks, no UserDefaults.
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    /// Immutable configuration used by the app.
    @Published public private(set) var config: AppConfig

    private init() {
        guard let url = Bundle.main.url(forResource: "settings", withExtension: "json") else {
            fatalError("Missing settings.json in bundle. Add it to the target resources.")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            self.config = try decoder.decode(AppConfig.self, from: data)
        } catch {
            fatalError("Failed to load settings.json: \(error)")
        }
    }
}