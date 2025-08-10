import Foundation

// Access shared settings for endpoint and model configuration.

/// Single-threaded actor wrapper around LM Studio.
/// Builds an OpenAI-compatible chat request, disables tool-calling ("tool_choice: \"none\"") and,
/// for Qwen-family models, explicitly turns off <think></think> output via `enable_thinking: false`.
/// Any residual <think> … </think> blocks (or stray closing tags) are stripped from the final
/// response before returning it to the UI.
actor Translator {

    // MARK: Singleton
    static let shared = Translator()

    // MARK: - Internal DTOs
    private struct Message: Codable {
        let role: String
        let content: String
        var dict: [String: String] { ["role": role, "content": content] }
    }

    // MARK: - Configuration
    /// URLSession configuration and runtime settings are derived from SettingsStore.
    private let session: URLSession = {
        // Use a tuned default configuration (no cache/cookies) instead of ephemeral.
        // This avoids certain lower-level socket options being applied by the system
        // that may trigger SO_NOWAKEFROMSLEEP warnings on some setups.
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.urlCache = nil
        cfg.httpShouldSetCookies = false
        cfg.httpCookieAcceptPolicy = .never
        cfg.allowsExpensiveNetworkAccess = true
        cfg.allowsConstrainedNetworkAccess = true
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()
    private let maxTokens  = 1024
    private let temperature: Double = 0.0

    // Behaviour toggles — tweak as needed in future UI settings.
    private let disableTools      = true   // “tool_choice: \"none\"” prevents tool calls.
    private let disableThinking   = true   // Adds “enable_thinking: false” for Qwen-family.

    // MARK: - Public API
    /// Translates `text` from `srcLang` ⇄ `dstLang` using LM Studio.
    func translate(_ text: String, from srcLang: String, to dstLang: String) async throws -> String {
        let messages = buildMessages(for: text, from: srcLang, to: dstLang)
        let payload  = try makeRequestPayload(messages: messages)
        let data     = try await post(payload)
        return try extractAnswer(from: data)
    }

    // MARK: - Networking helpers
    private func post(_ body: Data) async throws -> Data {
        guard let endpoint = SettingsStore.shared.config.chatCompletionsURL else {
            throw NSError(domain: "Translator", code: 100,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid Chat Completions URL in settings"])
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "Translator", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "LM Studio is not reachable at \(endpoint)"])
        }
        return data
    }

    private func extractAnswer(from data: Data) throws -> String {
        struct Choice: Decodable { let message: Message }
        struct ResponseBody: Decodable { let choices: [Choice] }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let raw = decoded.choices.first?.message.content else {
            throw NSError(domain: "Translator", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Empty response from language model"])
        }
        return clean(raw)
    }

    // MARK: - Post-processing
    /// Removes any Qwen-style thinking blocks or stray tags, then trims whitespace.
    private func clean(_ text: String) -> String {
        // 1) Remove complete <think> … </think> blocks (non-greedy, DOTALL).
        var cleaned = text.replacingOccurrences(
            of: "(?s)<think>.*?</think>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        // 2) Remove any remaining opening/closing tags (e.g. stray </think>).
        cleaned = cleaned.replacingOccurrences(
            of: "</?think>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Payload builder
    private func makeRequestPayload(messages: [Message]) throws -> Data {
        var dict: [String: Any] = [
            "model":        SettingsStore.shared.config.modelName,
            "temperature":  temperature,
            "max_tokens":   maxTokens,
            "messages":     messages.map { $0.dict },
            "stream":       false
        ]
        if disableTools {
            dict["tool_choice"] = "none"  // Prevent tool-calling.
        }
        if disableThinking {
            // Qwen-specific flag; ignored by other models, so safe to always include.
            dict["enable_thinking"] = false
        }
        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }

    // MARK: - Prompt construction
    private func buildMessages(for text: String, from srcLang: String, to dstLang: String) -> [Message] {
        // System rules (bi-directional).
        let systemPrompt = """
        You are a bilingual translation assistant. Always translate the user's message. 
            It can be a single character, word, phrase or large text.
        Rules:
        1. Preserve meaning, tone, punctuation, and formatting.
        2. Output ONLY the translated text without additional commentary.
        /no_think
        
        3. If user request is English text, translate and take it up in Russian.
        4. If user request is Russian text, translate and take it up in English.

        Example:
        1. word -> слово
        2. Что ещё нужно проверить -> What else needs to be checked
        """

        // Few-shot demonstration pairs (user → assistant)
        let examples: [(String, String)] = [
            ("Не всегда все зависит от нас самих, бывает, мы оказываемся не в то время не в том месте", "Not everything depends on us, sometimes we find ourselves at the wrong place at the wrong time. Everything can change in a moment."),
            ("Hello, how are you?", "Привет, как дела?"),
            ("Can you translate this text quickly?", "Можешь быстро перевести этот текст?"),
            ("The Janus pro 7b output were drastically disaster for me.", "Выход Janus Pro 7b был радикально катастрофой для меня."),
            ("Привет! Рад тебя видеть на своём канале :)", "Hello! Nice to see you on my channel :)"),
            ("песня звучит в фильме Ведьмина гора", "The song is from the movie The Witch Mountain"),
        ]

        var msgs = [Message(role: "system", content: systemPrompt)]
        for (u, a) in examples {
            msgs.append(Message(role: "user",      content: u))
            msgs.append(Message(role: "assistant", content: a))
        }
        msgs.append(Message(role: "user", content: text))
        return msgs
    }
}

