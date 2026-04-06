import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
// MARK: - Photo Picker

struct PhotoPickerView: UIViewControllerRepresentable {
    @Binding var selectedImageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedImageData: $selectedImageData, dismiss: dismiss)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let selectedImageData: Binding<Data?>
        let dismiss: DismissAction

        init(selectedImageData: Binding<Data?>, dismiss: DismissAction) {
            self.selectedImageData = selectedImageData
            self.dismiss = dismiss
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                dismiss()
                return
            }

            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else {
                    DispatchQueue.main.async { self?.dismiss() }
                    return
                }
                let data = image.jpegData(compressionQuality: 0.8)
                DispatchQueue.main.async {
                    self?.selectedImageData.wrappedValue = data
                    self?.dismiss()
                }
            }
        }
    }
}
import SwiftLlama

// MARK: - Unified Chat View

/// Unified chat interface supporting both GGUF (local) and Cloud (OpenRouter) AI backends.
struct UnifiedChatView: View {
    @StateObject private var viewModel = UnifiedChatViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with model selector
                header
                Divider()

                // Message list
                messagesList

                // Composer
                composer
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.clearConversation()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.isGenerating)
                }
            }
            .sheet(isPresented: $viewModel.showFilePicker) {
                DocumentPickerView(selectedURL: $viewModel.selectedGGUFURL)
            }
            .sheet(isPresented: $viewModel.showImagePicker) {
                PhotoPickerView(selectedImageData: $viewModel.selectedImageData)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorText)
            }
            .task {
                await viewModel.loadSavedModel()
            }
            .onChange(of: viewModel.selectedGGUFURL) { _, newURL in
                if let url = newURL {
                    Task { await viewModel.useSelectedModel(at: url) }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Model type selector
            HStack {
                Picker("Model", selection: $viewModel.selectedMode) {
                    Text("GGUF").tag(ChatMode.gguf)
                    Text("LocalAI").tag(ChatMode.localAI)
                    Text("Cloud").tag(ChatMode.cloud)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Spacer()

                // Cloud API key button (shown in cloud mode)
                if viewModel.selectedMode == .cloud {
                    Button {
                        viewModel.showCloudSettings.toggle()
                    } label: {
                        Image(systemName: viewModel.hasAPIKey ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(viewModel.hasAPIKey ? .green : .orange)
                    }
                    .sheet(isPresented: $viewModel.showCloudSettings) {
                        CloudSettingsSheet(
                            apiKey: $viewModel.cloudAPIKey,
                            selectedModelID: $viewModel.cloudModelID
                        )
                    }
                }

                if viewModel.selectedMode == .localAI {
                    Button {
                        viewModel.showLocalAISettings.toggle()
                    } label: {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.secondary)
                    }
                    .sheet(isPresented: $viewModel.showLocalAISettings) {
                        LocalAISettingsSheet(
                            serverURL: $viewModel.localAIServerURL,
                            modelName: $viewModel.localAIModelName
                        )
                    }
                }
            }

            // Model info row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.modelTypeIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if viewModel.selectedMode == .gguf {
                            Text(viewModel.modelName.isEmpty ? "No model selected" : viewModel.modelName)
                                .font(.headline)
                                .lineLimit(1)
                        } else if viewModel.selectedMode == .localAI {
                            Text(viewModel.localAIModelName.isEmpty ? "No model set" : viewModel.localAIModelName)
                                .font(.headline)
                                .lineLimit(1)
                        } else {
                            Text(viewModel.cloudModelLabel)
                                .font(.headline)
                                .lineLimit(1)
                        }
                    }

                    Text(viewModel.modelStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.selectedMode == .gguf {
                    Button {
                        viewModel.showFilePicker = true
                    } label: {
                        Label(viewModel.modelName.isEmpty ? "Pick GGUF" : "Change", systemImage: "folder")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: viewModel.modelTypeIcon)
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)

                            Text(viewModel.emptyStateMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }

                    ForEach(viewModel.messages) { message in
                        HStack(alignment: .bottom) {
                            if message.role == .assistant {
                                Spacer(minLength: 34)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(message.text)
                                    .font(.subheadline)
                                    .foregroundStyle(message.role == .user ? .white : Color(.label))
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(message.role == .user ? Color.blue : Color(.secondarySystemBackground))
                            )

                            if message.role == .user {
                                Spacer(minLength: 34)
                            }
                        }
                        .id(message.id)
                    }

                    if viewModel.isGenerating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Generating…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    if let errorMessage = viewModel.lastError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let lastId = viewModel.messages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            // Image preview when attached
            if let imageData = viewModel.selectedImageData,
               let uiImage = UIImage(data: imageData) {
                HStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Image attached")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        viewModel.selectedImageData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Divider()
            }

            HStack(spacing: 10) {
                TextField("Message", text: $viewModel.draftMessage)
                    .textFieldStyle(.roundedBorder)

                // Image attachment button
                Button {
                    viewModel.showImagePicker = true
                } label: {
                    Image(systemName: viewModel.selectedImageData != nil
                          ? "photo.fill"
                          : "photo")
                        .font(.title3)
                        .foregroundStyle(viewModel.selectedImageData != nil ? .blue : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.sendCurrentMessage()
                } label: {
                    if viewModel.isGenerating {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.composerDisabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Cloud Settings Sheet

private struct CloudSettingsSheet: View {
    @Binding var apiKey: String
    @Binding var selectedModelID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenRouter API Key") {
                    SecureField("sk-or-...", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Model") {
                    Picker("Model", selection: $selectedModelID) {
                        ForEach(OpenRouterVisionModel.options) { model in
                            Text(model.label).tag(model.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Text("Your API key is stored securely on-device and never sent anywhere except OpenRouter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Cloud Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                }
            }
            .onChange(of: apiKey) { _, newValue in
                OpenRouterAPIKeyCache.save(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    private func saveAndDismiss() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        OpenRouterAPIKeyCache.save(trimmedKey)
        dismiss()
    }
}

// MARK: - LocalAI Settings Sheet

private struct LocalAISettingsSheet: View {
    @Binding var serverURL: String
    @Binding var modelName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("LocalAI Server") {
                    TextField("Server URL", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Section("Vision Model") {
                    TextField("Model name", text: $modelName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("Use a vision-capable model such as llava, moondream, or bakllava running on your LocalAI server.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("LocalAI must be running on your Mac with a vision model. See: github.com/mudler/LocalAI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("LocalAI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                }
            }
        }
    }

    private func saveAndDismiss() {
        let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        LocalAISettingsCache.save(serverURL: trimmedURL, modelName: trimmedModel)
        dismiss()
    }
}

// MARK: - ViewModel

enum ChatMode: String {
    case gguf
    case localAI
    case cloud
}

@MainActor
private final class UnifiedChatViewModel: ObservableObject {
    // MARK: - Published State
    @Published var draftMessage = ""
    @Published var messages: [UnifiedChatMessage] = []
    @Published var isGenerating = false
    @Published var showError = false
    @Published var errorText = ""
    @Published var showFilePicker = false
    @Published var selectedGGUFURL: URL?
    @Published var lastError: String?
    @Published var selectedMode: ChatMode = .cloud

    // Cloud mode
    @Published var cloudAPIKey: String = OpenRouterAPIKeyCache.load()
    @Published var cloudModelID: String = OpenRouterVisionModel.defaults.id
    @Published var showCloudSettings = false

    // Image attachment
    @Published var selectedImageData: Data?
    @Published var showImagePicker = false

    // LocalAI mode
    @Published var localAIServerURL: String = LocalAISettingsCache.loadServerURL()
    @Published var localAIModelName: String = LocalAISettingsCache.loadModelName()
    @Published var showLocalAISettings = false

    private var localAIClient: LocalAIClient?

    // MARK: - Private State
    private var llamaService: LlamaService?
    private var conversationHistory: [UnifiedChatMessage] = []

    // MARK: - Computed

    var modelName: String {
        selectedGGUFURL?.deletingPathExtension().lastPathComponent ?? ""
    }

    var cloudModelLabel: String {
        OpenRouterVisionModel.options.first { $0.id == cloudModelID }?.label ?? cloudModelID
    }

    var hasAPIKey: Bool {
        !cloudAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var localAIConfigured: Bool {
        !localAIServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !localAIModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var modelTypeIcon: String {
        switch selectedMode {
        case .gguf: return "cpu"
        case .localAI: return "server.rack"
        case .cloud: return "cloud"
        }
    }

    var modelStatusText: String {
        switch selectedMode {
        case .gguf:
            return modelName.isEmpty ? "Pick a GGUF file to start" : "On-device via llama.cpp"
        case .localAI:
            return localAIConfigured ? "Via LocalAI server" : "Configure LocalAI server in settings"
        case .cloud:
            return "Via OpenRouter API"
        }
    }

    var emptyStateMessage: String {
        switch selectedMode {
        case .gguf:
            return "Pick a GGUF model file, then send a message."
        case .localAI:
            return "Configure your LocalAI server, then send a message."
        case .cloud:
            return "Enter your OpenRouter API key and send a message."
        }
    }

    var composerDisabled: Bool {
        if isGenerating { return true }
        if selectedMode == .cloud && !hasAPIKey { return true }
        if selectedMode == .localAI && !localAIConfigured { return true }
        return false
    }

    // MARK: - GGUF URL Persistence

    func loadSavedModel() async {
        guard let savedPath = UserDefaults.standard.string(forKey: "localAI_GGUFPath") else { return }
        let url = URL(fileURLWithPath: savedPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            UserDefaults.standard.removeObject(forKey: "localAI_GGUFPath")
            return
        }
        selectedGGUFURL = url
        await initializeLlama(with: url)
    }

    func saveGGUFURLBookmark(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: "localAI_GGUFPath")
    }

    // MARK: - Llama Initialization

    func useSelectedModel(at url: URL) async {
        selectedGGUFURL = url
        saveGGUFURLBookmark(url)
        await initializeLlama(with: url)
        messages.removeAll()
        conversationHistory.removeAll()
    }

    private func initializeLlama(with url: URL) async {
        llamaService = nil
        let service = LlamaService(
            modelUrl: url,
            config: LlamaConfig(batchSize: 512, maxTokenCount: 2048, useGPU: true)
        )
        llamaService = service
    }

    // MARK: - Send Message

    func sendCurrentMessage() {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isGenerating, !trimmed.isEmpty else { return }

        lastError = nil

        let userMessage = UnifiedChatMessage(role: .user, text: trimmed)
        messages.append(userMessage)
        conversationHistory.append(userMessage)
        draftMessage = ""

        // Capture and clear image before async operations
        let imageData = selectedImageData
        selectedImageData = nil

        isGenerating = true

        if selectedMode == .gguf {
            sendGGUFMessage(trimmed, imageData: imageData)
        } else if selectedMode == .localAI {
            sendLocalAIMessage(trimmed, imageData: imageData)
        } else {
            sendCloudMessage(trimmed, imageData: imageData)
        }
    }

    private func sendGGUFMessage(_ prompt: String, imageData: Data?) {
        // If image provided but GGUF doesn't support it, show inline error
        if imageData != nil {
            if selectedGGUFURL == nil {
                lastError = "Please select a GGUF model first to send images."
                isGenerating = false
                return
            }
            // TODO: Extend LlamaService to support multimodal GGUF models (LLaVA, etc.)
            // For now, include image as base64 in the prompt
        }

        guard let url = selectedGGUFURL else {
            lastError = "Please select a GGUF model file first."
            isGenerating = false
            return
        }

        Task {
            if llamaService == nil {
                await initializeLlama(with: url)
            }

            guard let service = llamaService else {
                await MainActor.run {
                    lastError = "Failed to initialize model. Please try again."
                    isGenerating = false
                }
                return
            }

            do {
                let reply = try await generateGGUFReply(for: prompt, service: service, imageData: imageData)
                await MainActor.run {
                    let assistantMessage = UnifiedChatMessage(role: .assistant, text: reply)
                    messages.append(assistantMessage)
                    conversationHistory.append(assistantMessage)
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    lastError = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func sendCloudMessage(_ prompt: String, imageData: Data?) {
        let apiKey = cloudAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let reply = try await generateCloudReply(
                    for: prompt,
                    apiKey: apiKey,
                    model: cloudModelID,
                    history: conversationHistory.dropLast().map { ChatHistoryMessage(role: $0.role == .user ? "user" : "assistant", text: $0.text) },
                    imageData: imageData
                )
                await MainActor.run {
                    let assistantMessage = UnifiedChatMessage(role: .assistant, text: reply)
                    messages.append(assistantMessage)
                    conversationHistory.append(assistantMessage)
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    lastError = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func generateGGUFReply(for prompt: String, service: LlamaService, imageData: Data?) async throws -> String {
        let historyText = conversationHistory
            .dropLast()
            .suffix(10)
            .map { turn -> String in
                let role = turn.role == .user ? "User" : "Assistant"
                return "\(role): \(turn.text)"
            }
            .joined(separator: "\n")

        var fullPrompt: String
        if let imageData = imageData {
            let base64Image = imageData.base64EncodedString()
            let imagePart = "[Image: data:image/jpeg;base64,\(base64Image)]"
            if historyText.isEmpty {
                fullPrompt = "User: \(imagePart)\nCaption: \(prompt)\nAssistant:"
            } else {
                fullPrompt = "\(historyText)\nUser: \(imagePart)\nCaption: \(prompt)\nAssistant:"
            }
        } else {
            if historyText.isEmpty {
                fullPrompt = "User: \(prompt)\nAssistant:"
            } else {
                fullPrompt = "\(historyText)\nUser: \(prompt)\nAssistant:"
            }
        }

        guard !conversationHistory.isEmpty else {
            throw UnifiedChatServiceError.modelNotLoaded
        }

        let chatMessage = LlamaChatMessage(role: .user, content: fullPrompt)
        let samplingConfig = LlamaSamplingConfig(temperature: 0.7, seed: 42, grammarConfig: nil)

        var result = ""
        let stream = try await service.streamCompletion(of: [chatMessage], samplingConfig: samplingConfig)

        for try await token in stream {
            result += token
        }

        return result.isEmpty ? "No response from model." : result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generateCloudReply(
        for prompt: String,
        apiKey: String,
        model: String,
        history: [ChatHistoryMessage],
        imageData: Data?
    ) async throws -> String {
        return try await OpenRouterClient.shared.sendMessage(
            apiKey: apiKey,
            model: model,
            history: history,
            userText: prompt,
            imageJPEGData: imageData
        )
    }

    func clearConversation() {
        messages.removeAll()
        conversationHistory.removeAll()
        lastError = nil
        llamaService = nil
        if let url = selectedGGUFURL {
            Task { await initializeLlama(with: url) }
        }
    }

    private func sendLocalAIMessage(_ prompt: String, imageData: Data?) {
        guard localAIConfigured else {
            lastError = "Configure LocalAI server URL and model name in settings."
            isGenerating = false
            return
        }

        Task {
            do {
                let reply = try await generateLocalAIReply(for: prompt, imageData: imageData)
                await MainActor.run {
                    let assistantMessage = UnifiedChatMessage(role: .assistant, text: reply)
                    messages.append(assistantMessage)
                    conversationHistory.append(assistantMessage)
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    lastError = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func generateLocalAIReply(for prompt: String, imageData: Data?) async throws -> String {
        let serverURL = URL(string: localAIServerURL.trimmingCharacters(in: .whitespacesAndNewlines)) ?? URL(string: "http://localhost:8080")!
        let modelName = localAIModelName.trimmingCharacters(in: .whitespacesAndNewlines)

        let client = LocalAIClient(serverURL: serverURL, modelName: modelName)

        let historyMessages: [ChatMessage] = conversationHistory.dropLast().map { msg in
            ChatMessage(role: msg.role == .user ? "user" : "assistant", text: msg.text)
        }

        return try await client.sendMessage(text: prompt, imageData: imageData, history: historyMessages)
    }

    private func reportError(_ message: String) {
        errorText = message
        showError = true
    }
}

// MARK: - Models

private struct UnifiedChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

fileprivate struct ChatHistoryMessage {
    let role: String
    let text: String
}

private enum UnifiedChatServiceError: LocalizedError {
    case modelNotLoaded
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No GGUF model loaded. Please pick a model file."
        case .emptyResponse:
            return "The model returned an empty response."
        }
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedURL: $selectedURL, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let selectedURL: Binding<URL?>
        let dismiss: DismissAction

        init(selectedURL: Binding<URL?>, dismiss: DismissAction) {
            self.selectedURL = selectedURL
            self.dismiss = dismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                selectedURL.wrappedValue = url
            }
            dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            dismiss()
        }
    }
}

// MARK: - OpenRouter Client (unchanged from original)

enum OpenRouterAPIKeyCache {
    static let key = "openrouter_api_key"

    static func save(_ apiKey: String) {
        UserDefaults.standard.set(apiKey, forKey: key)
    }

    static func load() -> String {
        UserDefaults.standard.string(forKey: key) ?? ""
    }
}

// MARK: - LocalAI Settings Cache

enum LocalAISettingsCache {
    static let serverURLKey = "localAI_serverURL"
    static let modelNameKey = "localAI_modelName"

    static func save(serverURL: String, modelName: String) {
        UserDefaults.standard.set(serverURL, forKey: serverURLKey)
        UserDefaults.standard.set(modelName, forKey: modelNameKey)
    }

    static func loadServerURL() -> String {
        UserDefaults.standard.string(forKey: serverURLKey) ?? "http://localhost:8080"
    }

    static func loadModelName() -> String {
        UserDefaults.standard.string(forKey: modelNameKey) ?? "vision-model"
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

private struct OpenRouterVisionModel: Identifiable {
    let id: String

    var label: String {
        switch id {
        case "openai/chatgpt-4o-latest": return "GPT-4o (Latest)"
        case "anthropic/claude-3.5-sonnet": return "Claude 3.5 Sonnet"
        case "google/gemini-2.0-flash": return "Gemini 2.0 Flash"
        case "meta-llama/llama-3-8b-instruct": return "Llama 3 8B"
        case "mistralai/mistral-7b-instruct": return "Mistral 7B"
        default: return id
        }
    }

    static let defaults = OpenRouterVisionModel(id: "openai/chatgpt-4o-latest")

    static let options: [OpenRouterVisionModel] = [
        .init(id: "openai/chatgpt-4o-latest"),
        .init(id: "anthropic/claude-3.5-sonnet"),
        .init(id: "google/gemini-2.0-flash"),
        .init(id: "meta-llama/llama-3-8b-instruct"),
        .init(id: "mistralai/mistral-7b-instruct")
    ]
}

struct OpenRouterClient {
    static let shared = OpenRouterClient()

    private let session = URLSession.shared

    fileprivate func sendMessage(
        apiKey: String,
        model: String,
        history: [ChatHistoryMessage],
        userText: String,
        imageJPEGData: Data?
    ) async throws -> String {
        var messages: [[String: Any]] = []

        for message in history {
            messages.append([
                "role": message.role,
                "content": message.text
            ])
        }

        var userContent: [Any] = []
        if let imageJPEGData {
            let base64Image = imageJPEGData.base64EncodedString()
            userContent = [
                ["type": "text", "text": userText],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
            ]
        } else {
            userContent = [["type": "text", "text": userText]]
        }
        messages.append(["role": "user", "content": userContent])

        let body: [String: Any] = [
            "model": model,
            "messages": messages
        ]

        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw OpenRouterClientError.invalidPayload
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterClientError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OpenRouterClientError.apiError(message)
            }
            throw OpenRouterClientError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenRouterClientError.invalidPayload
        }

        return content
    }
}

struct CameraImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage?) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage?) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onImagePicked(image)
            dismiss()
        }
    }
}
