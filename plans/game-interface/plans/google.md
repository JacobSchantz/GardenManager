# Garden Interface — Google/Gemini Response

## Executive Summary

Google's Gemini models recommend a **SwiftUI-first, cross-platform-ready** architecture for "Garden Interface," leveraging Apple's ecosystem for maximum polish and the App Store distribution channel, with a clear Godot migration path for Android/Steam.

---

## 1. Recommended Tech Stack

### Primary: SwiftUI + SwiftData + SpriteKit

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| UI | SwiftUI | Native Apple UI, minimal cross-platform ambition for v1 |
| Rendering | SpriteKit | 2D top-down garden scenes, particle effects, performant on iOS |
| State | SwiftData | Modern persistence, native Swift, @Observable support |
| Dialogue | Custom DSL (YAML-backed) | Lightweight, non-blocking, easy to iterate |
| Audio | AVFoundation + ambient audio | Built-in, no third-party deps |
| AI | Apple Intelligence (on-device) | Contextual suggestions, future-proofing |
| AR | ARKit + RealityKit | Optional AR mode overlay on real gardens |
| Build | XcodeGen + SPM | Standard iOS tooling |
| Deployment | App Store | Primary distribution |

### Secondary: Godot 4.x (Android/Steam path)

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Renderer | Godot 4.x (GDScript/C#) | Cross-platform, 2D + 3D capable |
| Dialogue | Dialogue Manager plugin | Popular Godot dialogue system |
| Persistence | Godot Resource system | JSON-based save files |
| Porting cost | 6–12 months post-MVP | After SwiftUI version ships |

### Verdict: Start with SwiftUI. Ship to App Store first. Port to Godot for Android/Steam in year 2.

---

## 2. Architecture

### SwiftUI Version (Primary)

```
GardenInterface/
├── App/
│   ├── GardenInterfaceApp.swift      # App entry, SwiftData container
│   └── AppState.swift               # @Observable global state
├── Core/
│   ├── Models/
│   │   ├── Plant.swift              # Plant entity (name, personality, mood)
│   │   ├── GardenZone.swift         # Garden region with plant set
│   │   ├── Player.swift             # Player state, position, journal
│   │   └── DialogueState.swift      # Per-plant conversation history
│   ├── Systems/
│   │   ├── DialogueSystem.swift     # Branching dialogue engine
│   │   ├── TimeSystem.swift         # Day/night, seasons
│   │   ├── NurtureSystem.swift      # Watering, pruning, fertilizing
│   │   └── MoodSystem.swift         # Plant mood influenced by time/weather
│   └── Data/
│       ├── PlantDatabase.swift       # All plant definitions (JSON/YAML)
│       ├── GardenLayouts.swift      # Zone layouts
│       └── DialogueTrees.swift       # Dialogue script storage
├── Rendering/
│   ├── GardenScene.swift            # SpriteKit scene
│   ├── PlantSprite.swift             # Animated plant sprites
│   ├── PlayerSprite.swift            # Player character
│   └── WeatherFX.swift              # Rain, sun, snow overlays
├── Views/
│   ├── GardenView.swift             # Main game view
│   ├── DialogueView.swift           # Conversation UI overlay
│   ├── JournalView.swift            # Player's recorded insights
│   └── MapView.swift                # Zone selection
├── Audio/
│   ├── AmbientAudio.swift           # Background soundscape
│   └── DialogueAudio.swift          # Voice/UI sounds
└── Resources/
    ├── Assets.xcassets
    └── Plants/                      # Sprite atlases
```

### Key Design Decisions

- **SpriteKit over Canvas**: SpriteKit handles 2D animation, particles, and camera movement far better than SwiftUI Canvas
- **SwiftData for persistence**: Native, @Observable, no Core Data complexity
- **YAML dialogue scripts**: Non-programmers can write dialogue; parsed at runtime
- **Offline-first**: All game state local; Supabase sync later for social features

---

## 3. Dialogue System

### Data Model

```swift
// Plant dialogue script structure (YAML)
struct DialogueTree: Codable {
    let plantId: String
    let nodes: [DialogueNode]
}

struct DialogueNode: Codable {
    let id: String
    let text: String
    let moodRequired: PlantMood?       // Optional mood gate
    let timeOfDay: [TimeOfDay]?       // Morning, afternoon, evening, night
    let season: [Season]?              // Spring, summer, autumn, winter
    let pastTalksCondition: Int?       // "Only if talked 3+ times"
    let responses: [DialogueResponse]
}

struct DialogueResponse: Codable {
    let text: String                   // Player says this
    let nextNodeId: String?            // Jump to node
    let effect: DialogueEffect?         // Change plant mood, unlock
    let wisdomPoints: Int
}
```

### Mood System

Each plant has a `mood: PlantMood` (happy, contemplative, grumpy, sleepy, excited). Mood shifts based on:
- Time of day (plants get sleepy at night)
- Season (some plants love summer, hate winter)
- Player's past behavior (neglect → sad; regular watering → trusting)
- Weather (rain makes most plants happy)

Dialogue trees check mood as a gate — a grumpy plant gives short, terse answers. A happy plant opens up.

### Dialogue Memory

Each `Plant` stores `pastConversations: [PastConversation]`:
- What the player asked about
- What the plant revealed
- Topics that were avoided

This lets plants "remember" and not repeat themselves, and reference past conversations in new dialogue.

---

## 4. Art & Audio Style Guide

### Art Direction: "Storybook Watercolor"

- **Aesthetic**: Soft, hand-painted feel — like a children's book illustration crossed with a Studio Ghibli background
- **Color palette**: Warm earth tones, mossy greens, soft golden light; occasional jewel-tone accents for magical moments
- **Plants**: Exaggerated, expressive — leaves that droop when sad, perk up when watered, glow when happy
- **Player character**: Minimalist — a simple silhouette or cloak, doesn't distract from the garden
- **UI**: Paper texture overlays, hand-drawn borders, serif fonts (think: notebook paper + letterpress)
- **Animation**: Gentle idle bobbing on plants, slow leaf sway, smooth character movement (no jerky transitions)

### Audio Landscape

| Layer | Description |
|-------|-------------|
| Ambient | Layered: wind through leaves, distant bird calls, soft stream, crickets at night |
| Music | Minimalist piano + strings; sparse, non-intrusive; shifts subtly with season/time |
| Plant voices | Soft, ethereal synthesized tones (not speech) — a "voice" without words |
| UI sounds | Paper rustling on menu transitions, soft chime on successful action |
| Weather | Rain patter, thunder in distance, snow with near-silence |

---

## 5. Feature Prioritization

### MVP (Months 1–4)

| Priority | Feature | Notes |
|----------|---------|-------|
| P0 | 5 unique plants with full dialogue trees | Core loop — conversation IS the game |
| P0 | 1 garden zone (meadow) | Focused scope |
| P0 | Player movement (tap-to-move) | Simple, intuitive |
| P0 | Day/night cycle | Affects dialogue moods |
| P1 | Player journal | Records conversations |
| P1 | Watering mechanic | Optional but adds depth |
| P2 | Seasonal system | Winter dormancy, spring rebirth |

### Year 1 Expansions

| Feature | Timeline | Notes |
|---------|----------|-------|
| 15–20 total plants | Months 5–8 | Staggered release |
| 3 more zones | Months 5–9 | Forest edge, zen garden, night garden |
| Weather system | Month 6 | Affects plant moods |
| Plant customizer | Month 7 | Rearrange your garden |
| Achievement/wisdom points | Month 8 | Light progression |

### Year 2+

| Feature | Notes |
|---------|-------|
| Multiplayer garden visits | Async — send/receive plant seeds |
| AR mode | Point phone at real garden, overlay digital plants |
| Godot port (Android/Steam) | 6–12 months effort |
| Procedural story generation | AI-generated plant backstories |
| Community garden sharing | Upload your garden layout |

---

## 6. Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Scope creep — too many plants/zones | High | High | Lock MVP at 5 plants, 1 zone. No additions until shipped. |
| Dialogue writing bottleneck | High | High | Use YAML scripts; non-devs can write. Build dialogue editor tool early. |
| SpriteKit performance on older iPhones | Medium | Medium | Profile on iPhone 12 minimum; use sprite atlases aggressively |
| Apple Intelligence API changes | Low | Medium | Wrap AI calls in abstraction layer; mock for testing |
| Player finds plants boring | Medium | High | Make personalities extreme early — grumpy IS grumpy, not polite |
| Monetization feels pay-to-win | Low | High | Nurturing is OPTIONAL; core experience free. Cosmetics only. |

---

## 7. Development Roadmap

### Phase 0 — Foundation (Weeks 1–2)
- Set up Xcode project with XcodeGen
- SpriteKit scene with camera pan
- Plant data model + SwiftData container
- 1 prototype plant with 3 dialogue nodes

### Phase 1 — Core Loop (Weeks 3–8)
- 5 MVP plants with full dialogue trees
- Meadow zone with hand-crafted layout
- Tap-to-move player character
- Day/night mood system
- Player journal (persisted)

### Phase 2 — Polish (Weeks 9–12)
- Full art asset pass (sprites, UI, backgrounds)
- Audio implementation (ambient + music)
- Weather system
- 3 seasonal variants per plant dialogue

### Phase 3 — Soft Launch (Months 4–5)
- TestFlight with 100 users
- Feedback → dialogue tuning
- Bug fixes
- App Store submission

### Phase 4 — Year 1 (Months 6–12)
- Expand to 20 plants
- 3 new zones
- Social features (seed sharing)
- Achievement system

### Phase 5 — Multiplatform (Year 2)
- Godot port for Android/Steam
- AR mode
- Procedural content generation

---

## 8. Team & Tools

### Solo Developer Stack

| Role | Tool |
|------|------|
| Code | Xcode + Swift |
| Art | Procreate (illustrations) + Aseprite (sprites) |
| Audio | GarageBand (music) + Freesound.org (ambient) |
| Dialogue | Obsidian or Notion → YAML export |
| Build | XcodeGen |
| CI/CD | GitHub Actions → TestFlight |
| Analytics | Firebase (post-launch) |

### Minimum Team for MVP

- **Solo dev**: All code, game design, writing
- **Contract artist**: 3–5 illustrations for art direction doc, sprite set for 5 plants (~20 hours)
- **Composer**: 1 ambient track + 1 music loop (~8 hours)

### Recommended Team (Year 1)

- 1 game developer (you)
- 1 part-time artist (2 days/week)
- 1 part-time writer (dialogue scripts)
- 1 part-time composer

---

## Closing Note from Gemini

This game doesn't need to be technically impressive — it needs to be **emotionally real**. Five plants with deep, surprising dialogue are worth more than fifty plants with shallow exchanges. Invest early in making each plant feel like a character you'd actually miss if you stopped visiting. That's the whole game.
