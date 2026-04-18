# OpenClaw Web UI Tab — Implementation Plan

## Overview
Add a tab to GardenManager that embeds OpenClaw's Control UI via WKWebView, giving real-time visibility into agent sessions, tool output, memory, and agent status without switching apps.

## Motivation
- Peanut (Manager agent) sometimes goes dark during long subagent tasks
- User can't see what the agent is actively working on
- Telegram chat is text-only; the Control UI shows sessions, tool bubbles, memory, and live agent state
- Real-time window into Foreman's work without leaving GardenManager

## Target Users
- Yacs Man (owner) — primary user
- Observability without trusting memory of what the agent "might be doing"

## ☐ Phase 1: Research & Setup

- [ ] 1.1 Explore existing GardenManager tab structure
  - [ ] 1.1.1 Find how tabs are defined (TabView, NavigationStack, etc.)
  - [ ] 1.1.2 Identify the tab bar or navigation layout
  - [ ] 1.1.3 Note existing tab names and icons
- [ ] 1.2 Confirm OpenClaw Control UI URL
  - [ ] 1.2.1 OpenClaw gateway runs at `http://127.0.0.1:18789`
  - [ ] 1.2.2 Test access from the app's network context (sandboxed vs localhost exceptions)
- [ ] 1.3 Check for existing WKWebView usage in GardenManager
  - [ ] 1.3.1 See if any tab already uses WebKit/URL loading
  - [ ] 1.3.2 Note any existing SPM/WebKit dependencies

## ☐ Phase 2: Minimal WebView Tab

- [ ] 2.1 Create new `OpenClawWebView.swift` file
  - [ ] 2.1.1 SwiftUI view with `WKWebView` via `UIViewRepresentable`
  - [ ] 2.1.2 Load `http://127.0.0.1:18789` on appear
  - [ ] 2.1.3 Basic navigation (back/forward/refresh buttons)
- [ ] 2.2 Add tab to main TabView
  - [ ] 2.2.1 Use icon like `globe` or `desktopcomputer`
  - [ ] 2.2.2 Label: "OpenClaw" or "Control"
  - [ ] 2.2.3 Position: probably last tab
- [ ] 2.3 Handle URL request permissions
  - [ ] 2.3.1 Add `localhost` exception if iOS blocks it
  - [ ] 2.3.2 Use `URLRequest` with proper headers if gateway needs auth token
- [ ] 2.4 Test on device (Jake's iPhone)
  - [ ] 2.4.1 Verify page loads and renders
  - [ ] 2.4.2 Check for JS/websocket errors in console

## ☐ Phase 3: UX Improvements

- [ ] 3.1 Add refresh button to toolbar
- [ ] 3.2 Show loading indicator while page loads
- [ ] 3.3 Handle "gateway unreachable" error state gracefully
- [ ] 3.4 Add a "Open in Safari" fallback button for external links
- [ ] 3.5 Support navigation between tabs (Sessions, Memory, etc.)

## ☐ Phase 4: Polish

- [ ] 4.1 Test on both iPhone and iPad layouts
- [ ] 4.2 Verify auth token is not exposed in logs or UI
- [ ] 4.3 Update `PROJECT_MEMORIES.md` with the new feature
- [ ] 4.4 Test on macOS (if GardenManager has macOS target)

## Technical Notes

### URL Auth
OpenClaw gateway at `127.0.0.1:18789` uses an auth token. Check:
```swift
// In AppDelegate or scene setup, retrieve gateway token:
// let token = UserDefaults.standard.string(forKey: "gatewayAuthToken")
// Then load URL with header: Authorization: Bearer <token>
```

### WKWebView Requirements
```swift
import WebKit
struct OpenClawWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }
    func updateUIView(_ webView: WKWebView, context: Context) {
        let url = URL(string: "http://127.0.0.1:18789")!
        let request = URLRequest(url: url)
        webView.load(request)
    }
}
```

### Localhost on iOS
iOS sandbox blocks `127.0.0.1` from app unless:
1. App uses `NSAppTransportSecurity` exceptions (deprecated but may still work)
2. Use `localhost` instead of `127.0.0.1`
3. Or use `http://Peanuts-Mac-mini.local:18789` over LAN (if Tailscale/gateway expose externally)

### Better Alternative: DesktopWebView
If iOS blocks localhost, use `openclaw web` CLI command that opens the dashboard in the system browser — this avoids WKWebView entirely and just launches Safari with the correct URL.

## Status
**Proposed** — not yet started

## Related
- GardenManager app at `~/.openclaw/workspace/GardenManager/`
- OpenClaw gateway at `http://127.0.0.1:18789`
