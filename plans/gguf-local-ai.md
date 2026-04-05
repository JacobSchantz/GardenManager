# Update Local AI Tab to Use GGUF Models (Multimodal)

## Overview

**REJECTED: Apple Vision Framework** — explicitly ruled out. Not smart enough for useful image understanding in chat.

Replace Apple Foundation models with GGUF models in the Local AI tab. **Must support vision (image + text) in chat.**

The current `swift-llama-cpp` package does NOT expose vision APIs. We need to switch to a package or approach that supports multimodal GGUF models.

## ☐ Phase 1: Research & Understand Current Implementation

- [ ] 1.1 Find existing LocalAITabView implementation
- [ ] 1.2 Understand how models are currently loaded
- [ ] 1.3 Check if GGUF support already exists (llama.cpp)
- [ ] 1.4 Find where Apple Foundation models are used

## ☐ Phase 2: Research & Vision Support Options

### Current Problem: swift-llama-cpp lacks vision APIs
- `SwiftLlama` is in `project.yml` and compiles
- BUT it has no image/vision methods exposed
- `llama.cpp` has `LLAMA_ROPE_TYPE_VISION` internally but Swift wrapper doesn't expose it

### Option A: MLC-LLM (Recommended for Vision)
- Native multimodal support built-in
- Supports Llava, CogVLM vision models in GGUF format
- Works with llama.cpp-backed GGUF
- Requires: `mlc-llm` package or compile llama.cpp with MLC
- See: https://github.com/mlc-ai/mlc-llm

### Option B: LocalAI REST API (Local Server)
- Local server (runs on Mac) handles vision
- Swift app sends images via HTTP
- Simpler Swift side, local server setup required
- Vision model runs locally on Mac GPU/CPU

### Option C: Dedicated Vision Model
- Run a separate vision model (CLIP, SigLIP, etc.) to encode images
- Feed encoded features to Llama as special tokens
- More engineering but avoids MLC complexity
- REST API server (runs locally) that handles vision
- Swift app sends images via HTTP
- Simpler Swift side, more complex local server setup



### Option D: Fork/update swift-llama-cpp
- Add Swift bindings for llama.cpp vision APIs
- Significant engineering effort

### Recommended: Option A (MLC-LLM) — true multimodal GGUF support

- If you want true native multimodal GGUF → MLC-LLM

## ☐ Phase 3: Implementation

### Step 3.1: Remove Apple Foundation Models
- [ ] Find all references to Apple ML models
- [ ] Remove or disable Apple Foundation model code

### Step 3.2: Implement Vision Support
- [ ] Implement chosen vision approach (Option A, B, or C)
- [ ] Add image encoding/preprocessing
- [ ] Pass image data to GGUF model alongside text
- [ ] Handle multimodal prompt construction

### Step 3.3: Implement GGUF Text Chat
- [ ] Create GGUF model loader service
- [ ] Implement chat/inference with GGUF

### Step 3.3: Update UI
- [ ] Update LocalAITabView to use GGUF backend
- [ ] Add model selection UI (if multiple models)
- [ ] Show GGUF model info (name, size, etc.)

## ☐ Phase 4: Testing

### GGUF Fixture Setup
GGUF files are large (500MB - 30GB). Store test fixtures outside repo:
```
~/.openclaw/workspace/GardenManager/test_fixtures/
├── tinyllama-1.1b.Q4_K_M.gguf     # ~70MB, text-only, fast CI
├── llava-1.6-mistral-7b.Q4_K_M.gguf  # ~4GB, multimodal vision support
└── README.md                          # where to download fixtures
```
Download script (run before tests):
```bash
# Text model
curl -L -o test_fixtures/tinyllama-1.1b.Q4_K_M.gguf \
  "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
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
  - Apple Foundation models (like FoundationKit) are low quality
  - GGUF is the standard format for local LLM inference
  - Much better response quality
  - Support for larger, more capable models

- **Vision/Multimodal**: Current `swift-llama-cpp` does NOT support vision. Must switch to MLC-LLM, LocalAI, or a dedicated vision encoder.
- **REJECTED: Apple Vision Framework** — not smart enough for useful image understanding in chat.

- **MLC-LLM** is the recommended path for true multimodal GGUF. See: https://github.com/mlc-ai/mlc-llm



- **Model Sources**: 
  - HuggingFace (e.g., Mistral, Llama, Phi variants in GGUF format)
  - TheBloke's GGUF models on HuggingFace

## App-Wide Development Guidelines

Before implementing ANY feature changes:

1. **Study existing code style** - Look at "moon style" (the app's existing design patterns)
2. **Use confirmed APIs** - Only use iOS/Swift APIs that you can verify exist in the codebase
3. **Match conventions** - Follow the same patterns used in existing files (naming, structure, imports)
4. **Check dependencies** - Ensure any framework you need is already imported in the project