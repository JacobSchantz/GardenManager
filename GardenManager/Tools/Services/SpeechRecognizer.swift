import Speech
import AVFoundation

class SpeechRecognizer: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var transcript = ""
    @Published var isListening = false
    @Published var errorMessage: String?
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    
    override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        recognizer?.delegate = self
    }
    
    func startListening() {
        stopListening()
       
        
    }
    
    private func startRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session failed"
            return
        }
        
        audioEngine = AVAudioEngine()
        request = SFSpeechAudioBufferRecognitionRequest()
        
        guard let audioEngine = audioEngine,
              let request = request,
              let recognizer = recognizer else {
            errorMessage = "Setup failed"
            return
        }
        
        request.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Engine start failed"
            return
        }
        
        isListening = true
        transcript = ""
        
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
//                if let result = result {
//                    self?.transcript = result.bestTranscription.formattedString
//                }
//                if error != nil || result?.isFinal == true {
//                    self?.stopListening()
//                }
            }
        }
    }
    
    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        request?.endAudio()
        request = nil
        
        task?.cancel()
        task = nil
        
        isListening = false
    }
}
