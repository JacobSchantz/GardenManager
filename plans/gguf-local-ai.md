# Update Local AI Tab to Use GGUF Models (Multimodal)

## Overview

**REJECTED: Apple Vision Framework** — explicitly ruled out. Not smart enough for useful image understanding in chat.

**REJECTED: Option B (LocalAI REST API)** — requires an external server. App must be fully self-contained with no local server dependency.

Replace Apple Foundation models with GGUF models in the Local AI tab. **Must support vision (image + text) in chat. Everything must run on-device within the app.**

## ☐ Phase 1: Research & Understand Current Implementation

- [ ] 1.1 Find existing LocalAITabView implementation
- [ ] 1.2 Understand how models are currently loaded
- [ ] 1.3 Check if GGUF support already exists (llama.cpp)
- [ ] 1.4 Find where Apple Foundation models are used

## ☐ Phase 2: Research & Vision Support Options

### Current Problem: swift-llama-cpp lacks vision APIs
- `SwiftLlama` is in `project.yml` and compiles
- BUT it has no image/vision methods exposed
- `llama.cpp` has vision support internally but Swift wrapper doesn't expose it

### Option A: MLC-LLM (REQUIRED — runs entirely on-device)
- Native multimodal support built-in
- Supports Llava, CogVLM vision models in GGUF format
- Works with llama.cpp-backed GGUF
- Runs fully on-device — NO external server required
- Can be embedded as a Swift package or compiled as a library
- See: https://github.com/mlc-ai/mlc-llm
- See: https://llava.mlc.ai (iOS deployment guide)

### Option B: LocalAI REST API (REJECTED)
- Requires a separate LocalAI server running on the Mac
- This is an external dependency — NOT acceptable
- App must be self-contained

### Option C: Dedicated Vision Model (REJECTED)
- Would still require either MLC-LLM or LocalAI
- More complex than Option A

### Option D: Fork/update swift-llama-cpp (REJECTED)
- Too much engineering effort

### SELECTED: Option A (MLC-LLM) — true on-device multimodal GGUF

## ☐ Phase 3: Implementation

### Step 3.1: Remove Apple Foundation Models
- [ ] Find all references to Apple ML models (Vision, CoreML, FoundationModels)
- [ ] Remove or disable Apple Foundation model code

### Step 3.2: Integrate MLC-LLM
- [ ] Add MLC-LLM Swift package or compile MLC-LLM as a static library
- [ ] Create Swift bindings for MLC-LLM's vision-capable GGUF inference
- [ ] Support loading vision GGUF models (llava, bakllava, moondream, etc.)
- [ ] Handle multimodal prompt construction (image tokens + text)

### Step 3.3: Implement On-Device Vision Chat
- [ ] Create MLCClient.swift wrapping MLC-LLM for Swift
- [ ] Add image encoding/preprocessing for GGUF vision models
- [ ] Pass image data to GGUF model alongside text
- [ ] Handle streaming text output
- [ ] Proper memory management between inference sessions

### Step 3.4: Implement GGUF Text Chat
- [ ] Reuse existing SwiftLlama for text-only models
- [ ] Create unified GGUF model loader service
- [ ] Implement chat/inference with GGUF

### Step 3.5: Update UI
- [ ] Update LocalAITabView to use GGUF backend
- [ ] Add model selection UI (text-only GGUF vs vision GGUF)
- [ ] Show GGUF model info (name, size, quantization)
- [ ] Update composer to support image attachment
- [ ] Remove Apple Foundation model references

## ⏱ Phase 4: Testing

### GGUF Fixture Setup
GGUF files are large (500MB - 30GB). Store test fixtures outside repo:
```
~/.openclaw/workspace/GardenManager/test_fixtures/
├── tinyllama-1.1b.Q4_K_M.gguf          # ~70MB, text-only, fast CI
├── llava-1.6-mistral-7b.Q4_K_M.gguf    # ~4GB, multimodal vision support
└── README.md                            # where to download fixtures
```
Download script (run before tests):
```bash
# Text model
curl -L -o test_fixtures/tinyllama-1.1b.Q4_K_M.gguf \
  "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1b-chat-v1.0.Q4_K_M.gguf"
# Vision model
curl -L -o test_fixtures/llava-1.6-mistral-7b.Q4_K_M.gguf \
  "https://huggingface.co/cjpais/llava-1.6-mistral-7b-GGUF/resolve/main/llava-v1.6-mistral-7b.Q4_K_M.gguf"
```

### Unit Tests
- `GGUFModelLoaderTests.swift`
  - [ ] Can load a valid GGUF file and return metadata
  - [ ] Loading non-existent file returns error
  - [ ] Loading corrupt GGUF returns appropriate error
  - [ ] Model quantization level is correctly detected

### Integration Tests
- `GGUFInferenceTests.swift`
  - [ ] Can initialize inference with GGUF file
  - [ ] Can run inference and get a text response
  - [ ] Inference handles empty prompt gracefully
  - [ ] Inference can be cancelled mid-generation
  - [ ] Memory is freed after inference session ends

### Multimodal/Vision Tests
- `GGUFMultimodalTests.swift`
  - [ ] Can load a vision-capable GGUF model
  - [ ] Can encode an image and pass to GGUF alongside text
  - [ ] Can receive a response to an image+text prompt
  - [ ] Image-only prompt returns appropriate response
  - [ ] Text-only prompt still works after image test

### Chat Regression Tests
- `ChatCrashRegressionTests.swift`
  - [ ] Send image → app does not crash
  - [ ] Receive image → app does not crash
  - [ ] Rapid image sends (3 images in 1 second) does not crash
  - [ ] Send image while receiving another → no crash
  - [ ] Image is displayed in chat alongside text response

---

## Notes

- **Why GGUF?**
  - Apple Foundation models are low quality
  - GGUF is the standard format for local LLM inference
  - Much better response quality
  - Support for larger, more capable models

- **Vision/Multimodal**: Current `swift-llama-cpp` does NOT support vision. Must switch to MLC-LLM (on-device, no external server).

- **Self-Contained Requirement**: The app must run entirely on-device. No LocalAI server, no cloud dependency. MLC-LLM is the only viable path.

- **MLC-LLM** is the recommended path for true multimodal GGUF. See: https://github.com/mlc-ai/mlc-llm and https://llava.mlc.ai

- **Model Sources**:
  - HuggingFace (e.g., Mistral, Llama, Phi variants in GGUF format)
  - TheBloke's GGUF models on HuggingFace
  - Llava GGUF variants on HuggingFace

## App-Wide Development Guidelines

Before implementing ANY feature changes:

1. **Study existing code style** - Look at "moon style" (the app's existing design patterns)
2. **Use confirmed APIs** - Only use iOS/Swift APIs that you can verify exist in the codebase
3. **Match conventions** - Follow the same patterns used in existing files (naming, structure, imports)
4. **Check dependencies** - Ensure any framework you need is already imported in the project
