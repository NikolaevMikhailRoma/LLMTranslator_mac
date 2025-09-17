import Foundation
import Combine

// MARK: - Models

/// Connection mode: local LM Studio (offline) or remote API (online).
public enum ConnectionMode: String, Codable, Equatable {
    case offline
    case online
}

/// Online configuration holding a full endpoint URL.
public struct OnlineConfig: Codable, Equatable {
    public var baseURLString: String
    enum CodingKeys: String, CodingKey { case baseURLString = "base_url" }
}

/// Offline (LM Studio) configuration.
public struct OfflineConfig: Codable, Equatable {
    public var port: Int
    public var path: String
    public var model: String
}

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
    /// Language codes with the first treated as the user's initial language.
    public var languageCodes: [String]
    /// Optional regex rules for counting characters per language to detect source language.
    /// Keys are language codes (e.g., "ru", "en"), values are regex patterns that match
    /// a single character belonging to that language alphabet. If missing, built-in
    /// defaults are used (Latin for "en", Cyrillic for "ru").
    public var languageDetectionRegexes: [String: String]? = nil
    /// Operational mode.
    public var mode: ConnectionMode
    /// Online endpoint settings.
    public var online: OnlineConfig
    /// Offline endpoint settings.
    public var offline: OfflineConfig
    /// Time window in seconds to detect a double copy gesture.
    public var doubleCopyGapSeconds: Double
    /// Request body parameters.
    public var requestBody: RequestBody
    /// Maximum line length for the translated text.
    public var maxLineLength: Int?

    /// Full Chat Completions URL depending on the selected mode.
    public var effectiveChatCompletionsURL: URL? {
        switch mode {
        case .offline:
            var comps = URLComponents()
            comps.scheme = "http"
            comps.host = "127.0.0.1"
            comps.port = offline.port
            comps.path = offline.path.hasPrefix("/") ? offline.path : "/" + offline.path
            return comps.url
        case .online:
            let trimmed = online.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            return URL(string: trimmed)
        }
    }

    /// Model name to request from the provider.
    public var effectiveModelName: String { offline.model }
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
            self.config = try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            fatalError("Failed to load settings.json: \(error)")
        }
    }
}

 