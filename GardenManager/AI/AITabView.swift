import SwiftUI
import UIKit

struct AIAssistantTabView: View {
    @State private var showChat = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.blue)

                Text("Send text and photos to OpenRouter")
                    .font(.headline)

                Button {
                    showChat = true
                } label: {
                    Label("Open AI Chat", systemImage: "message")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(.blue))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle("AI")
            .sheet(isPresented: $showChat) {
                NavigationStack {
                    AIChatView()
                }
            }
        }
    }
}

struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = OpenRouterAPIKeyCache.load()
    @State private var draftMessage = ""
    @State private var messages: [AIChatMessage] = []
    @State private var selectedPhoto: UIImage?
    @State private var isSending = false
    @State private var showCamera = false
    @State private var showCameraUnavailableAlert = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            keyField
            Divider()
            messagesList
            composer
        }
        .navigationTitle("OpenRouter Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker { image in
                if let image {
                    selectedPhoto = image
                }
            }
        }
        .alert("Camera unavailable", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        }
        .onChange(of: apiKey) { _, newValue in
            OpenRouterAPIKeyCache.save(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OpenRouter API Key")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            SecureField("sk-or-...", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
    }

    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if messages.isEmpty {
                    Text("No messages yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                }

                ForEach(messages) { message in
                    HStack {
                        if message.isAssistant { Spacer(minLength: 36) }

                        VStack(alignment: .leading, spacing: 8) {
                            if let photo = message.photo {
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            if !message.text.isEmpty {
                                Text(message.text)
                                    .font(.subheadline)
                                    .foregroundStyle(message.isUser ? .white : Color(.label))
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(message.isUser ? Color.blue : Color(.secondarySystemBackground))
                        )

                        if message.isUser { Spacer(minLength: 36) }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            if let selectedPhoto {
                HStack {
                    Image(uiImage: selectedPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text("Photo attached")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        self.selectedPhoto = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
            }

            HStack(spacing: 10) {
                Button {
                    openCamera()
                } label: {
                    Image(systemName: "camera")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)

                TextField("Message", text: $draftMessage)
                    .textFieldStyle(.roundedBorder)

                Button {
                    sendMessage()
                } label: {
                    if isSending {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSending || (draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedPhoto == nil))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .padding(.top, 10)
        .background(Color(.systemBackground))
    }

    func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailableAlert = true
            return
        }
        showCamera = true
    }

    func sendMessage() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            errorText = "Please enter your OpenRouter API key."
            return
        }

        guard !trimmedMessage.isEmpty || selectedPhoto != nil else {
            return
        }

        errorText = nil
        let previousMessages = messages
        let imageToSend = selectedPhoto
        let userMessage = AIChatMessage(role: .user, text: trimmedMessage, photo: imageToSend)
        messages.append(userMessage)

        draftMessage = ""
        selectedPhoto = nil
        isSending = true

        Task {
            do {
                let reply = try await OpenRouterClient.shared.sendMessage(
                    apiKey: trimmedKey,
                    history: previousMessages,
                    userText: trimmedMessage,
                    imageJPEGData: imageToSend?.jpegData(compressionQuality: 0.8)
                )

                await MainActor.run {
                    messages.append(AIChatMessage(role: .assistant, text: reply, photo: nil))
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isSending = false
                }
            }
        }
    }
}

struct AIChatMessage: Identifiable {
    enum Role {
        case user
        case assistant

        var openRouterRole: String {
            switch self {
            case .user: return "user"
            case .assistant: return "assistant"
            }
        }
    }

    let id = UUID()
    let role: Role
    let text: String
    let photo: UIImage?

    var isUser: Bool {
        switch role {
        case .user: return true
        case .assistant: return false
        }
    }

    var isAssistant: Bool {
        !isUser
    }
}

enum OpenRouterAPIKeyCache {
    static let key = "openrouter_api_key"

    static func save(_ apiKey: String) {
        UserDefaults.standard.set(apiKey, forKey: key)
    }

    static func load() -> String {
        UserDefaults.standard.string(forKey: key) ?? ""
    }
}

enum OpenRouterClientError: LocalizedError {
    case invalidResponse
    case invalidPayload
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "OpenRouter returned an invalid response."
        case .invalidPayload:
            return "Could not parse OpenRouter response payload."
        case .apiError(let message):
            return message
        }
    }
}

struct OpenRouterClient {
    static let shared = OpenRouterClient()

    func sendMessage(
        apiKey: String,
        history: [AIChatMessage],
        userText: String,
        imageJPEGData: Data?
    ) async throws -> String {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw OpenRouterClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://gardenmanager.local", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("GardenManager", forHTTPHeaderField: "X-Title")

        var messagesPayload: [[String: Any]] = []

        for message in history where !message.text.isEmpty {
            messagesPayload.append([
                "role": message.role.openRouterRole,
                "content": message.text
            ])
        }

        if let imageJPEGData {
            var content: [[String: Any]] = []

            if !userText.isEmpty {
                content.append([
                    "type": "text",
                    "text": userText
                ])
            }

            content.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(imageJPEGData.base64EncodedString())"
                ]
            ])

            messagesPayload.append([
                "role": "user",
                "content": content
            ])
        } else {
            messagesPayload.append([
                "role": "user",
                "content": userText
            ])
        }

        let requestBody: [String: Any] = [
            "model": "openai/gpt-4o-mini",
            "messages": messagesPayload
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenRouterClientError.apiError(parseErrorMessage(data) ?? "OpenRouter request failed with status code \(httpResponse.statusCode).")
        }

        guard let replyText = parseAssistantReply(data), !replyText.isEmpty else {
            throw OpenRouterClientError.invalidPayload
        }

        return replyText
    }

    func verifyToothbrushing(apiKey: String, imageJPEGData: Data) async throws -> (isVerified: Bool, modelReply: String) {
        let prompt = "is this a person brushing their teeth? Reply with only YES or NO."
        let reply = try await sendSingleImagePrompt(
            apiKey: apiKey,
            prompt: prompt,
            imageJPEGData: imageJPEGData
        )

        let normalized = reply
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let isYes = normalized == "yes"
            || normalized.hasPrefix("yes ")
            || normalized.hasPrefix("yes,")
            || normalized.hasPrefix("yes.")
            || normalized.hasPrefix("yes!")
            || normalized.hasPrefix("yes-")

        return (isYes, reply)
    }

    func sendSingleImagePrompt(apiKey: String, prompt: String, imageJPEGData: Data) async throws -> String {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw OpenRouterClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://gardenmanager.local", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("GardenManager", forHTTPHeaderField: "X-Title")

        let requestBody: [String: Any] = [
            "model": "openai/gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(imageJPEGData.base64EncodedString())"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenRouterClientError.apiError(parseErrorMessage(data) ?? "OpenRouter request failed with status code \(httpResponse.statusCode).")
        }

        guard let replyText = parseAssistantReply(data), !replyText.isEmpty else {
            throw OpenRouterClientError.invalidPayload
        }

        return replyText
    }

    func parseErrorMessage(_ data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }

    func parseAssistantReply(_ data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            return nil
        }

        if let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let contentParts = message["content"] as? [[String: Any]] {
            let textParts = contentParts.compactMap { $0["text"] as? String }
            let combined = textParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return combined.isEmpty ? nil : combined
        }

        return nil
    }
}

struct CameraImagePicker: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage?) -> Void
        let dismiss: DismissAction

        init(onImageCaptured: @escaping (UIImage?) -> Void, dismiss: DismissAction) {
            self.onImageCaptured = onImageCaptured
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImageCaptured(nil)
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onImageCaptured(image)
            dismiss()
        }
    }
}