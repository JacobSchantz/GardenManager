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

@MainActor
class GrokVoiceService: NSObject, ObservableObject {
    @Published var state: GrokVoiceState = .disconnected
    @Published var currentOutput: String = ""
    @Published var debugLogs: [String] = []
    @Published var isPlaying = false
    @Published var errorMessage: String? = nil
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var apiKey: String = ""
    
    let voices = ["Ara", "Rex", "Sal", "Eve", "Leo"]
    @Published var selectedVoice = "Ara"
    @Published var systemInstructions = "You are a helpful assistant."
    
    override init() {
        super.init()
        loadAPIKey()
    }
    
    private func loadAPIKey() {
        apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? ""
        if apiKey.isEmpty {
            debugLogs.append("API key not found")
        } else {
            debugLogs.append("API key loaded")
        }
    }
    
    func setAPIKey(_ key: String) { apiKey = key }
    
    func connect() async throws {
        guard !apiKey.isEmpty else {
            let err = GrokVoiceError.apiKeyMissing
            state = .error(err.localizedDescription)
            errorMessage = err.localizedDescription
            throw err
        }
        
        state = .connecting
        errorMessage = nil
        debugLogs.append("Connecting...")
        
        guard let url = URL(string: "wss://api.x.ai/v1/realtime") else {
            throw GrokVoiceError.websocketError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        debugLogs.append("WebSocket created, sending config...")
        
        let sessionConfig: [String: Any] = [
            "type": "session.update",
            "session": ["voice": selectedVoice, "instructions": systemInstructions]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: sessionConfig),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            sendMessage(jsonString)
        }
        
        state = .listening
        debugLogs.append("Ready")
        
        receiveMessage()
        
        Task {
            do { try await startAudioCapture() }
            catch { debugLogs.append("Mic error: \(error.localizedDescription)") }
        }
    }
    
    func disconnect() {
        debugLogs.append("Disconnecting...")
        stopAudioCapture()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        state = .disconnected
    }
    
    func sendMessage(_ message: String) {
        guard let task = webSocketTask else { return }
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        task.send(wsMessage) { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.debugLogs.append("Send error: \(error.localizedDescription)")
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
                case .success(let msg):
                    self.handleMessage(msg)
                    self.receiveMessage()
                case .failure(let error):
                    self.debugLogs.append("RX error: \(error.localizedDescription)")
                    self.errorMessage = "Connection error: \(error.localizedDescription)"
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let jsonString: String
        switch message {
        case .string(let t): jsonString = t
        case .data(let d): jsonString = String(data: d, encoding: .utf8) ?? ""
        @unknown default: return
        }
        
        debugLogs.append("RX: \(jsonString.prefix(60))...")
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        switch type {
        case "response.output_audio.delta":
            if let delta = json["delta"] as? String { handleIncomingAudio(delta) }
        case "response.output_audio_transcript.delta":
            if let delta = json["delta"] as? String { currentOutput += delta }
        case "input_audio_buffer.speech_started": state = .listening
        case "response.done": state = .listening
        case "error":
            if let msg = json["message"] as? String {
                errorMessage = msg
                state = .error(msg)
            }
        default: break
        }
    }
    
    private func handleIncomingAudio(_ base64Audio: String) {
        state = .speaking
        isPlaying = true
        
        guard var audioData = Data(base64Encoded: base64Audio) else { return }
        
        do {
            let fmt = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(audioData.count / 2))!
            buf.frameLength = AVAudioFrameCount(audioData.count / 2)
            
            audioData.withUnsafeMutableBytes { raw in
                if let base = raw.baseAddress {
                    let fbuf = base.assumingMemoryBound(to: Int16.self)
                    let fptr = buf.floatChannelData![0]
                    for i in 0..<Int(buf.frameLength) { fptr[i] = Float(fbuf[i]) / 32768.0 }
                }
            }
            playAudioBuffer(buf)
        } catch {
            debugLogs.append("Play error: \(error.localizedDescription)")
        }
    }
    
    private func playAudioBuffer(_ buf: AVAudioPCMBuffer) {
        if audioEngine == nil { setupAudioPlayer() }
        guard let p = audioPlayer, let e = audioEngine else { return }
        
        p.scheduleBuffer(buf, at: nil, options: []) { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
                if self?.state == .speaking { self?.state = .listening }
            }
        }
        if !e.isRunning { try? e.start() }
    }
    
    private func setupAudioPlayer() {
        audioEngine = AVAudioEngine()
        audioPlayer = AVAudioPlayerNode()
        guard let e = audioEngine, let p = audioPlayer else { return }
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
        e.attach(p)
        e.connect(p, to: e.mainMixerNode, format: fmt)
        try? e.start()
    }
    
    private func startAudioCapture() async throws {
        let sess = AVAudioSession.sharedInstance()
        try sess.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try sess.setActive(true)
        
        audioEngine = AVAudioEngine()
        guard let eng = audioEngine else { return }
        
        let input = eng.inputNode
        let fmt = input.outputFormat(forBus: 0)
        
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            Task { @MainActor in self?.processInputAudio(buf) }
        }
        
        try eng.start()
        debugLogs.append("Mic started")
    }
    
    private func processInputAudio(_ buf: AVAudioPCMBuffer) {
        guard let ch = buf.floatChannelData?[0] else { return }
        var data = Data()
        for i in 0..<Int(buf.frameLength) {
            var s = Int16(ch[i] * 32767).littleEndian
            data.append(Data(bytes: &s, count: 2))
        }
        let b64 = data.base64EncodedString()
        let msg: [String: Any] = ["type": "input_audio_buffer.append", "audio": b64]
        if let jd = try? JSONSerialization.data(withJSONObject: msg),
           let js = String(data: jd, encoding: .utf8) { sendMessage(js) }
    }
    
    private func stopAudioCapture() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }
    
    func clearLogs() { debugLogs.removeAll() }
    func clearOutput() { currentOutput = "" }
}

extension GrokVoiceService: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ s: URLSession, w: URLSessionWebSocketTask, didOpenWithProtocol p: String?) {
        Task { @MainActor in self.debugLogs.append("WS opened") }
    }
    nonisolated func urlSession(_ s: URLSession, w: URLSessionWebSocketTask, didCloseWith code: URLSessionWebSocketTask.CloseCode, r: Data?) {
        Task { @MainActor in
            self.debugLogs.append("WS closed: \(code)")
            self.state = .disconnected
        }
    }
}
