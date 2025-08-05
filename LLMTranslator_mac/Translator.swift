import Foundation

/// Single-threaded actor wrapper around LM Studio.
/// Connects via 127.0.0.1 to avoid DNS inside the App Sandbox, composes a chat
/// request with system rules and three few‑shot examples, and returns ONLY the
/// translated text.
actor Translator {

    // MARK: Singleton
    static let shared = Translator()

    // MARK: - Internal DTOs
    private struct Message: Codable {
        let role: String
        let content: String
    }

    private struct RequestBody: Codable {
        let model: String
        let temperature: Double
        let max_tokens: Int
        let messages: [Message]
    }

    private struct Choice: Codable { let message: Message }
    private struct ResponseBody: Codable { let choices: [Choice] }

    // MARK: - Configuration
    /// Change the port if LM Studio listens on a different one.
    /// NOTE: Use 127.0.0.1 instead of “localhost” to bypass DNS, which is often
    /// blocked by the App Sandbox (error -1003 / -72000).
    private let endpoint = URL(string: "http://127.0.0.1:1234/v1/chat/completions")!
    private let modelName = "local"          // Any placeholder works for LM Studio
    private let session   = URLSession(configuration: .ephemeral)

    // MARK: - Public API
    /// Translates `text` from `srcLang` → `dstLang` using LM Studio.
    /// - Parameters:
    ///   - text:    Plain string to translate.
    ///   - srcLang: Source language (ISO‑639‑1), e.g. "en".
    ///   - dstLang: Target language (ISO‑639‑1), e.g. "ru".
    func translate(_ text: String, from srcLang: String, to dstLang: String) async throws -> String {

        // 1) Compose chat messages with few‑shot examples
        let messages = buildMessages(for: text, from: srcLang, to: dstLang)

        // 2) Encode request JSON
        let body = RequestBody(
            model: modelName,
            temperature: 0.0,
            max_tokens: 1024,
            messages: messages
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        // 3) Perform network call
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "Translator", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "LM Studio is not reachable at \(endpoint)"])
        }

        // 4) Decode response
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let answer = decoded.choices.first?.message.content else {
            throw NSError(domain: "Translator", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Empty response from language model"])
        }
        return answer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers
    /// Builds system prompt + 3 few‑shot examples + current user request.
    private func buildMessages(for text: String, from srcLang: String, to dstLang: String) -> [Message] {
        // System rules
        let systemPrompt = """
        You are a bilingual translation assistant. Always translate the user's message from \(srcLang.uppercased()) to \(dstLang.uppercased()) or \(dstLang.uppercased()) to \(srcLang.uppercased()).   It can be char, word(s) frases or big text. 
        Rules:
        1. Preserve meaning, tone, punctuation, and formatting.
        2. Output ONLY the translated text without additional commentary.
        
        Example: 
        1. word -> слово,
        2. Что ещё нужно проверить -> What else needs to be checked
        """

//        let systemPrompt = ""

        // Three few‑shot demonstration pairs (user → assistant)
        let examples: [(String, String)] = [
            ("Hello, how are you?", "Привет, как дела?"),
            ("Спасибо за помощь.", "Thank you for your help."),
            ("Can you translate this text quickly?", "Можешь быстро перевести этот текст?")
        ]

        var msgs = [Message(role: "system", content: systemPrompt)]
        for (u, a) in examples {
            msgs.append(Message(role: "user",      content: u))
            msgs.append(Message(role: "assistant", content: a))
        }
        // Highlighted text from clipboard becomes the new user request
        msgs.append(Message(role: "user", content: text))
        return msgs
    }
}

