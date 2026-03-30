# GardenManager Project Memories

## ⚠️ ALWAYS PUSH AFTER MAKING CHANGES

**Rule:** Always pull before making changes, and always push after making changes.

```bash
# Before making any change:
git pull

# After making any change:
git add . && git commit -m "describe change" && git push
```

This prevents merge conflicts when multiple machines or agents work on the same repo. Never leave changes uncommitted.

---

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
1. **iOS Files App (Current)** - User imports from Locally app via Files → Add to Files → Garden Manager Documents
2. **Bundle with app** - Too large for GitHub (664MB > 100MB limit)
3. **Download on first launch** - Future option

### Models Downloaded
- `~/.cache/huggingface/models/LFM2.5-1.2B/LFM2.5-1.2B-Instruct-Q4_K_M.gguf` (697MB)
- `~/.cache/huggingface/models/LFM2.5-VL-1.6B/LFM2.5-VL-1.6B-Q4_0.gguf` (664MB)
- `~/.cache/huggingface/models/LFM2.5-VL-1.6B/mmproj-LFM2.5-VL-1.6b-Q8_0.gguf` (556MB)

### Vision-Language GGUF Models - IMPORTANT

**Current Issue:** SwiftLlama (llama.cpp wrapper) is **text-only** - doesn't support image input.

**Solution:** Need a vision-language GGUF model + mmproj (vision projector)

**Required for vision GGUF:**
1. **Model file (.gguf)** - The LLM with vision capabilities (e.g., LLaVA, BakLLaVA, LFM-VL)
2. **Projector file (mmproj-*.gguf)** - Vision projector that encodes images for the model

**Libraries to explore:**
1. **llama.cpp (native)** - Has vision support via `llava` architecture
   - Need to build llama.cpp with VISION=ON
   - Then create Swift bindings or use via C interop
   
2. **ggml-opt** - Another option with vision support

3. **llava.cpp** - Dedicated vision-language implementation
   - https://github.com/ggerganov/llama.cpp/tree/master/examples/llava
   - Would need Swift bindings

4. **Alternative: Use CoreML** - FastVLM already works, skip GGUF for vision

**Short-term fix:** Use Vision framework to describe image, pass to GGUF (current workaround)
**Long-term:** Find/build Swift library with GGUF vision support

### References
- SwiftLlama: https://github.com/pgorzelany/swift-llama-cpp
- MLX Swift: https://github.com/ml-explore/mlx-swift (for future VLM support)
- LFM Models: https://huggingface.co/LiquidAI

## GitHub Listener

**Source of Truth:** The `github-listener/` directory in the GardenManager repository is the canonical source. All listener code lives here and must be pushed to GitHub after any changes.

The listener auto-builds iOS apps when you push to specific repos.

### Repository Structure
```
GardenManager/
  github-listener/          # ← Source of truth for webhook listener
    server.js               # Main webhook handler
    setup.sh                # Setup script
    package.json
    README.md
```

### Repos and Branches Configured:
- **atg_monorepo** (branch: `Peaches`) → builds ATG iOS
- **keepMovin** → builds KeepMovin iOS
- **buyHabit / buyahabit** → builds BuyAHabit iOS
- **GardenManager** → builds GardenManager iOS

### Workflow
1. Make changes to `github-listener/server.js` or any listener code
2. **Always push changes to GardenManager repo** (`git push origin main`)
3. Pull on any machine running the listener, then restart

### Running the Listener
```bash
cd ~/.openclaw/workspace/GardenManager/github-listener
node server.js
```

### Ngrok
The listener is accessible via ngrok on port 8765. Webhook URL needs to be updated in GitHub repo settings.

### Important
- **Never modify listener code outside of this repo** — changes will be overwritten on next pull
- Android builds are currently disabled (commented out)
