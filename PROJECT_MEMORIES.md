# GardenManager Project Memories

## Local AI Models (Self-Contained)

**Goal:** Run vision-language models entirely on-device in the iOS app, no external API calls.

### Current Options:
1. **FastVLM** - Already integrated, uses CoreML (.mlpackage)
2. **ResNet-50** - CoreML, works for image classification
3. **GGUF Models** - LLaMA.cpp format, in progress

### GGUF Integration Plan

**Step 1: Fix Package Dependencies**
- [x] Add SwiftLlama (llama.cpp Swift wrapper) package reference
- [x] Remove MLX dependencies causing build failures (temporarily disabled FastVLM)
- [x] Get successful build ✅

**Step 2: Add GGUF Model to App Bundle**
- [x] Create `GardenManager/Models/` folder
- [x] Add GGUF file to bundle (LFM2.5-VL-1.6B-Q4_0.gguf - 664MB)
- [x] Update project.yml to include model in Copy Bundle Resources ✅

**Step 3: Implement SwiftLlama Integration**
- [x] Add `import SwiftLlama` to AITabView.swift
- [ ] Fix `analyzeWithGGUFModel()` function to properly use LlamaService
- [ ] Handle image input for vision models

**Step 4: Testing**
- [x] Build for simulator ✅
- [ ] Test with actual GGUF model files
- [ ] Verify no network calls during inference

### Model Location Options
1. **Bundle with app** - ~700MB, increases app size
2. **Download on first launch** - User downloads from server once
3. **iTunes File Sharing** - User manually adds files via Finder

### Models Downloaded
- `~/.cache/huggingface/models/LFM2.5-1.2B/LFM2.5-1.2B-Instruct-Q4_K_M.gguf` (697MB)
- `~/.cache/huggingface/models/LFM2.5-VL-1.6B/LFM2.5-VL-1.6B-Q4_0.gguf` (664MB)
- `~/.cache/huggingface/models/LFM2.5-VL-1.6B/mmproj-LFM2.5-VL-1.6b-Q8_0.gguf` (556MB)

### References
- SwiftLlama: https://github.com/pgorzelany/swift-llama-cpp
- MLX Swift: https://github.com/ml-explore/mlx-swift (for future VLM support)
- LFM Models: https://huggingface.co/LiquidAI

## GitHub Listener

The `github-listener/` folder contains the webhook listener that auto-builds iOS apps when you push to specific repos.

### Repos and Branches Configured:
- **atg_monorepo** (branch: `Peaches`) → builds ATG iOS
- **keepMovin** → builds KeepMovin iOS
- **BuyAHabit / buyahabit** → builds BuyAHabit iOS
- **GardenManager** → builds GardenManager iOS

### Important
- **Always push listener changes** to GardenManager repo after modifying `github-listener/server.js`
- The listener runs locally from `~/.openclaw/workspace/GardenManager/github-listener/`
- Android builds are currently disabled (commented out)

### Running the Listener
```bash
cd ~/.openclaw/workspace/GardenManager/github-listener
node server.js
```

### Ngrok
The listener is accessible via ngrok on port 8765. Webhook URL needs to be updated in GitHub repo settings.
