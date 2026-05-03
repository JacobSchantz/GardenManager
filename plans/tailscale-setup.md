# Tailscale Setup — BuyAHabit Remote Builds

## Why
When off home WiFi, `build_local.sh` can't reach the phone to install builds. TestFlight takes 10-15 min. Ad-hoc OTA was painful.

## Solution
Tailscale VPN — Mac mini + phone on same virtual network from anywhere. Same `build_local.sh` / `xcrun devicectl` flow, just works over Tailscale IP.

## Status
- [x] `brew install tailscale` (v1.96.4 installed)
- [ ] `sudo /opt/homebrew/bin/tailscaled install-system-daemon` (needs password in Terminal)
- [ ] `tailscale up` — authenticate (opens browser)
- [ ] Install Tailscale app on iPhone
- [ ] Get Tailscale IP of Mac mini
- [ ] Update listener build script to use Tailscale IP
- [ ] Test off-WiFi build

## Notes
- Tailscale is free for personal use (up to 100 devices)
- Also fixes webhook/ngrok issue — could use Tailscale IP for webhook URL too
- Currently `build_local_or_testflight.sh` falls back to TestFlight when off WiFi; with Tailscale, local build works everywhere
