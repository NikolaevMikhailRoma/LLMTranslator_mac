import Foundation

/// Одно-поточная singletone-обёртка вокруг LM Studio.
/// Здесь легко заменить реализацию на WebSocket/HTTP.
actor Translator {

    static let shared = Translator()

    /// Асинхронный перевод; пока stub.
    func translate(_ text: String, from: String, to: String) async throws -> String {
        // TODO: проверьте, что LM Studio слушает localhost:1234
        // и замените URLSession-запросом / сокетом.
        try await Task.sleep(nanoseconds: 150_000_000) // ~0.15 с «работы»
        return "[\(to.uppercased())] " + text
    }
}

