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

struct PersonActionTabView: View {
    @State private var selectedImage: UIImage?
    @State private var resultText = ""
    @State private var isAnalyzing = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var errorText: String?
    @State private var showModelPicker = false
    @State private var selectedModelID = "vision"
    @State private var modelStatus = "Select a model"
    @State private var showGGUFFilePicker = false
    @State private var selectedGGUFURL: URL?
    
    private let models = [
        ("vision", "Vision Framework", "Apple's built-in (basic)"),
        ("fastvlm-1.5b", "FastVLM 1.5B (INT8)", "~1.5B params - vision language"),
        ("fastvlm-7b", "FastVLM 7B (INT4)", "~7B params - most powerful"),
        ("resnet50", "ResNet-50", "~25M params - image classification"),
        ("gguf-lfm", "LFM 2.5 VL 1.6B (GGUF)", "~1.6B params - local GGUF model")
    ]
    
    private var currentModelName: String {
        models.first { $0.0 == selectedModelID }?.1 ?? "Select Model"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Model selector button
                    Button {
                        showModelPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentModelName)
                                    .font(.subheadline.weight(.medium))
                                Text(modelStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
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
                    
                    // GGUF file browser button
                    if selectedModelID == "gguf-lfm" {
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
                    }
                    
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
                            Text("Detected Action")
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
            .sheet(isPresented: $showModelPicker) {
                NavigationStack {
                    List {
                        ForEach(models, id: \.0) { model in
                            Button {
                                selectedModelID = model.0
                                if model.0 == "vision" {
                                    modelStatus = "Using Vision Framework"
                                } else {
                                    modelStatus = "Tap Analyze to download/use model"
                                }
                                showModelPicker = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(model.1)
                                            .foregroundStyle(.primary)
                                        Text(model.2)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if model.0 == selectedModelID {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Select Model")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showModelPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
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

        errorText = nil
        resultText = ""
        isAnalyzing = true

        Task {
            do {
                let analysis: String
                
                // Actually use the selected model
                switch selectedModelID {
                case "fastvlm-1.5b", "fastvlm-7b":
                    modelStatus = "Loading FastVLM model..."
                    analysis = try await analyzeWithFastVLMModel(cgImage: cgImage, modelID: selectedModelID)
                    
                case "resnet50", "mobilenetv2":
                    modelStatus = "Loading CoreML model..."
                    analysis = try await analyzeWithCoreMLModel(cgImage: cgImage, modelID: selectedModelID)
                    
                case "gguf-lfm":
                    modelStatus = "Loading GGUF model..."
                    analysis = try await analyzeWithGGUFModel(cgImage: cgImage)
                    
                default:
                    // Vision framework (default)
                    if #available(iOS 17.0, *) {
                        modelStatus = "Analyzing with Vision framework..."
                        analysis = try await analyzeWithVisualIntelligence(cgImage: cgImage)
                    } else {
                        modelStatus = "Using Vision Framework..."
                        analysis = try await performVisionAnalysis(cgImage: cgImage)
                    }
                }
                
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
            "What is happening in this image?" or "Describe this photo in detail."
            
            For now, here's a detailed analysis using Vision framework:
            
            \(try await performVisionAnalysis(cgImage: cgImage))
            """
        } catch {
            return "Failed to load model: \(error.localizedDescription)"
        }
    }

    // MARK: - CoreML Model Analysis (ResNet)
    
    private func analyzeWithCoreMLModel(cgImage: CGImage, modelID: String) async throws -> String {
        let downloadService = LocalModelDownloadService()
        let downloaded = await downloadService.listDownloadedModels()
        
        let catalogModelID = "coreml-resnet50-imagenet"
        
        guard let model = downloaded.first(where: { $0.id == catalogModelID }) else {
            // Try to download
            if let modelToDownload = DownloadableVisionModel.catalog.first(where: { $0.id == catalogModelID }) {
                modelStatus = "Downloading \(modelID) model..."
                do {
                    try await downloadService.download(modelToDownload)
                } catch {
                    return "Download failed: \(error.localizedDescription). Check your internet connection and try again."
                }
                
                guard let downloadedModel = (await downloadService.listDownloadedModels()).first(where: { $0.id == catalogModelID }) else {
                    return "Download failed. Please try again."
                }
                
                return try await runCoreMLClassification(cgImage: cgImage, model: downloadedModel)
            }
            
            return "Model '\(modelID)' not found in catalog."
        }
        
        return try await runCoreMLClassification(cgImage: cgImage, model: model)
    }
    
    private func runCoreMLClassification(cgImage: CGImage, model: LocalDownloadedModel) async throws -> String {
        modelStatus = "Running \(model.displayName)..."
        
        let packageURL = model.localPackageURL
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
            return "Could not find .mlmodel file."
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            do {
                let mlModel = try MLModel(contentsOf: modelURL, configuration: config)
                let vnModel = try VNCoreMLModel(for: mlModel)
                
                let request = VNClassifyImageRequest()
                request.revision = VNClassifyImageRequestRevision1
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                // Use the CoreML model for classification
                let coreMLRequest = VNCoreMLRequest(model: vnModel) { request, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let observations = request.results as? [VNClassificationObservation] else {
                        continuation.resume(returning: "No results from model")
                        return
                    }
                    
                    let topResults = observations.prefix(15).filter { $0.confidence > 0.05 }
                    let labels = topResults.map { "\($0.identifier.replacingOccurrences(of: "_", with: " ")) (\(Int($0.confidence * 100))%)" }
                    
                    let result = """
                    🔍 \(model.displayName) Classification Results:
                    
                    Top detections:
                    \(labels.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
                    
                    This model identified \(observations.count) possible classes in the image.
                    """
                    
                    continuation.resume(returning: result)
                }
                
                try handler.perform([coreMLRequest, VNClassifyImageRequest()])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - GGUF Model Analysis (LLaMA.cpp)
    
    private func analyzeWithGGUFModel(cgImage: CGImage) async throws -> String {
        // First check if user selected a specific GGUF file
        if let selectedURL = selectedGGUFURL, FileManager.default.fileExists(atPath: selectedURL.path) {
            return try await runGGUFInference(cgImage: cgImage, modelURL: selectedURL)
        }
        
        // Otherwise look for any GGUF models in Documents directory
        var modelURL: URL?
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        // Check for models in Documents root or Models subfolder
        if let docsURL = documentsURL {
            // Look for any .gguf file in Documents
            if let enumerator = FileManager.default.enumerator(at: docsURL, includingPropertiesForKeys: nil) {
                while let fileURL = enumerator.nextObject() as? URL {
                    if fileURL.pathExtension.lowercased() == "gguf" {
                        modelURL = fileURL
                        break
                    }
                }
            }
        }
        
        guard let finalModelURL = modelURL else {
            return "No GGUF model found.\n\nTap 'Browse for GGUF file' above to select a model file, or:\n1. Download a model in the 'Locally' app\n2. Open Files app → tap ... → Add to Files\n3. Select Garden Manager's Documents folder\n4. Try analyzing again!"
        }
        
        return try await runGGUFInference(cgImage: cgImage, modelURL: finalModelURL)
    }
    
    private func runGGUFInference(cgImage: CGImage, modelURL: URL) async throws -> String {
        modelStatus = "Running GGUF inference..."
        
        // Use SwiftLlama to run inference
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let llamaService = try LlamaService(
                        modelUrl: finalModelURL,
                        config: .init(batchSize: 512, maxTokenCount: 4096, useGPU: true)
                    )
                    
                    // Create a prompt asking about the image
                    let messages = [
                        LlamaChatMessage(role: .user, content: "Describe what you see in this image in detail.")
                    ]
                    
                    var result = ""
                    let stream = try await llamaService.streamCompletion(
                        of: messages,
                        samplingConfig: .init(temperature: 0.7, seed: 42)
                    )
                    
                    for try await token in stream {
                        result += token
                    }
                    
                    continuation.resume(returning: result.isEmpty ? "No response from model" : result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Visual Intelligence (iOS 17+) - Much Smarter Analysis
    
    @available(iOS 17.0, *)
    private func analyzeWithVisualIntelligence(cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest()
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
                return
            }
            
            // Visual Intelligence using Apple's built-in intelligence
            // Use multiple Vision requests combined with Apple's image analysis
            let classificationRequest = VNClassifyImageRequest()
            let poseRequest = VNDetectHumanBodyPoseRequest()
            let faceRequest = VNDetectFaceRectanglesRequest()
            let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
            
            do {
                try handler.perform([classificationRequest, poseRequest, faceRequest, saliencyRequest])
            } catch {
                // Continue with what we have
            }
            
            var results: [String] = []
            
            // 1. Get detailed scene classification
            if let classifications = classificationRequest.results, !classifications.isEmpty {
                let topResults = classifications.prefix(20)
                let labels = topResults.filter { $0.confidence > 0.03 }.map { 
                    "\($0.identifier.replacingOccurrences(of: "_", with: " ")) (\(Int($0.confidence * 100))%)" 
                }
                
                // Interpret the scene
                let sceneDescription = interpretScene(from: labels.map { $0.lowercased() })
                results.append("📍 Scene: \(sceneDescription)")
                results.append("   Objects: \(labels.prefix(8).joined(separator: ", ")))")
            }
            
            // 2. Detailed body pose analysis
            if let poses = poseRequest.results, !poses.isEmpty {
                for (index, pose) in poses.prefix(3).enumerated() {
                    let activity = detailedPoseAnalysis(pose)
                    let bodyLang = describeDetailedBodyLanguage(pose)
                    results.append("🧍 Person \(index + 1): \(activity)")
                    if !bodyLang.isEmpty {
                        results.append("   Posture: \(bodyLang)")
                    }
                }
            }
            
            // 3. Face analysis
            let faces = faceRequest.results ?? []
            if !faces.isEmpty {
                results.append("👤 Faces: \(faces.count) detected")
                if faces.count == 1 {
                    results.append("   Single person facing camera")
                } else {
                    results.append("   Group of \(faces.count) people")
                }
            }
            
//             // 4. Saliency - what's the focus of the image
//             if let saliency = saliencyRequest.results?.first {
//                 let saliencyPoints = saliency.pixelObservations?.count ?? 0
//                 if saliencyPoints > 0 {
//                     results.append("🎯 Focus: Multiple points of interest detected")
//                 }
//             }
            
            // 5. Generate comprehensive summary
            let summary = generateComprehensiveSummary(
                classifications: classificationRequest.results ?? [],
                poses: poseRequest.results ?? [],
                faces: faces.count
            )
            
            let output = results.joined(separator: "\n")
            let finalOutput = output + "\n\n📋 Summary: \(summary)"
            
            continuation.resume(returning: finalOutput)
        }
    }

    private func interpretScene(from labels: [String]) -> String {
        let labelText = labels.joined(separator: " ")
        
        // Determine scene type
        var scene = "general environment"
        
        let scenes: [(keywords: [String], name: String)] = [
            (["indoor", "room", "kitchen", "bedroom", "bathroom", "office", "living"], "indoor"),
            (["outdoor", "street", "park", "beach", "mountain", "garden", "yard", "road", "sky"], "outdoor"),
            (["gym", "workout", "fitness", "exercise", "yoga", "sport", "running", "training"], "fitness/sports"),
            (["kitchen", "cooking", "food", "meal", "restaurant", "table"], "kitchen/dining"),
            (["home", "house", "couch", "sofa", "bed", "living room", "bedroom"], "residential"),
            (["car", "vehicle", "road", "street", "highway", "driving"], "vehicle/travel"),
            (["water", "ocean", "beach", "swimming", "pool", "lake"], "water/ocean"),
            (["forest", "tree", "nature", "mountain", "hiking", "trail"], "nature/outdoor"),
            (["computer", "desk", "laptop", "keyboard", "office", "work", "meeting"], "workspace"),
            (["shop", "store", "market", "shopping", "retail"], "store/shopping")
        ]
        
        for (keywords, name) in scenes {
            for keyword in keywords {
                if labelText.contains(keyword) {
                    scene = name
                    break
                }
            }
            if scene != "general environment" { break }
        }
        
        return scene
    }

    private func detailedPoseAnalysis(_ pose: VNHumanBodyPoseObservation) -> String {
        guard let leftWrist = try? pose.recognizedPoint(.leftWrist),
              let rightWrist = try? pose.recognizedPoint(.rightWrist),
              let leftShoulder = try? pose.recognizedPoint(.leftShoulder),
              let rightShoulder = try? pose.recognizedPoint(.rightShoulder),
              let nose = try? pose.recognizedPoint(.nose),
              let leftElbow = try? pose.recognizedPoint(.leftElbow),
              let rightElbow = try? pose.recognizedPoint(.rightElbow),
              let leftHip = try? pose.recognizedPoint(.leftHip),
              let rightHip = try? pose.recognizedPoint(.rightHip) else {
            return "position unclear"
        }
        
        let avgWristY = (leftWrist.location.y + rightWrist.location.y) / 2
        let avgShoulderY = (leftShoulder.location.y + rightShoulder.location.y) / 2
        let avgElbowY = (leftElbow.location.y + rightElbow.location.y) / 2
        let wristSpread = abs(leftWrist.location.x - rightWrist.location.x)
        
        // Detailed activity detection
        if avgWristY < nose.location.y - 0.2 {
            return "reaching up high / celebrating"
        } else if avgWristY < nose.location.y - 0.1 {
            if wristSpread > 0.4 {
                return "arms raised wide / excited"
            }
            return "arms raised above shoulders"
        } else if avgElbowY < avgShoulderY - 0.1 {
            if abs(leftElbow.location.x - leftShoulder.location.x) > 0.15 {
                return "hands on hips / frustrated/impatient"
            }
            return "arms bent at elbows"
        } else if wristSpread > 0.5 {
            return "arms spread wide open"
        } else if wristSpread < 0.12 {
            if avgWristY > avgShoulderY + 0.15 {
                return "arms folded / defensive stance"
            }
            return "arms close together"
        } else if avgWristY > avgShoulderY + 0.3 {
            return "arms hanging at sides / relaxed"
        }
        
        // Check for walking/running
        let hipSpread = abs(leftHip.location.x - rightHip.location.x)
        if hipSpread > 0.2 {
            return "walking or moving"
        }
        
        return "standing naturally"
    }

    private func describeDetailedBodyLanguage(_ pose: VNHumanBodyPoseObservation) -> String {
        var descriptions: [String] = []
        
        guard let leftShoulder = try? pose.recognizedPoint(.leftShoulder),
              let rightShoulder = try? pose.recognizedPoint(.rightShoulder),
              let leftHip = try? pose.recognizedPoint(.leftHip),
              let rightHip = try? pose.recognizedPoint(.rightHip) else {
            return ""
        }
        
        // Body tilt
        let shoulderY = (leftShoulder.location.y + rightShoulder.location.y) / 2
        let hipY = (leftHip.location.y + rightHip.location.y) / 2
        let tilt = shoulderY - hipY
        
        if tilt > 0.2 {
            descriptions.append("leaning back")
        } else if tilt < -0.2 {
            descriptions.append("leaning forward")
        }
        
        // Shoulder orientation
        let shoulderWidth = abs(leftShoulder.location.x - rightShoulder.location.x)
        let hipWidth = abs(leftHip.location.x - rightHip.location.x)
        
        if shoulderWidth < hipWidth * 0.8 {
            descriptions.append("body turned to side")
        } else if shoulderWidth > hipWidth * 1.4 {
            descriptions.append("broad stance")
        }
        
        return descriptions.joined(separator: ", ")
    }

    private func generateComprehensiveSummary(classifications: [VNClassificationObservation], poses: [VNHumanBodyPoseObservation], faces: Int) -> String {
        var parts: [String] = []
        
        // Number of people
        let personCount = max(poses.count, faces)
        if personCount == 0 {
            parts.append("No people detected in the image")
        } else if personCount == 1 {
            parts.append("One person is")
        } else {
            parts.append("\(personCount) people are")
        }
        
        // What they're doing
        if let pose = poses.first {
            let activity = detailedPoseAnalysis(pose)
            parts.append(activity)
        }
        
        // Environment
        if let topClass = classifications.first {
            let env = topClass.identifier.replacingOccurrences(of: "_", with: " ")
            parts.append("in a \(env) setting")
        }
        
        // Face info
        if !poses.isEmpty {
            if faces > 0 {
                parts.append("and facing the camera")
            } else {
                parts.append("with their back turned or face not visible")
            }
        }
        
        return parts.joined(separator: " ") + "."
    }

    private func analyzeWithFastVLM(cgImage: CGImage, modelSize: String) async throws -> String {
        // FastVLM is a vision-language model that can answer questions
        // For now, we'll use a prompt-based approach to get detailed description
        
        // First, check if we have a downloaded FastVLM model
        let downloadService = LocalModelDownloadService()
        let downloaded = await downloadService.listDownloadedModels()
        
        let modelID = modelSize == "fastvlm-7b" ? "coreml-fastvlm-7b-int4" : "coreml-fastvlm-1.5b-int8"
        
        guard let model = downloaded.first(where: { $0.id == modelID }) else {
            // Try to download the model
            if let modelToDownload = DownloadableVisionModel.catalog.first(where: { $0.id == modelID }) {
                modelStatus = "Downloading \(modelSize) model..."
                try await downloadService.download(modelToDownload)
            } else {
                return "FastVLM model not found in catalog. Please select a different model."
            }
            
            // Try to load after download
            guard let downloadedModel = (await downloadService.listDownloadedModels()).first(where: { $0.id == modelID }) else {
                return "Failed to download \(modelSize) model. Check your internet connection."
            }
            
            // Load and use the model
            return try await runFastVLMInference(cgImage: cgImage, model: downloadedModel)
        }
        
        return try await runFastVLMInference(cgImage: cgImage, model: model)
    }

    private func runFastVLMInference(cgImage: CGImage, model: LocalDownloadedModel) async throws -> String {
        // Load the CoreML model
        let packageURL = model.localPackageURL
        let mlModelURL = packageURL.appendingPathComponent(model.displayName + ".mlmodel")
        
        let config = MLModelConfiguration()
        config.computeUnits = .all
        
        modelStatus = "Loading model..."
        let mlModel = try await MLModel.load(contentsOf: mlModelURL, configuration: config)
        
        // For vision-language models, we'd need to use the appropriate input/output
        // This is a simplified version - the full implementation would use the VL model's interface
        // For now, fall back to detailed vision analysis since FastVLM interface is complex
        
        // Return a message that FastVLM needs special handling
        // In production, you'd implement the full VL prompt interface
        return """
        FastVLM \(model.displayName) loaded successfully!

        This is a vision-language model capable of detailed image understanding.

        Note: Full FastVLM inference requires implementing the text prompt interface.
        For now, using enhanced Vision framework analysis instead:

        \(try await performVisionAnalysis(cgImage: cgImage))
        """
    }

    private func performVisionAnalysis(cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            // Multiple Vision requests for comprehensive analysis
            let classificationRequest = VNClassifyImageRequest()
            // // let personRequest = VNDetectPersonRectanglesRequest() // Not available // Not available in iOS 26
            let poseRequest = VNDetectHumanBodyPoseRequest()
            let faceRequest = VNDetectFaceRectanglesRequest()
            
            do {
                try handler.perform([classificationRequest, poseRequest, faceRequest])
            } catch {
                continuation.resume(throwing: error)
                return
            }
            
            var results: [String] = []
            
            // 1. Person detection - disabled (VNDetectPersonRectanglesRequest not available)
            // let personCount = personRequest.results?.count ?? 0
            // if personCount > 0 {
            //     results.append("\(personCount) person(s) detected")
            // }
            // 2. Classification - get all results above threshold
            if let classifications = classificationRequest.results, !classifications.isEmpty {
                let relevant = classifications.prefix(10).filter { $0.confidence > 0.1 }
                let labels = relevant.map { $0.identifier }
                results.append("Scene: " + labels.joined(separator: ", "))
            }
            
            // 3. Body pose analysis for activity
            if let pose = poseRequest.results?.first {
                let activity = describeActivityFromPose(pose)
                results.append("Activity: \(activity)")
            }
            
            // 4. Face detection
            let faceCount = faceRequest.results?.count ?? 0
            if faceCount > 0 {
                results.append("\(faceCount) face(s) visible")
            }
            
            // Generate summary
            let summary: String
            // Use pose detection
            if let pose = poseRequest.results?.first {
                let activity = describeActivityFromPose(pose)
                summary = "Person - \(activity)"
            } else if let classifications = classificationRequest.results, !classifications.isEmpty {
                let top3 = classifications.prefix(3).map { $0.identifier }.joined(separator: ", ")
                summary = "Likely: \(top3)"
            } else {
                summary = results.isEmpty ? "Unable to analyze" : results.joined(separator: "\n")
            }
            
            continuation.resume(returning: summary)
        }
    }

    private func describeActivityFromPose(_ pose: VNHumanBodyPoseObservation) -> String {
        guard let leftWrist = try? pose.recognizedPoint(.leftWrist),
              let rightWrist = try? pose.recognizedPoint(.rightWrist),
              let leftShoulder = try? pose.recognizedPoint(.leftShoulder),
              let rightShoulder = try? pose.recognizedPoint(.rightShoulder),
              let nose = try? pose.recognizedPoint(.nose) else {
            return "position unclear"
        }
        
        let avgWristY = (leftWrist.location.y + rightWrist.location.y) / 2
        let avgShoulderY = (leftShoulder.location.y + rightShoulder.location.y) / 2
        let wristSpread = abs(leftWrist.location.x - rightWrist.location.x)
        
        if avgWristY < nose.location.y - 0.1 {
            return "arms raised above head"
        } else if avgWristY < avgShoulderY - 0.1 {
            return "arms raised"
        } else if wristSpread > 0.4 {
            return "arms extended outward"
        } else if avgWristY > avgShoulderY + 0.2 {
            return "arms down/by side"
        }
        
        return "standing naturally"
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
// MARK: - Document Picker for GGUF Files

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
