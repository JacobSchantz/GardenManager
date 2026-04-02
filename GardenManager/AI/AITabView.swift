import SwiftUI
import UIKit
import Vision
import CoreML
import UniformTypeIdentifiers
#if canImport(FoundationModels)
import FoundationModels
#endif
import SwiftLlama

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

// MARK: - Local AI Tab (Simplified GGUF Chat)

private let kSelectedGGUFURLBookmark = "selectedGGUFURLBookmark"

struct LocalAITabView: View {
    @StateObject private var viewModel = LocalAIChatViewModel()

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
            .alert("Local AI Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorText)
            }
            .task {
                await viewModel.loadSavedModel()
            }
            .onChange(of: viewModel.selectedGGUFURL) { _, newURL in
                if let url = newURL {
                    Task {
                        await viewModel.useSelectedModel(at: url)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.modelName.isEmpty ? "No model selected" : viewModel.modelName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    Text(viewModel.modelName.isEmpty ? "Pick a GGUF file to start chatting" : "On-device inference via llama.cpp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
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
        .padding(12)
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cpu")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Pick a GGUF model file, then send a message.")
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
            Divider()

            HStack(spacing: 10) {
                TextField("Message", text: $viewModel.draftMessage)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.selectedGGUFURL == nil)

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
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - ViewModel

@MainActor
private final class LocalAIChatViewModel: ObservableObject {
    @Published var draftMessage = ""
    @Published var messages: [LocalAIMessage] = []
    @Published var isGenerating = false
    @Published var showError = false
    @Published var errorText = ""
    @Published var showFilePicker = false
    @Published var selectedGGUFURL: URL?
    @Published var lastError: String?

    private var llamaService: LlamaService?
    private var conversationHistory: [LocalAIMessage] = []

    var sendDisabled: Bool {
        draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedGGUFURL == nil
    }

    var modelName: String {
        selectedGGUFURL?.deletingPathExtension().lastPathComponent ?? ""
    }

    // MARK: - GGUF URL Persistence

    func loadSavedModel() async {
        // Since DocumentPicker uses asCopy: true, files are copied to app documents.
        // We save the path directly.
        guard let savedPath = UserDefaults.standard.string(forKey: "localAI_GGUFPath") else {
            return
        }
        let url = URL(fileURLWithPath: savedPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            UserDefaults.standard.removeObject(forKey: "localAI_GGUFPath")
            return
        }
        selectedGGUFURL = url
        await initializeLlama(with: url)
    }

    func saveGGUFURLBookmark(_ url: URL) {
        // DocumentPicker uses asCopy: true, so the file is in app's documents.
        // Save the path directly.
        UserDefaults.standard.set(url.path, forKey: "localAI_GGUFPath")
    }

    // MARK: - Llama Initialization

    func useSelectedModel(at url: URL) async {
        // DocumentPicker uses asCopy: true, so the URL is already a local copy
        // We can directly use it without security-scoped access
        selectedGGUFURL = url
        saveGGUFURLBookmark(url)
        await initializeLlama(with: url)
        // Clear conversation when model changes
        messages.removeAll()
        conversationHistory.removeAll()
    }

    private func initializeLlama(with url: URL) async {
        llamaService = nil
        do {
            let service = LlamaService(
                modelUrl: url,
                config: LlamaConfig(batchSize: 512, maxTokenCount: 2048, useGPU: true)
            )
            llamaService = service
        } catch {
            reportError("Failed to initialize model: \(error.localizedDescription)")
        }
    }

    // MARK: - Send Message

    func sendCurrentMessage() {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isGenerating, !trimmed.isEmpty else { return }
        guard let url = selectedGGUFURL else {
            reportError("Please select a GGUF model file first.")
            return
        }

        lastError = nil

        let userMessage = LocalAIMessage(role: .user, text: trimmed)
        messages.append(userMessage)
        conversationHistory.append(userMessage)
        draftMessage = ""
        isGenerating = true

        Task {
            // Initialize llama service if needed
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
                let reply = try await generateReply(for: trimmed, service: service)
                await MainActor.run {
                    let assistantMessage = LocalAIMessage(role: .assistant, text: reply)
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

    private func generateReply(for prompt: String, service: LlamaService) async throws -> String {
        // Build prompt with conversation history
        let historyText = conversationHistory
            .dropLast() // exclude the current user message (already in prompt)
            .suffix(10)
            .map { turn -> String in
                let role = turn.role == .user ? "User" : "Assistant"
                return "\(role): \(turn.text)"
            }
            .joined(separator: "\n")

        let fullPrompt: String
        if historyText.isEmpty {
            fullPrompt = "User: \(prompt)\nAssistant:"
        } else {
            fullPrompt = "\(historyText)\nUser: \(prompt)\nAssistant:"
        }

        guard !conversationHistory.isEmpty else {
            throw LocalAIServiceError.modelNotLoaded
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

    func clearConversation() {
        messages.removeAll()
        conversationHistory.removeAll()
        lastError = nil
        llamaService = nil
        // Re-initialize if we have a URL
        if let url = selectedGGUFURL {
            Task { await initializeLlama(with: url) }
        }
    }

    private func reportError(_ message: String) {
        errorText = message
        showError = true
    }
}

// MARK: - Models

private struct LocalAIMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

private struct LocalAIModelStatus: Sendable {
    let title: String
    let detail: String
    let isReady: Bool

    static let noModel = LocalAIModelStatus(
        title: "No model",
        detail: "Pick a GGUF file to begin",
        isReady: false
    )
}

private enum LocalAIServiceError: LocalizedError {
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

private struct DocumentPickerView: UIViewControllerRepresentable {
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

// MARK: - Person Action Tab (unchanged)

struct PersonActionTabView: View {
    @State private var selectedImage: UIImage?
    @State private var resultText = ""
    @State private var usedModelName = ""
    @State private var isAnalyzing = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var errorText: String?
    @State private var modelStatus = "Select a GGUF file"
    @State private var showGGUFFilePicker = false
    @State private var selectedGGUFURL: URL?

    // Shared GGUF URL for chat (persisted)
    @AppStorage(kSelectedGGUFURLBookmark, store: UserDefaults.standard)
    private var ggufBookmarkData: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // GGUF file browser button - main interaction
                    Button {
                        showGGUFFilePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedGGUFURL?.lastPathComponent ?? "Browse for GGUF file")
                                    .font(.subheadline.weight(.medium))
                                Text(selectedGGUFURL != nil ? "File selected" : "Tap to select a .gguf file")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)

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
                            analyzeWithVision()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAnalyzing || selectedImage == nil)
                    }

                    if isAnalyzing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Analyzing...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let errorText {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorText)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                            Button {
                                UIPasteboard.general.string = errorText
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.red.opacity(0.1))
                        )
                    }

                    if !resultText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Detected Action")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = resultText
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy")
                                    }
                                    .font(.caption)
                                }
                            }
                            Text(resultText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                )

                            // Show which model was actually used
                            if !usedModelName.isEmpty {
                                HStack {
                                    Image(systemName: "cpu")
                                        .font(.caption)
                                    Text("Model: \(usedModelName)")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Person Action")
            .onAppear { loadSavedGGUFURL() }
            .onChange(of: selectedGGUFURL) { _, newURL in
                if let url = newURL {
                    saveGGUFURL(url)
                }
            }
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
            .sheet(isPresented: $showGGUFFilePicker) {
                DocumentPickerView(selectedURL: $selectedGGUFURL)
            }
        }
    }

    private func analyzeWithVision() {
        guard !isAnalyzing, let uiImage = selectedImage, let cgImage = uiImage.cgImage else {
            errorText = "Please choose an image first."
            return
        }

        guard selectedGGUFURL != nil else {
            errorText = "Please select a GGUF model file first."
            return
        }

        errorText = nil
        resultText = ""
        isAnalyzing = true

        Task {
            do {
                modelStatus = "Loading GGUF model..."
                let analysis = try await analyzeWithGGUFModel(cgImage: cgImage)
                let modelName = selectedGGUFURL?.lastPathComponent ?? "GGUF Model"
                usedModelName = modelName

                await MainActor.run {
                    resultText = analysis
                    isAnalyzing = false
                    modelStatus = "Analysis complete"
                }
            } catch {
                await MainActor.run {
                    errorText = "Analysis failed: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }

    // MARK: - GGUF URL Persistence

    private func loadSavedGGUFURL() {
        // Since DocumentPicker uses asCopy: true, the file is in app's documents
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path
        guard let savedPath = UserDefaults.standard.string(forKey: "selectedGGUFPath"),
              let docsPath = documentsPath,
              savedPath.contains(docsPath) || savedPath.hasPrefix("/var/") else {
            return
        }

        let url = URL(fileURLWithPath: savedPath)
        if FileManager.default.fileExists(atPath: url.path) {
            selectedGGUFURL = url
            modelStatus = "Loaded saved model"
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedGGUFPath")
        }
    }

    private func saveGGUFURL(_ url: URL) {
        // Save the absolute path since asCopy: true copies to app sandbox
        UserDefaults.standard.set(url.path, forKey: "selectedGGUFPath")
    }

    // MARK: - FastVLM Model Analysis

    private func analyzeWithFastVLMModel(cgImage: CGImage, modelID: String) async throws -> String {
        let downloadService = LocalModelDownloadService()
        let downloaded = await downloadService.listDownloadedModels()

        let catalogModelID = modelID == "fastvlm-7b" ? "coreml-fastvlm-7b-int4" : "coreml-fastvlm-1.5b-int8"

        // Check if model is downloaded
        guard let model = downloaded.first(where: { $0.id == catalogModelID }) else {
            // Try to download
            if let modelToDownload = DownloadableVisionModel.catalog.first(where: { $0.id == catalogModelID }) {
                modelStatus = "Downloading \(modelID) model (this may take a while)..."
                try await downloadService.download(modelToDownload)

                // Try loading again after download
                guard let downloadedModel = (await downloadService.listDownloadedModels()).first(where: { $0.id == catalogModelID }) else {
                    return "Download failed. Please try again or check your internet connection."
                }

                return try await runFastVLMCoreML(cgImage: cgImage, model: downloadedModel)
            }

            return "Model '\(modelID)' not found in catalog. Please select a different model."
        }

        return try await runFastVLMCoreML(cgImage: cgImage, model: model)
    }

    private func runFastVLMCoreML(cgImage: CGImage, model: LocalDownloadedModel) async throws -> String {
        modelStatus = "Running FastVLM inference..."

        // For FastVLM, we need to use it as a CoreML model
        // FastVLM takes image input and outputs text
        // The interface depends on how the model was exported

        // Try loading the model
        let packageURL = model.localPackageURL

        // Find the .mlmodel file
        let fileManager = FileManager.default
        var mlmodelURL: URL?

        if let enumerator = fileManager.enumerator(at: packageURL, includingPropertiesForKeys: nil) {
            while let fileURL = enumerator.nextObject() as? URL {
                if fileURL.pathExtension == "mlmodel" {
                    mlmodelURL = fileURL
                    break
                }
            }
        }

        guard let modelURL = mlmodelURL else {
            return "Could not find .mlmodel file in downloaded package."
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all

            let mlModel = try await MLModel.load(contentsOf: modelURL, configuration: config)

            // Get model description to understand inputs/outputs
            let description = mlModel.modelDescription
            let inputNames = description.inputDescriptionsByName.keys.joined(separator: ", ")
            let outputNames = description.outputDescriptionsByName.keys.joined(separator: ", ")

            return """
            ⚡ FastVLM Model Loaded Successfully!

            Model: \(model.displayName)
            Input: \(inputNames)
            Output: \(outputNames)

            Note: FastVLM is a vision-language model. To use it properly, you need to:
            1. Pass the image as input
            2. Provide a text prompt asking what you want to know about the image
            3. Get the text response from the model output

            The current implementation requires a prompt to be sent with the image.
            Consider adding a text field for the user to ask questions like:
            "What action is this person performing?" or "Describe this image."
            """
        } catch {
            return "Failed to load CoreML model: \(error.localizedDescription)"
        }
    }

    // MARK: - GGUF Model Analysis

    private func analyzeWithGGUFModel(cgImage: CGImage) async throws -> String {
        guard let modelURL = selectedGGUFURL else {
            throw NSError(domain: "LocalAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "No GGUF model selected"])
        }

        // Analyze image using Vision
        let visionSummary = try await summarizeImage(cgImage: cgImage)

        // Create prompt for GGUF model
        let prompt = """
        Based on the following image analysis, describe what action or activity the person is performing:

        Image Analysis:
        \(visionSummary)

        Please provide a detailed description of the detected action, including any objects involved, the likely context, and your confidence in the analysis.
        """

        // Run GGUF inference
        let ggufService = try await GGUFInferenceService(modelURL: modelURL)
        let response = try await ggufService.generateResponse(prompt: prompt)

        return response
    }

    private func summarizeImage(cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let classificationRequest = VNClassifyImageRequest()
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            textRequest.minimumTextHeight = 0.02
            let faceRequest = VNDetectFaceRectanglesRequest()

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
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
                    continuation.resume(returning: "No strong visual features were detected.")
                } else {
                    continuation.resume(returning: chunks.joined(separator: "\n"))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - GGUF Inference Service for PersonActionTabView

private actor GGUFInferenceService {
    private var service: LlamaService?
    private let modelUrl: URL

    init(modelURL: URL) async throws {
        self.modelUrl = modelURL
        self.service = LlamaService(
            modelUrl: modelURL,
            config: LlamaConfig(batchSize: 512, maxTokenCount: 4096, useGPU: true)
        )
    }

    func generateResponse(prompt: String) async throws -> String {
        guard let service else {
            throw NSError(domain: "GGUFInference", code: 2, userInfo: [NSLocalizedDescriptionKey: "Service not initialized"])
        }

        let chatMessage = LlamaChatMessage(role: .user, content: prompt)
        let samplingConfig = LlamaSamplingConfig(temperature: 0.7, seed: 42, grammarConfig: nil)

        var result = ""
        let stream = try await service.streamCompletion(of: [chatMessage], samplingConfig: samplingConfig)

        for try await token in stream {
            result += token
        }

        return result.isEmpty ? "No response from model." : result
    }
}

// MARK: - Supporting Types for PersonActionTabView

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
        ),
        // Image Classification Models for Action Recognition
        .init(
            id: "coreml-resnet50-imagenet",
            displayName: "ResNet-50 (ImageNet)",
            task: "Image Classification",
            parameterCountLabel: "~25M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlmodel",
            packageDirectoryName: "Resnet50.mlmodel",
            files: [
                .init(
                    remoteURLString: "https://huggingface.co/apple/coreml-resnet-50/resolve/main/Resnet50.mlmodel",
                    localRelativePath: "Resnet50.mlmodel"
                )
            ]
        ),
        .init(
            id: "coreml-squeezenet-imagenet",
            displayName: "SqueezeNet (ImageNet)",
            task: "Image Classification",
            parameterCountLabel: "~1.2M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "SqueezeNet.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://docs-assets.developer.apple.com/coreml-models/SqueezeNet.mlmodel/1/SqueezeNet.mlmodel",
                    localRelativePath: "SqueezeNet.mlmodel"
                )
            ]
        ),
        .init(
            id: "coreml-vgg16-imagenet",
            displayName: "VGG-16 (ImageNet)",
            task: "Image Classification",
            parameterCountLabel: "~138M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "VGG16.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://docs-assets.developer.apple.com/coreml-models/VGG16.mlmodel/1/VGG16.mlmodel",
                    localRelativePath: "VGG16.mlmodel"
                )
            ]
        ),
        .init(
            id: "coreml-inceptionv3-imagenet",
            displayName: "InceptionV3 (ImageNet)",
            task: "Image Classification",
            parameterCountLabel: "~23M params",
            runtimeLabel: "Core ML",
            format: "Core ML .mlpackage",
            packageDirectoryName: "InceptionV3.mlpackage",
            files: [
                .init(
                    remoteURLString: "https://docs-assets.developer.apple.com/coreml-models/InceptionV3.mlmodel/1/InceptionV3.mlmodel",
                    localRelativePath: "InceptionV3.mlmodel"
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

// MARK: - OpenRouter Chat (unchanged)

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

    func sendMessage(
        apiKey: String,
        model: String,
        history: [AIChatMessage],
        userText: String,
        imageJPEGData: Data?
    ) async throws -> String {
        var messages: [[String: Any]] = []

        for message in history {
            if let photo = message.photo, let imageData = photo.jpegData(compressionQuality: 0.8) {
                let base64Image = imageData.base64EncodedString()
                messages.append([
                    "role": message.role.openRouterRole,
                    "content": [
                        ["type": "text", "text": message.text],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                    ]
                ])
            } else {
                messages.append([
                    "role": message.role.openRouterRole,
                    "content": message.text
                ])
            }
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
