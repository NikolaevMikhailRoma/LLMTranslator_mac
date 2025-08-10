import Foundation

/// LM Studio-backed provider using OpenAI-compatible Chat Completions endpoint.
public final class LMStudioProvider: TranslationProvider {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
            cfg.urlCache = nil
            cfg.httpShouldSetCookies = false
            cfg.httpCookieAcceptPolicy = .never
            cfg.allowsExpensiveNetworkAccess = true
            cfg.allowsConstrainedNetworkAccess = true
            cfg.waitsForConnectivity = false
            self.session = URLSession(configuration: cfg)
        }
    }

    public func translate(text: String, from sourceLanguageCode: String, to targetLanguageCode: String) async throws -> String {
        let messages = buildMessages(for: text, from: sourceLanguageCode, to: targetLanguageCode)
        let payload  = try makeRequestPayload(messages: messages)
        let data     = try await post(payload)
        return try extractAnswer(from: data)
    }

    // MARK: - Networking helpers
    private func post(_ body: Data) async throws -> Data {
        guard let endpoint = SettingsStore.shared.config.chatCompletionsURL else {
            throw NSError(domain: "LMStudioProvider", code: 100,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid Chat Completions URL in settings"])
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "LMStudioProvider", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "LM Studio is not reachable at \(endpoint)"])
        }
        return data
    }

    private func extractAnswer(from data: Data) throws -> String {
        struct Message: Decodable { let role: String; let content: String }
        struct Choice: Decodable { let message: Message }
        struct ResponseBody: Decodable { let choices: [Choice] }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let raw = decoded.choices.first?.message.content else {
            throw NSError(domain: "LMStudioProvider", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Empty response from language model"])
        }
        return clean(raw)
    }

    // MARK: - Post-processing
    /// Removes any Qwen-style thinking blocks or stray tags, then trims whitespace.
    private func clean(_ text: String) -> String {
        var cleaned = text.replacingOccurrences(
            of: "(?s)<think>.*?</think>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        cleaned = cleaned.replacingOccurrences(
            of: "</?think>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Payload builder
    private func makeRequestPayload(messages: [[String: String]]) throws -> Data {
        var dict: [String: Any] = [
            "model":        SettingsStore.shared.config.modelName,
            "temperature":  0.0,
            "max_tokens":   1024,
            "messages":     messages,
            "stream":       false,
            "tool_choice":  "none",
            "enable_thinking": false
        ]
        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }

    // MARK: - Prompt construction
    private func buildMessages(for text: String, from srcLang: String, to dstLang: String) -> [[String: String]] {
        let systemPrompt = """
        You are a bilingual translation assistant. Always translate the user's message. 
            It can be a single character, word, phrase or large text.
        Rules:
        1. Preserve meaning, tone, punctuation, and formatting.
        2. Output ONLY the translated text without additional commentary.
        /no_think
        3. If user request is English text, translate and take it up in Russian.
        4. If user request is Russian text, translate and take it up in English.
        """

        let examples: [(String, String)] = [
            ("Не всегда все зависит от нас самих, бывает, мы оказываемся не в то время не в том месте", "Not everything depends on us, sometimes we find ourselves at the wrong place at the wrong time. Everything can change in a moment."),
            ("Hello, how are you?", "Привет, как дела?"),
            ("Can you translate this text quickly?", "Можешь быстро перевести этот текст?"),
            ("The Janus pro 7b output were drastically disaster for me.", "Выход Janus Pro 7b был радикально катастрофой для меня."),
            ("Привет! Рад тебя видеть на своём канале :)", "Hello! Nice to see you on my channel :)"),
            ("песня звучит в фильме Ведьмина гора", "The song is from the movie The Witch Mountain")
        ]

        var msgs: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for (u, a) in examples {
            msgs.append(["role": "user",      "content": u])
            msgs.append(["role": "assistant", "content": a])
        }
        msgs.append(["role": "user", "content": text])
        return msgs
    }
}

