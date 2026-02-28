import Foundation
import AVFoundation
import Combine

enum GrokVoiceError: Error, LocalizedError {
    case notConnected
    case audioSetupFailed(String)
    case websocketError(String)
    case apiKeyMissing
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Grok Voice service"
        case .audioSetupFailed(let message):
            return "Audio setup failed: \(message)"
        case .websocketError(let message):
            return "WebSocket error: \(message)"
        case .apiKeyMissing:
            return "xAI API key is missing"
        }
    }
}

enum GrokVoiceState {
    case disconnected
    case connecting
    case listening
    case processing
    case speaking
    case error(String)
}

struct GrokTranscriptEntry: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let timestamp: Date
}

@MainActor
class GrokVoiceService: NSObject, ObservableObject {
    @Published var state: GrokVoiceState = .disconnected
    @Published var transcript: [GrokTranscriptEntry] = []
    @Published var currentOutput: String = ""
    @Published var debugLogs: [String] = []
    @Published var isPlaying = false
    @Published var errorMessage: String? = nil
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var inputFormat: AVAudioFormat?
    private var apiKey: String = ""
    private var incomingAudioData = Data()
    
    let voices = ["Ara", "Rex", "Sal", "Eve", "Leo"]
    @Published var selectedVoice = "Ara"
    @Published var systemInstructions = "You are a helpful gardening assistant."
    
    override init() {
        super.init()
        loadAPIKey()
    }
    
    private func loadAPIKey() {
        apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? ""
        if apiKey.isEmpty {
            debugLogs.append("[GrokVoice] API key not found - set XAI_API_KEY env var")
        } else {
            debugLogs.append("[GrokVoice] API key loaded")
        }
    }
    
    func setAPIKey(_ key: String) {
        apiKey = key
        debugLogs.append("[GrokVoice] API key set")
    }
    
    func connect() async throws {
        guard !apiKey.isEmpty else {
            let error = GrokVoiceError.apiKeyMissing
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            debugLogs.append("[GrokVoice] Error: \(error.localizedDescription)")
            throw error
        }
        
        state = .connecting
        errorMessage = nil
        debugLogs.append("[GrokVoice] Connecting...")
        
        guard let url = URL(string: "wss://api.x.ai/v1/realtime") else {
            throw GrokVoiceError.websocketError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        debugLogs.append("[GrokVoice] WebSocket created, sending config...")
        
        let sessionConfig: [String: Any] = [
            "type": "session.update",
            "session": [
                "voice": selectedVoice,
                "instructions": systemInstructions
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: sessionConfig),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            sendMessage(jsonString)
        }
        
        state = .listening
        debugLogs.append("[GrokVoice] Ready")
        
        receiveMessage()
        
        Task {
            do {
                try await startAudioCapture()
            } catch {
                debugLogs.append("[GrokVoice] Audio error: \(error.localizedDescription)")
            }
        }
    }
    
    func disconnect() {
        debugLogs.append("[GrokVoice] Disconnecting...")
        stopAudioCapture()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        state = .disconnected
        debugLogs.append("[GrokVoice] Disconnected")
    }
    
    func sendMessage(_ message: String) {
        guard let task = webSocketTask else {
            errorMessage = "Not connected"
            return
        }
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        task.send(wsMessage) { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.debugLogs.append("[GrokVoice] Send error: \(error.localizedDescription)")
                    self?.errorMessage = "Send error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.receiveMessage()
                case .failure(let error):
                    self.debugLogs.append("[GrokVoice] Receive error: \(error.localizedDescription)")
                    self.errorMessage = "Connection error: \(error.localizedDescription)"
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let jsonString: String
        switch message {
        case .string(let text): jsonString = text
        case .data(let data): jsonString = String(data: data, encoding: .utf8) ?? ""
        @unknown default: return
        }
        
        debugLogs.append("[GrokVoice] RX: \(jsonString.prefix(80))...")
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        switch type {
        case "response.output_audio.delta":
            if let delta = json["delta"] as? String {
                handleIncomingAudio(delta)
            }
        case "response.output_audio_transcript.delta":
            if let delta = json["delta"] as? String {
                currentOutput += delta
            }
        case "input_audio_buffer.speech_started":
            state = .listening
        case "response.done":
            state = .listening
        case "error":
            if let message = json["message"] as? String {
                errorMessage = message
                state = .error(message)
            }
        default:
            break
        }
    }
    
    private func handleIncomingAudio(_ base64Audio: String) {
        state = .speaking
        isPlaying = true
        
        guard let audioData = Data(base64Encoded: base64Audio) else { return }
        
        do {
            let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
            let audioPCMBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(audioData.count / 2))!
            audioPCMBuffer.frameLength = AVAudioFrameCount(audioData.count / 2)
            
            audioData.withUnsafeMutableBytes { rawBuffer in
                if let baseAddress = rawBuffer.baseAddress {
                    let floatBuffer = baseAddress.assumingMemoryBound(to: Int16.self)
                    let floatPtr = audioPCMBuffer.floatChannelData![0]
                    for i in 0..<Int(audioPCMBuffer.frameLength) {
                        floatPtr[i] = Float(floatBuffer[i]) / 32768.0
                    }
                }
            }
            
            playAudioBuffer(audioPCMBuffer)
        } catch {
            debugLogs.append("[GrokVoice] Play error: \(error.localizedDescription)")
        }
    }
    
    private func playAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        if audioEngine == nil {
            setupAudioPlayer()
        }
        
        guard let player = audioPlayer, let engine = audioEngine else { return }
        
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
                if self?.state == .speaking {
                    self?.state = .listening
                }
            }
        }
        
        if !engine.isRunning {
            try? engine.start()
        }
    }
    
    private func setupAudioPlayer() {
        audioEngine = AVAudioEngine()
        audioPlayer = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = audioPlayer else { return }
        
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
        
        try? engine.start()
    }
    
    private func startAudioCapture() async throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)
        
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.processInputAudio(buffer)
            }
        }
        
        try engine.start()
        debugLogs.append("[GrokVoice] Mic started")
    }
    
    private func processInputAudio(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameCount = Int(buffer.frameLength)
        var pcmData = Data()
        
        for i in 0..<frameCount {
            let sample = Int16(channelData[i] * 32767)
            var littleEndian = sample.littleEndian
            pcmData.append(Data(bytes: &littleEndian, count: 2))
        }
        
        let base64Audio = pcmData.base64EncodedString()
        
        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            sendMessage(jsonString)
        }
    }
    
    private func stopAudioCapture() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }
    
    func clearLogs() {
        debugLogs.removeAll()
    }
    
    func clearOutput() {
        currentOutput = ""
        transcript.removeAll()
    }
}

extension GrokVoiceService: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor in
            self.debugLogs.append("[GrokVoice] WebSocket opened")
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in
            self.debugLogs.append("[GrokVoice] WebSocket closed: \(closeCode)")
            self.state = .disconnected
        }
    }
}
