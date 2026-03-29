import Foundation
import AVFoundation
import Speech
import Combine

enum OpenClawVoiceError: Error, LocalizedError {
    case notConnected
    case audioSetupFailed(String)
    case telegramError(String)
    case apiKeyMissing
    
    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected"
        case .audioSetupFailed(let msg): return "Audio: \(msg)"
        case .telegramError(let msg): return "Telegram: \(msg)"
        case .apiKeyMissing: return "API key missing"
        }
    }
}

enum OpenClawVoiceState: Equatable {
    case disconnected
    case connecting
    case listening
    case processing
    case speaking
    case error(String)
}

enum OpenClawPermissionStatus: Equatable {
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

@MainActor
class OpenClawVoiceService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var state: OpenClawVoiceState = .disconnected
    @Published var transcribedText: String = ""
    @Published var responseText: String = ""
    @Published var debugLogs: [String] = []
    @Published var isPlaying = false
    @Published var errorMessage: String? = nil
    @Published private(set) var microphonePermissionStatus: OpenClawPermissionStatus = .unknown
    
    // Telegram configuration
    @Published var telegramBotToken: String = ""
    @Published var telegramChatId: String = ""
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    
    private var lastSentMessage: String = ""
    
    override init() {
        super.init()
        synthesizer.delegate = self
        loadSettings()
        checkPermissions()
    }
    
    private func loadSettings() {
        telegramBotToken = UserDefaults.standard.string(forKey: "openclaw_telegram_token") ?? ""
        telegramChatId = UserDefaults.standard.string(forKey: "openclaw_telegram_chat_id") ?? ""
    }
    
    func saveSettings() {
        UserDefaults.standard.set(telegramBotToken, forKey: "openclaw_telegram_token")
        UserDefaults.standard.set(telegramChatId, forKey: "openclaw_telegram_chat_id")
    }
    
    // MARK: - Permissions
    
    func checkPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        switch speechStatus {
        case .notDetermined:
            microphonePermissionStatus = .notDetermined
        case .denied, .restricted:
            microphonePermissionStatus = .denied
        case .authorized:
            microphonePermissionStatus = .granted
        @unknown default:
            microphonePermissionStatus = .unknown
        }
    }
    
    func requestPermissions() async {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    switch status {
                    case .authorized:
                        self.microphonePermissionStatus = .granted
                    case .denied, .restricted:
                        self.microphonePermissionStatus = .denied
                    default:
                        self.microphonePermissionStatus = .notDetermined
                    }
                    continuation.resume()
                }
            }
        }
        
        AVAudioApplication.requestRecordPermission { granted in
            // Handle microphone permission if needed
        }
    }
    
    // MARK: - Connection
    
    func connect() async throws {
        guard !telegramBotToken.isEmpty else {
            let error = OpenClawVoiceError.apiKeyMissing
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            debugLogs.append("[OpenClaw] Error: \(error.localizedDescription)")
            throw error
        }
        
        state = .connecting
        errorMessage = nil
        debugLogs.append("[OpenClaw] Connecting...")
        
        // Start speech recognition
        do {
            try startSpeechRecognition()
            state = .listening
            debugLogs.append("[OpenClaw] Ready to listen")
        } catch {
            state = .error(error.localizedDescription)
            debugLogs.append("[OpenClaw] Speech error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func disconnect() {
        debugLogs.append("[OpenClaw] Disconnecting...")
        stopSpeechRecognition()
        stopSpeaking()
        state = .disconnected
    }
    
    // MARK: - Speech Recognition (STT)
    
    private func startSpeechRecognition() throws {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw OpenClawVoiceError.audioSetupFailed("Speech recognizer not available")
        }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw OpenClawVoiceError.audioSetupFailed("Unable to create recognition request")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.recognitionRequest?.append(buffer)
            }
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    self.transcribedText = transcription
                    self.debugLogs.append("[OpenClaw] Transcribed: \(transcription)")
                    
                    // If transcription is complete, send to Telegram
                    if result.isFinal {
                        self.sendToTelegram(transcription)
                    }
                }
                
                if let error = error {
                    self.debugLogs.append("[OpenClaw] Recognition error: \(error.localizedDescription)")
                }
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func stopSpeechRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    // MARK: - Telegram Integration
    
    private func sendToTelegram(_ message: String) {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard message != lastSentMessage else { return }
        
        lastSentMessage = message
        state = .processing
        debugLogs.append("[OpenClaw] Sending to Telegram: \(message)")
        
        guard let token = telegramBotToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let chatId = telegramChatId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let messageEncoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        
        let urlString = "https://api.telegram.org/bot\(token)/sendMessage?chat_id=\(chatId)&text=\(messageEncoded)"
        
        guard let url = URL(string: urlString) else { return }
        
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    debugLogs.append("[OpenClaw] Message sent successfully")
                    // Note: For a real implementation, we'd need to set up a webhook 
                    // to receive responses. For now, we'll simulate a response or
                    // wait for user input.
                    // 
                    // To receive responses from Telegram, you would need to:
                    // 1. Set up a webhook endpoint
                    // 2. Have OpenClaw forward Telegram messages to your app
                    // 3. Or poll Telegram for new messages
                    
                    // For demo purposes, let's show a placeholder response
                    await MainActor.run {
                        self.state = .listening
                        self.debugLogs.append("[OpenClaw] Waiting for response...")
                    }
                } else {
                    await MainActor.run {
                        self.debugLogs.append("[OpenClaw] Failed to send message")
                        self.state = .error("Failed to send message")
                    }
                }
            } catch {
                await MainActor.run {
                    self.debugLogs.append("[OpenClaw] Network error: \(error.localizedDescription)")
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Text to Speech (TTS)
    
    func speak(_ text: String) {
        stopSpeaking()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        
        state = .speaking
        isPlaying = true
        responseText = text
        
        synthesizer.speak(utterance)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
            if self.state == .speaking {
                self.state = .listening
            }
        }
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
    }
    
    // MARK: - Utility
    
    func clearLogs() {
        debugLogs.removeAll()
    }
    
    func clearTranscription() {
        transcribedText = ""
        responseText = ""
    }
}