# GardenManager Project Memories

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
