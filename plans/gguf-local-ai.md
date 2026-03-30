# Update Local AI Tab to Use GGUF Models

## Overview

Replace Apple Foundation models with GGUF models in the Local AI tab. GGUF models provide much better quality and are the standard for local LLM inference.

## ☐ Phase 1: Research & Understand Current Implementation

- [ ] 1.1 Find existing LocalAITabView implementation
- [ ] 1.2 Understand how models are currently loaded
- [ ] 1.3 Check if GGUF support already exists (llama.cpp)
- [ ] 1.4 Find where Apple Foundation models are used

## ☐ Phase 2: Architecture

### Components to Modify/Add:
1. **GGUF Model Loader** - Load GGUF model files
2. **LLM Inference Service** - Use llama.cpp for inference
3. **Update LocalAITabView** - Switch to GGUF models
4. **Model Management** - Download/select GGUF models

### Key Changes:
- Remove Apple Foundation model references
- Add GGUF model loading (using llama.cpp)
- Update chat/AI interface to use new backend

## ☐ Phase 3: Implementation

### Step 3.1: Remove Apple Foundation Models
- [ ] Find all references to Apple ML models
- [ ] Remove or disable Apple Foundation model code

### Step 3.2: Implement GGUF Support
- [ ] Use existing llama.cpp framework (already in project)
- [ ] Create GGUF model loader service
- [ ] Implement chat/inference with GGUF

### Step 3.3: Update UI
- [ ] Update LocalAITabView to use GGUF backend
- [ ] Add model selection UI (if multiple models)
- [ ] Show GGUF model info (name, size, etc.)

## ☐ Phase 4: Testing

- [ ] Test GGUF model loads correctly
- [ ] Test chat/inference works
- [ ] Test response quality

---

## Notes

- **Why GGUF?** 
  - Apple Foundation models (like FoundationKit) are low quality
  - GGUF is the standard format for local LLM inference
  - Much better response quality
  - Support for larger, more capable models

- **Existing llama.cpp**: The project already has llama.cpp framework included - use it!

- **Model Sources**: 
  - HuggingFace (e.g., Mistral, Llama, Phi variants in GGUF format)
  - TheBloke's GGUF models on HuggingFace

## App-Wide Development Guidelines

Before implementing ANY feature changes:

1. **Study existing code style** - Look at "moon style" (the app's existing design patterns)
2. **Use confirmed APIs** - Only use iOS/Swift APIs that you can verify exist in the codebase
3. **Match conventions** - Follow the same patterns used in existing files (naming, structure, imports)
4. **Check dependencies** - Ensure any framework you need is already imported in the project