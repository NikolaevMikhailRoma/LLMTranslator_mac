import Foundation

/// A provider that connects to any OpenAI-compatible Chat Completions endpoint.
public final class LLMProvider: TranslationProvider {
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
        let response = try extractAnswer(from: data)
        return response
    }

    // MARK: - Networking helpers
    private func post(_ body: Data) async throws -> Data {
        let config = SettingsStore.shared.config
        guard let endpoint = URL(string: config.baseURL) else {
            throw NSError(domain: "LLMProvider", code: 100,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid baseURL in settings: \(config.baseURL)"])
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = config.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "LLMProvider", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "The API endpoint is not reachable or returned an error. Status: \(statusCode)"])
        }
        return data
    }

    private func extractAnswer(from data: Data) throws -> String {
        struct Message: Decodable { let role: String; let content: String }
        struct Choice: Decodable { let message: Message }
        struct ResponseBody: Decodable { let choices: [Choice] }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let raw = decoded.choices.first?.message.content else {
            throw NSError(domain: "LLMProvider", code: 2,
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
        let config = SettingsStore.shared.config
        var dict = config.requestBody.toDictionary()
        
        if let modelId = config.modelIdentifier, !modelId.isEmpty {
            dict["model"] = modelId
        }
        
        dict["messages"] = messages
        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }

    // MARK: - Prompt construction
    private func buildMessages(for text: String, from srcLang: String, to dstLang: String) -> [[String: String]] {
        let systemPrompt = """
        You are a bilingual translation assistant. Always translate the user's message from \(srcLang) to \(dstLang).
            It can be a single character, word, phrase or large text.
        Rules:
        1. Preserve meaning, tone, punctuation, and formatting.
        2. Output ONLY the translated text without additional commentary.
        /no_think
        """

        var msgs: [[String: String]] = [["role": "system", "content": systemPrompt]]

        if let url = Bundle.main.url(forResource: "few_shot_examples", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            if let examples = try? decoder.decode([[String: String]].self, from: data) {
                for example in examples {
                    if let srcText = example[srcLang], let dstText = example[dstLang] {
                        msgs.append(["role": "user",      "content": srcText])
                        msgs.append(["role": "assistant", "content": dstText])
                    }
                }
            }
        }

        msgs.append(["role": "user", "content": text])
        return msgs
    }
}