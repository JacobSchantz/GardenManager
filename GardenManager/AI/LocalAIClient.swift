import Foundation

// MARK: - LocalAI REST API Client
// Handles vision-capable GGUF inference via a LocalAI server running locally.
// LocalAI server: https://github.com/mudler/LocalAI

actor LocalAIClient {
    // MARK: - Types

    struct Message: Codable {
        let role: String
        let content: [ContentPart]
    }

    struct ContentPart: Codable {
        let type: String
        var text: String?
        var imageURL: String?

        enum CodingKeys: String, CodingKey {
            case type, text
            case imageURL = "image_url"
        }
    }

    struct Request: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double?
        let stream: Bool
    }

    struct Response: Codable {
        let model: String
        let choices: [Choice]

        struct Choice: Codable {
            let message: ResponseMessage
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }

        struct ResponseMessage: Codable {
            let role: String
            let content: String
        }
    }

    // MARK: - Errors

    enum LocalAIError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case serverError(Int, String)
        case invalidResponse
        case streamNotSupported

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid LocalAI server URL."
            case .networkError(let err):
                return "Network error: \(err.localizedDescription)"
            case .serverError(let code, let msg):
                return "Server error (\(code)): \(msg)"
            case .invalidResponse:
                return "Invalid response from LocalAI server."
            case .streamNotSupported:
                return "Streaming is not supported by LocalAI client."
            }
        }
    }

    // MARK: - Properties

    private let session: URLSession
    private var baseURL: URL

    /// The model name to use, e.g. "vision-model" or "llava"
    var modelName: String

    /// Temperature for generation (nil = use server default)
    var temperature: Double?

    // MARK: - Init

    init(
        serverURL: URL = URL(string: "http://localhost:8080")!,
        modelName: String = "vision-model"
    ) {
        self.session = URLSession.shared
        self.baseURL = serverURL
        self.modelName = modelName
    }

    // MARK: - Configuration

    func update(serverURL: URL) {
        self.baseURL = serverURL
    }

    // MARK: - Non-streaming chat

    /// Send a chat message with optional image data.
    func sendMessage(
        text: String,
        imageData: Data?,
        history: [ChatMessage] = []
    ) async throws -> String {
        var content: [ContentPart] = []

        // Add history messages
        for msg in history {
            let parts: [ContentPart]
            if let imageData = msg.imageData {
                parts = [
                    ContentPart(type: "text", text: msg.text),
                    ContentPart(type: "image_url", imageURL: dataURI(for: imageData))
                ]
            } else {
                parts = [ContentPart(type: "text", text: msg.text)]
            }
            content.append(contentsOf: parts)
        }

        // Current user message
        if let imageData {
            content.append(ContentPart(type: "text", text: text))
            content.append(ContentPart(type: "image_url", imageURL: dataURI(for: imageData)))
        } else {
            content.append(ContentPart(type: "text", text: text))
        }

        let messages = buildMessages(history: history, currentText: text, currentImageData: imageData)

        let request = Request(
            model: modelName,
            messages: messages,
            temperature: temperature,
            stream: false
        )

        let url = baseURL.appendingPathComponent("v1/chat/completions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocalAIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LocalAIError.serverError(httpResponse.statusCode, message)
        }

        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(Response.self, from: data)

        guard let content = chatResponse.choices.first?.message.content else {
            throw LocalAIError.invalidResponse
        }

        return content
    }

    // MARK: - Helpers

    /// Build messages array from history + current message.
    private func buildMessages(
        history: [ChatMessage],
        currentText: String,
        currentImageData: Data?
    ) -> [Message] {
        var messages: [Message] = []

        // Add history as alternating user/assistant
        for msg in history {
            if let imageData = msg.imageData {
                messages.append(Message(
                    role: msg.role,
                    content: [
                        ContentPart(type: "text", text: msg.text),
                        ContentPart(type: "image_url", imageURL: dataURI(for: imageData))
                    ]
                ))
            } else {
                messages.append(Message(
                    role: msg.role,
                    content: [ContentPart(type: "text", text: msg.text)]
                ))
            }
        }

        // Current message
        if let imageData = currentImageData {
            messages.append(Message(
                role: "user",
                content: [
                    ContentPart(type: "text", text: currentText),
                    ContentPart(type: "image_url", imageURL: dataURI(for: imageData))
                ]
            ))
        } else {
            messages.append(Message(
                role: "user",
                content: [ContentPart(type: "text", text: currentText)]
            ))
        }

        return messages
    }

    /// Convert image data to a data URI string.
    private func dataURI(for data: Data) -> String {
        let base64 = data.base64EncodedString()
        return "data:image/jpeg;base64,\(base64)"
    }

    // MARK: - Server Health Check

    /// Check if LocalAI server is reachable and list available models.
    func ping() async -> Bool {
        let url = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - Chat Message (for history)

struct ChatMessage: Identifiable, Sendable {
    let id = UUID()
    let role: String
    let text: String
    var imageData: Data?

    init(role: String, text: String, imageData: Data? = nil) {
        self.role = role
        self.text = text
        self.imageData = imageData
    }
}
