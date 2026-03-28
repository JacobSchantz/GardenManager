# Voice Communication with OpenClaw - Implementation Plan

## Overview

Create a voice conversation feature in Garden Manager that works like a phone call:
- User speaks → Speech converted to text → Sent to OpenClaw (Telegram)
- OpenClaw responds → Text converted to speech → User hears response
- No touching the phone required

## ☐ Phase 1: Research & Understand Existing Code

- [ ] 1.1 Study existing Grok Voice implementation (if any)
- [ ] 1.2 Find existing speech-to-text (STT) code in Garden Manager
- [ ] 1.3 Find existing text-to-speech (TTS) code in Garden Manager
- [ ] 1.4 Understand how to send messages to Telegram via OpenClaw
- [ ] 1.5 Check iOS permissions for microphone access

## ☐ Phase 2: Design the Architecture

### Components Needed:
1. **VoiceConversationScreen** - New screen with:
   - Start/End call button
   - Real-time transcription display (what user is saying)
   - Response display (what OpenClaw responded)
   - Visual feedback (speaking indicator)

2. **SpeechToText Service** - Convert spoken words to text:
   - Use iOS Speech framework (SFSpeechRecognizer)
   - Real-time transcription as user speaks
   - Handle microphone permissions

3. **TextToSpeech Service** - Convert text to speech:
   - Use AVSpeechSynthesizer
   - Configure voice settings (rate, pitch)

4. **OpenClaw Message Service** - Send/receive messages:
   - Send transcribed text to Telegram via OpenClaw
   - Listen for responses from Telegram
   - Route responses to TTS service

## ☐ Phase 3: Implementation Steps

### Step 3.1: Voice Conversation Screen
- [ ] Create new `VoiceConversationView.swift`
- [ ] Add start call button to Garden Manager home
- [ ] UI: Large start button, transcription area, status indicator

### Step 3.2: Speech-to-Text (STT)
- [ ] Create `SpeechToTextService.swift`
- [ ] Request microphone + speech recognition permissions
- [ ] Implement real-time transcription using SFSpeechRecognizer
- [ ] Handle continuous speech recognition
- [ ] Send transcribed text to OpenClaw

### Step 3.3: Text-to-Speech (TTS)
- [ ] Create `TextToSpeechService.swift` (or reuse existing)
- [ ] Configure AVSpeechSynthesizer
- [ ] Add queue management for responses

### Step 3.4: OpenClaw Integration
- [ ] Determine how to send messages to Telegram
- [ ] Options:
  - Use OpenClaw's API if available
  - Use Telegram Bot API directly
  - Use existing OpenClaw session messaging
- [ ] Receive responses and route to TTS

### Step 3.5: Flow Control
- [ ] Start call → Begin STT → User speaks → Text sent
- [ ] Wait for response → Receive text → TTS speaks
- [ ] Continue conversation until user ends call

## ☐ Phase 4: Technical Considerations

### Permissions Needed:
- Microphone (NSMicrophoneUsageDescription)
- Speech Recognition (NSSpeechRecognitionUsageDescription)

### Edge Cases to Handle:
- [ ] No internet connection
- [ ] Speech recognition fails
- [ ] OpenClaw/Telegram unavailable
- [ ] User ends call mid-speech
- [ ] Background audio handling

### UI States:
1. **Idle** - Ready to start call
2. **Listening** - User speaking, converting to text
3. **Processing** - Sending to OpenClaw, waiting for response
4. **Speaking** - Playing back OpenClaw's response
5. **Error** - Something went wrong

## ☐ Phase 5: Testing

- [ ] Test STT accuracy
- [ ] Test TTS quality
- [ ] Test message send/receive
- [ ] Test call start/end flow
- [ ] Test error handling

---

## Technical Notes

### iOS Speech Framework (SFSpeechRecognizer):
```swift
import Speech

let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
let recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
    // Handle transcription result
}
```

### iOS TTS (AVSpeechSynthesizer):
```swift
import AVFoundation

let synthesizer = AVSpeechSynthesizer()
let utterance = AVSpeechUtterance(string: "Hello!")
utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
synthesizer.speak(utterance)
```

### Telegram Bot API (for sending messages):
```
POST https://api.telegram.org/bot<TOKEN>/sendMessage
{
    "chat_id": "<CHAT_ID>",
    "text": "<MESSAGE>"
}
```

## App-Wide Development Guidelines

Before implementing ANY feature changes:

1. **Study existing code style** - Look at "moon style" (the app's existing design patterns)
2. **Use confirmed APIs** - Only use iOS/Swift APIs that you can verify exist in the codebase
3. **Match conventions** - Follow the same patterns used in existing files (naming, structure, imports)
4. **Check dependencies** - Ensure any framework you need is already imported in the project