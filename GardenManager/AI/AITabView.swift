import SwiftUI
import UIKit
import Vision
import CoreML
#if canImport(FoundationModels)
import FoundationModels
#endif

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

struct PersonActionTabView: View {
    @State private var apiKey = OpenRouterAPIKeyCache.load()
    @State private var selectedModelID = OpenRouterVisionModel.defaults.id
    @State private var selectedImage: UIImage?
    @State private var resultText = ""
    @State private var isAnalyzing = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Model", selection: $selectedModelID) {
                        ForEach(OpenRouterVisionModel.options) { model in
                            Text(model.label).tag(model.id)
                        }
                    }

                    SecureField("OpenRouter API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 220)
                            .overlay {
                                Text("Choose an image")
                                    .foregroundStyle(.secondary)
                            }
                    }

                    HStack(spacing: 12) {
                        Button("Photos") {
                            showPhotoLibrary = true
                        }
                        .buttonStyle(.bordered)

                        Button("Camera") {
                            showCamera = true
                        }
                        .buttonStyle(.bordered)

                        Button("Analyze") {
                            analyzeImage()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAnalyzing || selectedImage == nil || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if isAnalyzing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Analyzing image...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if !resultText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Result")
                                .font(.headline)
                            Text(resultText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Person Action")
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { image in
                    if let image {
                        selectedImage = image
                    }
                }
            }
            .sheet(isPresented: $showPhotoLibrary) {
                LocalUIImagePicker(sourceType: .photoLibrary) { image in
                    if let image {
                        selectedImage = image
                    }
                }
            }
            .onChange(of: apiKey) { _, newValue in
                OpenRouterAPIKeyCache.save(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    private func analyzeImage() {
        guard !isAnalyzing else { return }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            errorText = "Please enter your OpenRouter API key."
            return
        }

        guard let jpegData = selectedImage?.jpegData(compressionQuality: 0.82) else {
            errorText = "Please choose an image first."
            return
        }

        errorText = nil
        resultText = ""
        isAnalyzing = true

        Task {
            do {
                let reply = try await OpenRouterClient.shared.sendSingleImagePrompt(
                    apiKey: trimmedKey,
                    model: selectedModelID,
                    prompt: "Describe what the person in this image is doing. Be concise and specific.",
                    imageJPEGData: jpegData
                )

                await MainActor.run {
                    resultText = reply
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }
}

struct LocalAITabView: View {
    @StateObject private var viewModel = LocalAIChatViewModel()
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                messagesList
                composer
            }
            .navigationTitle("Local AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }

                    Button {
                        viewModel.clearConversation()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.isGenerating)
                }
            }
            .sheet(isPresented: $showCamera) {
                LocalUIImagePicker(sourceType: .camera) { image in
                    if let image {
                        viewModel.selectedPhoto = image
                    }
                }
            }
            .sheet(isPresented: $showPhotoLibrary) {
                LocalUIImagePicker(sourceType: .photoLibrary) { image in
                    if let image {
                        viewModel.selectedPhoto = image
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    LocalAISettingsView(
                        configuration: viewModel.configuration,
                        modelStatus: viewModel.modelStatus,
                        downloadableModels: DownloadableVisionModel.catalog,
                        downloadedModels: viewModel.downloadedModels,
                        downloadingModelIDs: viewModel.downloadingModelIDs,
                        isSaving: viewModel.isUpdatingConfiguration,
                        onDownloadModel: { model in
                            viewModel.downloadModel(model)
                        },
                        onSave: { updated in
                            viewModel.apply(configuration: updated)
                        }
                    )
                }
            }
            .task {
                await viewModel.refreshModelStatus()
                await viewModel.refreshDownloadedModels()
            }
            .alert("Local AI Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorText)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("On-device chat + vision", systemImage: "cpu")
                .font(.headline)

            Text("All inference happens locally. Attach a photo and ask questions offline.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.modelStatus.isReady ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(viewModel.modelStatus.title)
                    .font(.caption.weight(.semibold))
                Text("•")
                    .foregroundStyle(.secondary)
                Text(viewModel.modelStatus.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.messages.isEmpty {
                        Text("Start a local conversation. Add an image for vision prompts.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    }

                    ForEach(viewModel.messages) { message in
                        HStack(alignment: .bottom) {
                            if message.role == .assistant {
                                Spacer(minLength: 34)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                if let image = message.photo {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 150, height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }

                                if !message.text.isEmpty {
                                    Text(message.text)
                                        .font(.subheadline)
                                        .foregroundStyle(message.role == .user ? .white : Color(.label))
                                }
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
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let lastId = viewModel.messages.last?.id else { return }
                withAnimation {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            if let selectedPhoto = viewModel.selectedPhoto {
                HStack {
                    Image(uiImage: selectedPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text("Image attached")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        viewModel.selectedPhoto = nil
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
                    showPhotoLibrary = true
                } label: {
                    Image(systemName: "photo")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                        viewModel.reportError("Camera unavailable on this device.")
                        return
                    }
                    showCamera = true
                } label: {
                    Image(systemName: "camera")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)

                TextField("Message", text: $viewModel.draftMessage)
                    .textFieldStyle(.roundedBorder)

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
                .disabled(viewModel.isGenerating || viewModel.sendDisabled)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .padding(.top, 10)
        .background(Color(.systemBackground))
    }
}

@MainActor
private final class LocalAIChatViewModel: ObservableObject {
    @Published var draftMessage = ""
    @Published var selectedPhoto: UIImage?
    @Published var messages: [LocalAIMessage] = []
    @Published var isGenerating = false
    @Published var showError = false
    @Published var errorText = ""
    @Published var modelStatus: LocalAIModelStatus = .checking
    @Published var configuration: LocalAIConfiguration = .load()
    @Published var isUpdatingConfiguration = false
    @Published var downloadedModels: [LocalDownloadedModel] = []
    @Published var downloadingModelIDs: Set<String> = []

    private let service = LocalAIService()
    private let downloadService = LocalModelDownloadService()

    var sendDisabled: Bool {
        draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedPhoto == nil
    }

    func reportError(_ message: String) {
        errorText = message
        showError = true
    }

    func refreshModelStatus() async {
        modelStatus = await service.status()
    }

    func refreshDownloadedModels() async {
        downloadedModels = await downloadService.listDownloadedModels()
    }

    func sendCurrentMessage() {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isGenerating, !trimmed.isEmpty || selectedPhoto != nil else { return }

        let history = messages.map(\.conversationTurn)
        let image = selectedPhoto
        let imageData = image?.jpegData(compressionQuality: 0.82)
        let userMessage = LocalAIMessage(role: .user, text: trimmed, photo: image)
        messages.append(userMessage)

        draftMessage = ""
        selectedPhoto = nil
        isGenerating = true

        Task {
            do {
                let reply = try await service.generateReply(
                    history: history,
                    prompt: trimmed,
                    imageJPEGData: imageData
                )
                messages.append(LocalAIMessage(role: .assistant, text: reply, photo: nil))
                isGenerating = false
            } catch {
                isGenerating = false
                reportError(error.localizedDescription)
            }

            await refreshModelStatus()
        }
    }

    func clearConversation() {
        messages.removeAll()
        selectedPhoto = nil
        draftMessage = ""
        Task { await service.resetConversation() }
    }

    func apply(configuration newConfiguration: LocalAIConfiguration) {
        isUpdatingConfiguration = true
        Task {
            do {
                try await service.updateConfiguration(newConfiguration)
                configuration = newConfiguration
            } catch {
                reportError(error.localizedDescription)
            }

            isUpdatingConfiguration = false
            await refreshModelStatus()
        }
    }

    func downloadModel(_ model: DownloadableVisionModel) {
        guard !downloadingModelIDs.contains(model.id) else { return }
        downloadingModelIDs.insert(model.id)

        Task {
            defer { downloadingModelIDs.remove(model.id) }

            do {
                try await downloadService.download(model)
                await refreshDownloadedModels()
            } catch {
                reportError(error.localizedDescription)
            }
        }
    }
}

private actor LocalAIService {
    private var configuration = LocalAIConfiguration.load()
    private var session: LanguageModelSession?

    private func selectedChatModel() -> LocalChatModelOption {
        LocalChatModelOption.option(for: configuration.selectedChatModelID)
    }

    func updateConfiguration(_ newConfiguration: LocalAIConfiguration) async throws {
        configuration = newConfiguration.normalized()
        configuration.save()
        session = nil
        try await ensureSession()
    }

    func resetConversation() {
        session = nil
    }

    func status() async -> LocalAIModelStatus {
        let selectedModel = selectedChatModel()
        let model: SystemLanguageModel = .default
        let detail = "Selected: \(selectedModel.label)"

        switch model.availability {
        case .available:
            return .init(title: "Ready", detail: detail, isReady: true)
        case .unavailable(let reason):
            return .init(title: "Unavailable", detail: reason.localizedDescription, isReady: false)
        }
    }

    func generateReply(
        history: [LocalAIConversationTurn],
        prompt: String,
        imageJPEGData: Data?
    ) async throws -> String {
        try await ensureSession()

        var composedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if let imageJPEGData {
            let visionSummary = try await LocalVisionAnalyzer.summarize(jpegData: imageJPEGData)
            let normalizedPrompt = composedPrompt.isEmpty ? "What do you see in this image?" : composedPrompt
            composedPrompt = """
            Image context extracted on-device:
            \(visionSummary)

            User request:
            \(normalizedPrompt)
            """
        }

        if composedPrompt.isEmpty {
            throw LocalAIServiceError.emptyPrompt
        }

        let response = try await currentSession().respond(
            to: buildTranscriptPrompt(history: history, latestUserPrompt: composedPrompt),
            options: GenerationOptions(
                temperature: configuration.temperature,
                maximumResponseTokens: configuration.maxResponseTokens
            )
        )

        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LocalAIServiceError.emptyResponse
        }
        return text
    }

    private func buildTranscriptPrompt(history: [LocalAIConversationTurn], latestUserPrompt: String) -> String {
        let recent = history.suffix(8)
        var lines: [String] = ["Conversation context:"]

        for turn in recent {
            let rolePrefix = turn.role == .user ? "User" : "Assistant"
            lines.append("\(rolePrefix): \(turn.text)")
        }

        lines.append("User: \(latestUserPrompt)")
        lines.append("Assistant:")
        return lines.joined(separator: "\n")
    }

    private func ensureSession() async throws {
        _ = try await currentSession()
    }

    private func currentSession() async throws -> LanguageModelSession {
        if let session {
            return session
        }

        let model: SystemLanguageModel = .default

        guard model.isAvailable else {
            throw LocalAIServiceError.modelUnavailable(model.availability.localizedDescription)
        }

        let session = LanguageModelSession(
            model: model,
            instructions: configuration.systemPrompt
        )
        self.session = session
        return session
    }
}

private struct LocalAISettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State var configuration: LocalAIConfiguration
    let modelStatus: LocalAIModelStatus
    let downloadableModels: [DownloadableVisionModel]
    let downloadedModels: [LocalDownloadedModel]
    let downloadingModelIDs: Set<String>
    let isSaving: Bool
    let onDownloadModel: (DownloadableVisionModel) -> Void
    let onSave: (LocalAIConfiguration) -> Void

    var body: some View {
        Form {
            Section("Model") {
                Text("Choose one chat model. The selected model handles both text and image prompts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Chat Model", selection: $configuration.selectedChatModelID) {
                    ForEach(LocalChatModelOption.options) { model in
                        Text(model.label).tag(Optional(model.id))
                    }
                }

                HStack {
                    Text("Status")
                    Spacer()
                    Text(modelStatus.title)
                        .foregroundStyle(modelStatus.isReady ? .green : .orange)
                }
                Text(modelStatus.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Downloaded Core ML models below are assets for local experimentation and are not used as direct chat LLMs in this simplified flow.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("Core ML Vision Models") {
                Text("Download Core ML model packages for on-device vision analysis. You can select any downloaded model above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(downloadableModels) { model in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                Text("\(model.task) • \(model.parameterCountLabel) • \(model.runtimeLabel) • \(model.format)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            if downloadedModels.contains(where: { $0.id == model.id }) {
                                Label("Downloaded", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Button(downloadingModelIDs.contains(model.id) ? "Downloading..." : "Download") {
                                    onDownloadModel(model)
                                }
                                .disabled(downloadingModelIDs.contains(model.id))
                                .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                if !downloadedModels.isEmpty {
                    Divider()
                    ForEach(downloadedModels) { downloaded in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(downloaded.displayName)
                                .font(.caption)
                            Text("Saved: \(downloaded.formattedSize)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Generation") {
                Stepper(value: $configuration.maxResponseTokens, in: 64...2048, step: 32) {
                    Text("Max tokens: \(configuration.maxResponseTokens)")
                }

                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(String(format: "%.2f", configuration.temperature))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $configuration.temperature, in: 0...1.5)
            }

            Section("System prompt") {
                TextEditor(text: $configuration.systemPrompt)
                    .frame(minHeight: 120)
            }
        }
        .navigationTitle("Local AI Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(configuration.normalized())
                    dismiss()
                }
                .disabled(isSaving)
            }
        }
    }
}

private struct LocalAIMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
    let photo: UIImage?

    var conversationTurn: LocalAIConversationTurn {
        .init(role: role == .user ? .user : .assistant, text: text)
    }
}

private struct LocalAIConversationTurn: Sendable {
    enum Role: Sendable {
        case user
        case assistant
    }

    let role: Role
    let text: String
}

private struct LocalAIModelStatus: Sendable {
    let title: String
    let detail: String
    let isReady: Bool

    static let checking = LocalAIModelStatus(title: "Checking", detail: "Validating local model availability...", isReady: false)
}

private struct LocalChatModelOption: Identifiable, Sendable {
    enum Kind: Sendable {
        case appleFoundation
    }

    let id: String
    let label: String
    let kind: Kind

    static let options: [LocalChatModelOption] = [
        .init(id: "apple-foundation", label: "Apple Foundation (On-Device)", kind: .appleFoundation)
    ]

    static let defaultID = "apple-foundation"

    static func option(for id: String?) -> LocalChatModelOption {
        guard let id,
              let match = options.first(where: { $0.id == id }) else {
            return options[0]
        }
        return match
    }
}

private struct DownloadableVisionModel: Identifiable, Hashable, Sendable {
    struct FileResource: Hashable, Sendable {
        let remoteURLString: String
        let localRelativePath: String

        var remoteURL: URL? {
            URL(string: remoteURLString)
        }
    }

    let id: String
    let displayName: String
    let task: String
    let parameterCountLabel: String
    let runtimeLabel: String
    let format: String
    let packageDirectoryName: String
    let files: [FileResource]

    static let catalog: [DownloadableVisionModel] = [
        .init(
            id: "coreml-mobileclip-s0-image",
            displayName: "MobileCLIP S0 (Image Encoder)",
            task: "Image embeddings",
            parameterCountLabel: "~33M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "mobileclip_s0_image.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_s0_image.mlpackage/Manifest.json?download=true",
                    localRelativePath: "Manifest.json"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_s0_image.mlpackage/Data/com.apple.CoreML/model.mlmodel?download=true",
                    localRelativePath: "Data/com.apple.CoreML/model.mlmodel"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_s0_image.mlpackage/Data/com.apple.CoreML/weights/weight.bin?download=true",
                    localRelativePath: "Data/com.apple.CoreML/weights/weight.bin"
                )
            ]
        ),
        .init(
            id: "coreml-depth-anything-v2-small-f16",
            displayName: "Depth Anything V2 Small (F16)",
            task: "Depth estimation",
            parameterCountLabel: "~25M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "DepthAnythingV2SmallF16.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-depth-anything-v2-small/resolve/main/DepthAnythingV2SmallF16.mlpackage/Manifest.json?download=true",
                    localRelativePath: "Manifest.json"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-depth-anything-v2-small/resolve/main/DepthAnythingV2SmallF16.mlpackage/Data/com.apple.CoreML/model.mlmodel?download=true",
                    localRelativePath: "Data/com.apple.CoreML/model.mlmodel"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-depth-anything-v2-small/resolve/main/DepthAnythingV2SmallF16.mlpackage/Data/com.apple.CoreML/weights/weight.bin?download=true",
                    localRelativePath: "Data/com.apple.CoreML/weights/weight.bin"
                )
            ]
        ),
        .init(
            id: "coreml-detr-segmentation-f16",
            displayName: "DETR Semantic Segmentation (F16)",
            task: "Semantic segmentation",
            parameterCountLabel: "~41M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "DETRResnet50SemanticSegmentationF16.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-detr-semantic-segmentation/resolve/main/DETRResnet50SemanticSegmentationF16.mlpackage/Manifest.json?download=true",
                    localRelativePath: "Manifest.json"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-detr-semantic-segmentation/resolve/main/DETRResnet50SemanticSegmentationF16.mlpackage/Data/com.apple.CoreML/model.mlmodel?download=true",
                    localRelativePath: "Data/com.apple.CoreML/model.mlmodel"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-detr-semantic-segmentation/resolve/main/DETRResnet50SemanticSegmentationF16.mlpackage/Data/com.apple.CoreML/weights/weight.bin?download=true",
                    localRelativePath: "Data/com.apple.CoreML/weights/weight.bin"
                )
            ]
        ),
        .init(
            id: "coreml-mobileclip-s1-image",
            displayName: "MobileCLIP S1 (Image Encoder)",
            task: "Image embeddings",
            parameterCountLabel: "~73M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "mobileclip_s1_image.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_s1_image.mlpackage/Manifest.json?download=true",
                    localRelativePath: "Manifest.json"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_s1_image.mlpackage/Data/com.apple.CoreML/model.mlmodel?download=true",
                    localRelativePath: "Data/com.apple.CoreML/model.mlmodel"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_s1_image.mlpackage/Data/com.apple.CoreML/weights/weight.bin?download=true",
                    localRelativePath: "Data/com.apple.CoreML/weights/weight.bin"
                )
            ]
        ),
        .init(
            id: "coreml-mobileclip-s2-image",
            displayName: "MobileCLIP S2 (Image Encoder)",
            task: "Image embeddings",
            parameterCountLabel: "~152M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "mobileclip_s2_image.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_s2_image.mlpackage/Manifest.json?download=true",
                    localRelativePath: "Manifest.json"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_s2_image.mlpackage/Data/com.apple.CoreML/model.mlmodel?download=true",
                    localRelativePath: "Data/com.apple.CoreML/model.mlmodel"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_s2_image.mlpackage/Data/com.apple.CoreML/weights/weight.bin?download=true",
                    localRelativePath: "Data/com.apple.CoreML/weights/weight.bin"
                )
            ]
        ),
        .init(
            id: "coreml-mobileclip-blt-image",
            displayName: "MobileCLIP B(LT) (Image Encoder)",
            task: "Image embeddings",
            parameterCountLabel: "~307M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "mobileclip_blt_image.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_blt_image.mlpackage/Manifest.json?download=true",
                    localRelativePath: "Manifest.json"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_blt_image.mlpackage/Data/com.apple.CoreML/model.mlmodel?download=true",
                    localRelativePath: "Data/com.apple.CoreML/model.mlmodel"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-mobileclip/resolve/main/mobileclip_blt_image.mlpackage/Data/com.apple.CoreML/weights/weight.bin?download=true",
                    localRelativePath: "Data/com.apple.CoreML/weights/weight.bin"
                )
            ]
        ),
        .init(
            id: "coreml-depth-anything-small-f16",
            displayName: "Depth Anything Small (F16)",
            task: "Depth estimation",
            parameterCountLabel: "~25M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "DepthAnythingSmallF16.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-depth-anything-small/resolve/main/DepthAnythingSmallF16.mlpackage/Manifest.json?download=true",
                    localRelativePath: "Manifest.json"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-depth-anything-small/resolve/main/DepthAnythingSmallF16.mlpackage/Data/com.apple.CoreML/model.mlmodel?download=true",
                    localRelativePath: "Data/com.apple.CoreML/model.mlmodel"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-depth-anything-small/resolve/main/DepthAnythingSmallF16.mlpackage/Data/com.apple.CoreML/weights/weight.bin?download=true",
                    localRelativePath: "Data/com.apple.CoreML/weights/weight.bin"
                )
            ]
        ),
        .init(
            id: "coreml-sam2-large-image-encoder",
            displayName: "SAM2 Large (Image Encoder)",
            task: "Mask generation encoder",
            parameterCountLabel: "~224M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "SAM2LargeImageEncoderFLOAT16.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-sam2-large/resolve/main/SAM2LargeImageEncoderFLOAT16.mlpackage/Manifest.json?download=true",
                    localRelativePath: "Manifest.json"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-sam2-large/resolve/main/SAM2LargeImageEncoderFLOAT16.mlpackage/Data/com.apple.CoreML/model.mlmodel?download=true",
                    localRelativePath: "Data/com.apple.CoreML/model.mlmodel"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-sam2-large/resolve/main/SAM2LargeImageEncoderFLOAT16.mlpackage/Data/com.apple.CoreML/weights/weight.bin?download=true",
                    localRelativePath: "Data/com.apple.CoreML/weights/weight.bin"
                )
            ]
        ),
        .init(
            id: "coreml-fastvlm-1.5b-int8",
            displayName: "FastVLM 1.5B (INT8)",
            task: "Vision-language chat",
            parameterCountLabel: "~1.5B params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "fastvithd-fastvlm-1_5b-int8.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/apple/FastVLM-1.5B-int8/resolve/main/fastvithd.mlpackage/Manifest.json?download=true",
                    localRelativePath: "Manifest.json"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/FastVLM-1.5B-int8/resolve/main/fastvithd.mlpackage/Data/com.apple.CoreML/model.mlmodel?download=true",
                    localRelativePath: "Data/com.apple.CoreML/model.mlmodel"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/FastVLM-1.5B-int8/resolve/main/fastvithd.mlpackage/Data/com.apple.CoreML/weights/weight.bin?download=true",
                    localRelativePath: "Data/com.apple.CoreML/weights/weight.bin"
                )
            ]
        ),
        .init(
            id: "coreml-fastvlm-7b-int4",
            displayName: "FastVLM 7B (INT4)",
            task: "Vision-language chat",
            parameterCountLabel: "~7B params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "fastvithd-fastvlm-7b-int4.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/apple/FastVLM-7B-int4/resolve/main/fastvithd.mlpackage/Manifest.json?download=true",
                    localRelativePath: "Manifest.json"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/FastVLM-7B-int4/resolve/main/fastvithd.mlpackage/Data/com.apple.CoreML/model.mlmodel?download=true",
                    localRelativePath: "Data/com.apple.CoreML/model.mlmodel"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/apple/FastVLM-7B-int4/resolve/main/fastvithd.mlpackage/Data/com.apple.CoreML/weights/weight.bin?download=true",
                    localRelativePath: "Data/com.apple.CoreML/weights/weight.bin"
                )
            ]
        ),
        .init(
            id: "coreml-fastvlm-7b-mlx-4bit",
            displayName: "FastVLM 7B (MLX 4-bit, community)",
            task: "Vision-language chat",
            parameterCountLabel: "~7B params",
            runtimeLabel: "Core ML (Community)",
            format: "Core ML .mlpackage",
            packageDirectoryName: "fastvithd-fastvlm-7b-mlx-4bit.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/InsightKeeper/FastVLM-7B-MLX-4bit/resolve/main/fastvithd.mlpackage/Manifest.json?download=true",
                    localRelativePath: "Manifest.json"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/InsightKeeper/FastVLM-7B-MLX-4bit/resolve/main/fastvithd.mlpackage/Data/com.apple.CoreML/model.mlmodel?download=true",
                    localRelativePath: "Data/com.apple.CoreML/model.mlmodel"
                ),
                .init(
                    remoteURLString: "https://huggingface.co/InsightKeeper/FastVLM-7B-MLX-4bit/resolve/main/fastvithd.mlpackage/Data/com.apple.CoreML/weights/weight.bin?download=true",
                    localRelativePath: "Data/com.apple.CoreML/weights/weight.bin"
                )
            ]
        )
    ]
}

private struct LocalDownloadedModel: Identifiable {
    let id: String
    let displayName: String
    let localPackageURL: URL
    let fileSizeBytes: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
}

private enum LocalModelDownloadError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The model download URL is invalid."
        }
    }
}

private actor LocalModelDownloadService {
    private let fileManager = FileManager.default

    func listDownloadedModels() -> [LocalDownloadedModel] {
        DownloadableVisionModel.catalog.compactMap { model in
            let packageURL = packageDirectoryURL(for: model)
            let allFilesPresent = model.files.allSatisfy { file in
                let fileURL = packageURL.appendingPathComponent(file.localRelativePath)
                return fileManager.fileExists(atPath: fileURL.path)
            }

            guard allFilesPresent else {
                return nil
            }

            let totalBytes = model.files.reduce(Int64(0)) { partial, file in
                let fileURL = packageURL.appendingPathComponent(file.localRelativePath)
                guard let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                      let sizeNumber = attrs[.size] as? NSNumber else {
                    return partial
                }
                return partial + sizeNumber.int64Value
            }

            return LocalDownloadedModel(
                id: model.id,
                displayName: model.displayName,
                localPackageURL: packageURL,
                fileSizeBytes: totalBytes
            )
        }
    }

    func download(_ model: DownloadableVisionModel) async throws {
        try ensureModelsDirectoryExists()
        let packageURL = packageDirectoryURL(for: model)

        if fileManager.fileExists(atPath: packageURL.path) {
            try fileManager.removeItem(at: packageURL)
        }
        try fileManager.createDirectory(at: packageURL, withIntermediateDirectories: true)

        for file in model.files {
            guard let remoteURL = file.remoteURL else {
                throw LocalModelDownloadError.invalidURL
            }
            let destinationURL = packageURL.appendingPathComponent(file.localRelativePath)
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            let (temporaryURL, _) = try await URLSession.shared.download(from: remoteURL)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        }
    }

    func packageDirectoryURL(for model: DownloadableVisionModel) -> URL {
        modelsDirectoryURL().appendingPathComponent(model.packageDirectoryName, isDirectory: true)
    }

    private func modelsDirectoryURL() -> URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("local_models", isDirectory: true)
    }

    private func destinationURL(for model: DownloadableVisionModel) -> URL {
        packageDirectoryURL(for: model)
    }

    private func ensureModelsDirectoryExists() throws {
        try fileManager.createDirectory(at: modelsDirectoryURL(), withIntermediateDirectories: true)
    }
}

private enum LocalAIServiceError: LocalizedError {
    case emptyPrompt
    case emptyResponse
    case modelUnavailable(String)
    case visionAnalysisFailed

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "Please enter a message or attach an image."
        case .emptyResponse:
            return "The local model returned an empty response."
        case .modelUnavailable(let details):
            return "Local model unavailable: \(details)"
        case .visionAnalysisFailed:
            return "Unable to analyze the attached image locally."
        }
    }
}

private struct LocalAIConfiguration: Codable, Sendable, Equatable {
    var selectedChatModelID: String?
    var selectedVisionModelID: String?
    var systemPrompt: String
    var maxResponseTokens: Int
    var temperature: Double

    static let defaults = LocalAIConfiguration(
        selectedChatModelID: LocalChatModelOption.defaultID,
        selectedVisionModelID: nil,
        systemPrompt: "You are a helpful assistant running entirely on-device. Prioritize concise, practical answers.",
        maxResponseTokens: 600,
        temperature: 0.5
    )

    private static let storageKey = "local_ai_configuration"

    static func load() -> LocalAIConfiguration {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(LocalAIConfiguration.self, from: data) else {
            return .defaults
        }
        return decoded.normalized()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(normalized()) else { return }
        UserDefaults.standard.set(data, forKey: LocalAIConfiguration.storageKey)
    }

    func normalized() -> LocalAIConfiguration {
        let normalizedChatModelID: String
        if LocalChatModelOption.options.contains(where: { $0.id == selectedChatModelID }) {
            normalizedChatModelID = selectedChatModelID ?? LocalChatModelOption.defaultID
        } else {
            normalizedChatModelID = LocalChatModelOption.defaultID
        }

        return .init(
            selectedChatModelID: normalizedChatModelID,
            selectedVisionModelID: selectedVisionModelID,
            systemPrompt: systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? LocalAIConfiguration.defaults.systemPrompt : systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            maxResponseTokens: min(max(maxResponseTokens, 64), 2048),
            temperature: min(max(temperature, 0), 1.5)
        )
    }
}

private enum LocalVisionModelStorage {
    static func modelsDirectoryURL() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("local_models", isDirectory: true)
    }

    static func packageDirectoryURL(for model: DownloadableVisionModel) -> URL {
        modelsDirectoryURL().appendingPathComponent(model.packageDirectoryName, isDirectory: true)
    }
}

private enum LocalVisionAnalyzer {
    static func summarize(jpegData: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            guard let uiImage = UIImage(data: jpegData),
                  let cgImage = uiImage.cgImage else {
                throw LocalAIServiceError.visionAnalysisFailed
            }

            let classificationRequest = VNClassifyImageRequest()
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            textRequest.minimumTextHeight = 0.02
            let faceRequest = VNDetectFaceRectanglesRequest()

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try handler.perform([classificationRequest, textRequest, faceRequest])

            let labels = (classificationRequest.results ?? [])
                .prefix(6)
                .map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }

            let extractedText = (textRequest.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .prefix(8)
                .joined(separator: " | ")

            let faceCount = faceRequest.results?.count ?? 0

            var chunks: [String] = []
            if !labels.isEmpty {
                chunks.append("Top visual labels: \(labels.joined(separator: ", "))")
            }
            if !extractedText.isEmpty {
                chunks.append("Recognized text: \(extractedText)")
            }
            if faceCount > 0 {
                chunks.append("Detected faces: \(faceCount)")
            }

            if chunks.isEmpty {
                return "No strong visual features were detected."
            }

            return chunks.joined(separator: "\n")
        }.value
    }
}

private struct LocalUIImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = false
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

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private extension SystemLanguageModel.Availability.UnavailableReason {
    var localizedDescription: String {
        switch self {
        case .deviceNotEligible:
            return "This device does not support on-device foundation models."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled on this device."
        case .modelNotReady:
            return "The local model is still being prepared by the system."
        @unknown default:
            return "The local model is currently unavailable."
        }
    }
}

@available(iOS 26.0, *)
private extension SystemLanguageModel.Availability {
    var localizedDescription: String {
        switch self {
        case .available:
            return "Available"
        case .unavailable(let reason):
            return reason.localizedDescription
        }
    }
}
#endif

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
    @State private var selectedOpenRouterModelID = OpenRouterVisionModel.defaults.id

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
            Picker("Vision Model", selection: $selectedOpenRouterModelID) {
                ForEach(OpenRouterVisionModel.options) { model in
                    Text(model.label).tag(model.id)
                }
            }

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
                    model: selectedOpenRouterModelID,
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

private struct OpenRouterVisionModel: Identifiable {
    let id: String
    let label: String

    static let defaults = OpenRouterVisionModel(
        id: "qwen/qwen2.5-vl-3b-instruct",
        label: "Qwen2.5-VL 3B"
    )

    static let options: [OpenRouterVisionModel] = [
        defaults,
        .init(id: "qwen/qwen2.5-vl-3b-instruct:free", label: "Qwen2.5-VL 3B (Free)"),
        .init(id: "openai/gpt-4o-mini", label: "GPT-4o Mini")
    ]
}

struct OpenRouterClient {
    static let shared = OpenRouterClient()

    fileprivate func sendMessage(
        apiKey: String,
        model: String,
        history: [LocalAIConversationTurn],
        userText: String,
        imageJPEGData: Data?
    ) async throws -> String {
        let messageHistory = history.map { turn in
            AIChatMessage(
                role: turn.role == .user ? .user : .assistant,
                text: turn.text,
                photo: nil
            )
        }

        return try await sendMessage(
            apiKey: apiKey,
            model: model,
            history: messageHistory,
            userText: userText,
            imageJPEGData: imageJPEGData
        )
    }

    func sendMessage(
        apiKey: String,
        model: String,
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
            "model": model,
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
            model: OpenRouterVisionModel.defaults.id,
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

    func sendSingleImagePrompt(apiKey: String, model: String, prompt: String, imageJPEGData: Data) async throws -> String {
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
            "model": model,
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