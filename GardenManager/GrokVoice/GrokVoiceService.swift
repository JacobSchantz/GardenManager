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
        case .notConnected: return "Not connected"
        case .audioSetupFailed(let msg): return "Audio: \(msg)"
        case .websocketError(let msg): return "WebSocket: \(msg)"
        case .apiKeyMissing: return "API key missing"
        }
    }
}

enum GrokVoiceState: Equatable {
    case disconnected
    case connecting
    case listening
    case processing
    case speaking
    case error(String)
}

enum PermissionStatus: Equatable {
    case unknown
    case notDetermined
    case granted
    case denied

    var label: String {
        switch self {
        case .unknown: return "Unknown"
        case .notDetermined: return "Not Determined"
        case .granted: return "Granted"
        case .denied: return "Denied"
        }
    }
}

enum ServicePermission {
    case microphone
}

@MainActor
class GrokVoiceService: NSObject, ObservableObject {
    @Published var state: GrokVoiceState = .disconnected
    @Published var currentOutput: String = ""
    @Published var responses: [String] = []
    @Published var apiMessages: [String] = []  // All API messages for debugging
    @Published var debugLogs: [String] = []
    @Published var isPlaying = false
    @Published var errorMessage: String? = nil
    @Published private(set) var microphonePermissionStatus: PermissionStatus = .unknown
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var apiKey: String = ""
    private var isInputTapInstalled = false
    
    let voices = ["Ara", "Rex", "Sal", "Eve", "Leo"]
    @Published var selectedVoice = "Ara"
    @Published var systemInstructions = "You are a helpful assistant."
    
    override init() {
        super.init()
        loadAPIKey()
        refreshPermissionStatus()
    }
    
    private let apiKeyStorageKey = "xAI_API_Key"
    
    private func loadAPIKey() {
        // First try environment variable, then UserDefaults
        apiKey = (ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if apiKey.isEmpty {
            // Try loading from UserDefaults
            if let savedKey = UserDefaults.standard.string(forKey: apiKeyStorageKey) {
                apiKey = savedKey
                debugLogs.insert("API key loaded from cache", at: 0)
            } else {
                debugLogs.insert("API key not found", at: 0)
            }
        } else {
            debugLogs.insert("API key loaded from environment", at: 0)
        }
    }
    
    func setAPIKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKey.isEmpty {
            debugLogs.insert("API key is empty after trimming.", at: 0)
            UserDefaults.standard.removeObject(forKey: apiKeyStorageKey)
        } else {
            // Save to UserDefaults
            UserDefaults.standard.set(apiKey, forKey: apiKeyStorageKey)
            debugLogs.insert("API key saved to cache", at: 0)
        }
    }

    var hasMicrophonePermission: Bool {
        microphonePermissionStatus == .granted
    }

    func refreshPermissionStatus() {
        let permission = AVAudioSession.sharedInstance().recordPermission
        microphonePermissionStatus = mapPermission(permission)
    }

    @discardableResult
    func requestPermission(_ permission: ServicePermission) async -> Bool {
        switch permission {
        case .microphone:
            return await ensureMicrophonePermission()
        }
    }

    private func mapPermission(_ permission: AVAudioSession.RecordPermission) -> PermissionStatus {
        switch permission {
        case .undetermined: return .notDetermined
        case .denied: return .denied
        case .granted: return .granted
        @unknown default: return .unknown
        }
    }

    private func ensureMicrophonePermission() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        let currentPermission = session.recordPermission
        microphonePermissionStatus = mapPermission(currentPermission)

        switch currentPermission {
        case .granted:
            return true
        case .denied:
            reportFailure("Microphone permission denied. Enable microphone access in Settings.")
            return false
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            microphonePermissionStatus = granted ? .granted : .denied

            if !granted {
                reportFailure("Microphone permission denied. Enable microphone access in Settings.")
            }
            return granted
        @unknown default:
            microphonePermissionStatus = .unknown
            reportFailure("Unable to determine microphone permission status.")
            return false
        }
    }
    
    func connect() async {
        guard !apiKey.isEmpty else {
            reportFailure(GrokVoiceError.apiKeyMissing.localizedDescription)
            return
        }

        guard await requestPermission(.microphone) else {
            return
        }

        guard let url = URL(string: "wss://api.x.ai/v1/realtime") else {
            reportFailure(GrokVoiceError.websocketError("Invalid URL").localizedDescription)
            return
        }

        state = .connecting
        errorMessage = nil
        debugLogs.insert("Connecting...", at: 0)
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        urlSession = URLSession(configuration: .default)
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()

        debugLogs.insert("WebSocket created, sending config...", at: 0)
        debugLogs.insert("Handshake headers: Authorization(Bearer ...), Content-Type(application/json)", at: 0)

        let sessionConfig: [String: Any] = [
            "type": "session.update",
            "session": [
                "voice": selectedVoice,
                "instructions": systemInstructions,
                "modalities": ["audio", "text"],
                "input_audio_format": "pcm_s16le",
                "output_audio_format": "pcm_s16le"
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: sessionConfig),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            reportFailure("Failed to encode session configuration.")
            teardownConnection(markDisconnected: false)
            return
        }

        do {
            try await Task.sleep(nanoseconds: 300_000_000)
        } catch {
            reportFailure("Connection setup was interrupted.")
            teardownConnection(markDisconnected: false)
            return
        }

        sendMessage(jsonString)
        if case .error = state {
            teardownConnection(markDisconnected: false)
            return
        }

        state = .listening
        debugLogs.insert("Ready", at: 0)

        receiveMessage()

        do {
            try await startAudioCapture()
        } catch {
            reportFailure("Microphone setup failed: \(error.localizedDescription)")
            teardownConnection(markDisconnected: false)
        }
    }
    
    func disconnect() {
        debugLogs.insert("Disconnecting...", at: 0)
        teardownConnection(markDisconnected: true)
    }

    private func teardownConnection(markDisconnected: Bool) {
        receiveTask?.cancel()
        receiveTask = nil
        stopAudioCapture()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil

        if markDisconnected {
            state = .disconnected
        }
    }
    
    func sendMessage(_ message: String) {
        guard let task = webSocketTask else {
            reportFailure(GrokVoiceError.notConnected.localizedDescription)
            return
        }

        Task { [weak self] in
            do {
                try await task.send(.string(message))
            } catch {
                await MainActor.run {
                    guard let self = self else { return }
                    let details = self.formatError(error)
                    self.reportFailure("Send error: \(details)")
                }
            }
        }
    }
    
    func receiveMessage() {
        guard let task = webSocketTask else {
            reportFailure(GrokVoiceError.notConnected.localizedDescription)
            return
        }

        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    await MainActor.run {
                        self.handleMessage(message)
                    }
                } catch {
                    if Task.isCancelled { return }
                    await MainActor.run {
                        let details = self.formatError(error)
                        self.reportFailure("RX error: \(details)")
                    }
                    return
                }
            }
        }
    }
    
    private func formatError(_ error: Error) -> String {
        var msg = error.localizedDescription
        if let urlError = error as? URLError {
            msg += " (code: \(urlError.code.rawValue))"
            if let failingURL = urlError.failingURL?.absoluteString {
                msg += ", URL: \(failingURL)"
            }

            if urlError.code == .badServerResponse {
                msg += ". WebSocket handshake was rejected by xAI. Verify API key, account access to Realtime/Voice Agent, and endpoint wss://api.x.ai/v1/realtime"
            }
        }
        return msg
    }

    private func reportFailure(_ message: String) {
        errorMessage = message
        debugLogs.insert("Error: \(message)", at: 0)
        state = .error(message)
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let jsonString: String
        switch message {
        case .string(let t): jsonString = t
        case .data(let d): jsonString = String(data: d, encoding: .utf8) ?? ""
        @unknown default: return
        }
        
        // Store all API messages for debugging
        apiMessages.insert(jsonString, at: 0)
        
        debugLogs.insert("RX: \(jsonString.prefix(60))...", at: 0)

        guard let data = jsonString.data(using: .utf8) else {
            reportFailure("Received non-UTF8 message from server.")
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            reportFailure("Failed to parse server message.")
            return
        }

        guard let type = json["type"] as? String else {
            reportFailure("Server message missing type.")
            return
        }
        
        switch type {
        case "response.output_audio.delta":
            if let delta = json["delta"] as? String { handleIncomingAudio(delta) }
        case "response.output_audio_transcript.delta":
            if let delta = json["delta"] as? String { currentOutput += delta }
        case "input_audio_buffer.speech_started": 
            commitAudioBuffer()
            if !currentOutput.isEmpty {
                responses.insert(currentOutput, at: 0)
            }
            currentOutput = ""
            state = .listening
        case "response.done": 
            if !currentOutput.isEmpty {
                responses.insert(currentOutput, at: 0)
                currentOutput = ""
            }
            state = .listening
        case "error":
            if let msg = json["message"] as? String {
                reportFailure(msg)
            }
        case "ping":
            // Pings are expected, just acknowledge in debug
            debugLogs.insert("Pong", at: 0)
        case "session.created":
            debugLogs.insert("Session created", at: 0)
        case "session_updated":
            debugLogs.insert("Session updated", at: 0)
        case "response.audio_transcript.done":
            // Full transcript complete
            if let transcript = json["transcript"] as? String {
                if !currentOutput.isEmpty {
                    responses.insert(currentOutput, at: 0)
                }
                currentOutput = transcript
            }
        case "response.created":
            debugLogs.insert("Response created - processing", at: 0)
            state = .processing
        case "response.content.done":
            // Response content complete
            state = .listening
        case "conversation.item.created":
            debugLogs.insert("Input audio processed", at: 0)
        default: 
            debugLogs.insert("Unknown type: \(type)", at: 0)
        }
    }
    
    private func handleIncomingAudio(_ base64Audio: String) {
        state = .speaking
        isPlaying = true

        guard let audioData = Data(base64Encoded: base64Audio), !audioData.isEmpty else {
            isPlaying = false
            reportFailure("Received invalid output audio data.")
            return
        }

        let frameCount = audioData.count / 2
        guard frameCount > 0 else {
            isPlaying = false
            reportFailure("Received empty output audio frame.")
            return
        }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1) else {
            isPlaying = false
            reportFailure("Unable to create output audio format.")
            return
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            isPlaying = false
            reportFailure("Unable to allocate output audio buffer.")
            return
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let floatData = buffer.floatChannelData?[0] else {
            isPlaying = false
            reportFailure("Unable to access output audio channel data.")
            return
        }

        var conversionSucceeded = false
        audioData.withUnsafeBytes { raw in
            guard let int16Ptr = raw.baseAddress?.assumingMemoryBound(to: Int16.self) else {
                return
            }
            conversionSucceeded = true
            for i in 0..<Int(buffer.frameLength) {
                floatData[i] = Float(int16Ptr[i]) / 32768.0
            }
        }

        guard conversionSucceeded else {
            isPlaying = false
            reportFailure("Unable to decode output audio samples.")
            return
        }

        playAudioBuffer(buffer)
    }
    
    private func playAudioBuffer(_ buf: AVAudioPCMBuffer) {
        do {
            if audioEngine == nil { try setupAudioPlayer() }
            guard let p = audioPlayer, let e = audioEngine else {
                reportFailure("Audio player is not ready.")
                return
            }
            
            p.scheduleBuffer(buf, at: nil, options: []) { [weak self] in
                Task { @MainActor in
                    self?.isPlaying = false
                    if self?.state == .speaking { self?.state = .listening }
                }
            }
            if !e.isRunning { try e.start() }
        } catch {
            reportFailure("PlayBuffer error: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioPlayer() throws {
        audioEngine = AVAudioEngine()
        audioPlayer = AVAudioPlayerNode()
        guard let e = audioEngine, let p = audioPlayer else {
            throw GrokVoiceError.audioSetupFailed("Engine or player nil")
        }

        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1) else {
            throw GrokVoiceError.audioSetupFailed("Unable to create playback audio format")
        }

        e.attach(p)
        e.connect(p, to: e.mainMixerNode, format: fmt)
        try e.start()
    }
    
    private func startAudioCapture() async throws {
        guard await requestPermission(.microphone) else {
            throw GrokVoiceError.audioSetupFailed("Microphone permission not granted")
        }

        let sess = AVAudioSession.sharedInstance()
        try sess.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try sess.setActive(true)
        
        audioEngine = AVAudioEngine()
        guard let eng = audioEngine else {
            throw GrokVoiceError.audioSetupFailed("Could not create audio engine")
        }
        
        let input = eng.inputNode
        let fmt = input.outputFormat(forBus: 0)

        if isInputTapInstalled {
            input.removeTap(onBus: 0)
            isInputTapInstalled = false
        }
        
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt, block: makeInputTapHandler())
        isInputTapInstalled = true
        
        try eng.start()
        debugLogs.insert("Mic started", at: 0)
    }
    
    private var inputBufferCommitNeeded = false
    
    private func processInputAudioMessage(_ message: String) {
        guard state != .disconnected else {
            return
        }

        if case .error = state {
            return
        }

        sendMessage(message)
        inputBufferCommitNeeded = true
    }
    
    private func commitAudioBuffer() {
        guard inputBufferCommitNeeded else { return }
        inputBufferCommitNeeded = false
        
        // Commit the audio buffer
        let commitMsg: [String: Any] = ["type": "input_audio_buffer.commit"]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: commitMsg),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        sendMessage(jsonString)
        debugLogs.insert("Audio buffer committed", at: 0)
        
        // Request a response
        requestResponse()
    }
    
    private func requestResponse() {
        let responseMsg: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": ["audio", "text"]
            ]
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: responseMsg),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        sendMessage(jsonString)
        debugLogs.insert("Response requested", at: 0)
    }

    nonisolated private func makeInputTapHandler() -> AVAudioNodeTapBlock {
        { [weak self] buf, _ in
            guard let message = Self.makeInputAudioMessage(from: buf) else {
                Task { @MainActor [weak self] in
                    self?.reportFailure("Failed to encode microphone input audio.")
                }
                return
            }

            Task { @MainActor [weak self] in
                self?.processInputAudioMessage(message)
            }
        }
    }

    nonisolated private static func makeInputAudioMessage(from buf: AVAudioPCMBuffer) -> String? {
        
        guard let ch = buf.floatChannelData?[0] else {
            return nil
        }

        var data = Data()
        for i in 0..<Int(buf.frameLength) {
            var s = Int16(ch[i] * 32767).littleEndian
            data.append(Data(bytes: &s, count: 2))
        }
        let b64 = data.base64EncodedString()
        let msg: [String: Any] = ["type": "input_audio_buffer.append", "audio": b64]

        guard let jd = try? JSONSerialization.data(withJSONObject: msg),
              let js = String(data: jd, encoding: .utf8) else {
            return nil
        }

        return js
    }
    
    private func stopAudioCapture() {
        if let engine = audioEngine, isInputTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isInputTapInstalled = false
        }
        audioEngine?.stop()
        audioEngine = nil
    }
    
    func clearLogs() { debugLogs.removeAll() }
    func clearOutput() { currentOutput = "" }
}

