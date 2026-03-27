# GardenManager Project Memories

## Local AI Models (Self-Contained)

**Goal:** Run vision-language models entirely on-device in the iOS app, no external API calls.

### Current Options:
1. **FastVLM** - Already integrated, uses CoreML (.mlpackage)
2. **ResNet-50** - CoreML, works for image classification
3. **GGUF Models** - LLaMA.cpp format, not yet integrated

### GGUF Integration (In Progress)
- Model format: GGUF (Generic Graph Unified Format) from llama.cpp
- Downloaded to: `~/.cache/huggingface/models/`
- Current models:
  - `LFM2.5-1.2B-Instruct-Q4_K_M.gguf` (text model, 697MB)
  - `LFM2.5-VL-1.6B-Q4_0.gguf` (vision model, 664MB)
  - `mmproj-LFM2.5-VL-1.6b-Q8_0.gguf` (multimodal projector, 556MB)

### Challenges:
- llama.cpp CLI hangs on this Mac (M4) - needs investigation
- Need to integrate llama.cpp into iOS app (Swift wrapper or native)
- GGUF files must be bundled in app or downloaded on first launch

### References:
- swift-llama-cpp (GitHub: pgorzelany/swift-llama-cpp) - Swift wrapper for llama.cpp
- ONNX export also available from LiquidAI but incomplete

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
