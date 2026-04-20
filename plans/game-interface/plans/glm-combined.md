# Garden Interface — Combined Plan

> The best of every model's response, synthesized into a single authoritative plan.

---

## Sources

| Model | What it contributed |
|-------|-------------------|
| Google/Gemini | "Storybook Watercolor" art direction, Swift struct dialogue data model, clean risk table, offline-first principle, "emotionally real" philosophy |
| GLM 5.1 | Detailed phased roadmap with gates, ECS-lite architecture, JSON dialogue format with conditions/effects, personality profiles, memory model, feature priority matrix, playtest checklist, budget estimate |

Grok and Peaches echoed the prompt without producing a plan — not included.

### Key External Influence: Gas Town (Steve Yegge)

Gas Town is an agent orchestrator ("Kubernetes for AI coding agents"). Key learnings:

- **Multiple agents with roles** → Mayor, Planner, Implementer, Tester (duplicates allowed)
- **GUPP: persistent work survives session crashes** → Plant memory persists in SwiftData
- **Visual status** → Glowing=working, blooming=done, wilted=failed
- **Graceful degradation** → Garden works offline; agents queue when disconnected
- **Garden Interface = Gas Town with a garden skin**

---

## 1. Tech Stack Decision

### Primary: SwiftUI + SpriteKit + SwiftData

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| UI | SwiftUI | Best for text-heavy dialogue UI; native Apple feel |
| Rendering | SpriteKit | 2D garden scenes, particles, camera — mature on iOS |
| State | SwiftData | Modern persistence, @Observable, no Core Data overhead |
| Dialogue | JSON trees + custom compiler | Engine-agnostic, non-devs can write, build-time validation |
| Audio | AVFoundation + AudioKit (if needed) | Built-in baseline; AudioKit for advanced spatial/crossfade |
| AI | Apple Intelligence (on-device) | Contextual suggestions, future-proofing |
| AR | ARKit + RealityKit | Optional AR mode in Year 2+ |
| Build | XcodeGen + SPM | Standard iOS tooling |
| CI/CD | GitHub Actions → Xcode Cloud → TestFlight | Automated pipeline |

### Secondary: Godot 4.x (Year 2+ port)

| Factor | SwiftUI + SpriteKit | Godot 4.x |
|--------|-------------------|-----------|
| iOS native feel | ✅ First-class | ⚠️ Requires wrapper |
| Dialogue UI | ✅ SwiftUI excels | ⚠️ Less polished |
| 2D rendering | ✅ SpriteKit mature | ✅ Excellent |
| App Store / IAP | ✅ Native | ❌ Manual |
| Accessibility | ✅ VoiceOver, Dynamic Type free | ⚠️ Must implement |
| Cross-platform | ❌ Apple only | ✅ All platforms |
| Visual editor | ⚠️ Code-driven | ✅ Excellent scene editor |
| Performance | ✅ Great for scope | ✅ Great for scope |

**Verdict: Ship iOS with SwiftUI first. Design data layer as engine-agnostic JSON so a Godot port is a rendering swap, not a rewrite. Re-evaluate Godot at Phase 4 if cross-platform demand exists.**

---

## 2. Architecture

```
┌─────────────────────────────────────────────┐
│                  App Layer                   │
│  SwiftUI (Navigation, Settings, Dialogue UI) │
├─────────────────────────────────────────────┤
│              Game Scene Layer                │
│  SpriteKit Scene (GardenView, Characters,    │
│  Particles, Day/Night Overlay)               │
├─────────────────────────────────────────────┤
│              Systems Layer                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐ │
│  │ Dialogue │ │  Time &  │ │  Nurturing   │ │
│  │ Engine   │ │ Season   │ │  System      │ │
│  └────┬─────┘ └────┬─────┘ └──────┬───────┘ │
│       │            │              │          │
│  ┌────┴────────────┴──────────────┴───────┐  │
│  │         ECS-lite Plant Entities         │  │
│  │  (Mood, Memory, Story Components)       │  │
│  └────────────────────┬───────────────────┘  │
├───────────────────────┼─────────────────────┤
│               Data Layer                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐ │
│  │ SwiftData│ │  JSON    │ │  UserDefaults│ │
│  │ (Save)   │ │(Dialogue)│ │  (Settings)  │ │
│  └──────────┘ └──────────┘ └──────────────┘ │
├─────────────────────────────────────────────┤
│              Audio Layer                     │
│  AVFoundation (Music) + AudioToolbox (SFX)   │
└─────────────────────────────────────────────┘
```

**Key decisions:**
- **ECS-lite for plants:** Each plant is an entity with components (Mood, Memory, Dialogue, Visual). Lightweight — protocols + structs, no framework.
- **Dialogue as data:** All dialogue lives in JSON files, not code. A `DialogueCompiler` validates trees at build time (no dead ends, all IDs resolve).
- **Time as a service:** `GardenClock` singleton broadcasts events (hourChanged, seasonChanged). Systems subscribe, not poll.
- **Save as snapshots:** SwiftData stores full garden state. Portable format for future Godot port.
- **Offline-first:** All game state local. Supabase sync only for social features (Year 2+).

### Directory Structure

```
GardenInterface/
├── App/
│   ├── GardenInterfaceApp.swift      # App entry, SwiftData container
│   └── AppState.swift               # @Observable global state
├── Core/
│   ├── Models/
│   │   ├── Plant.swift              # Plant entity
│   │   ├── GardenZone.swift         # Garden region
│   │   ├── Player.swift             # Player state, position, journal
│   │   └── DialogueState.swift      # Per-plant conversation history
│   ├── Systems/
│   │   ├── DialogueSystem.swift     # Branching dialogue engine
│   │   ├── TimeSystem.swift         # Day/night, seasons
│   │   ├── NurtureSystem.swift      # Watering, pruning, fertilizing
│   │   └── MoodSystem.swift         # Plant mood engine
│   └── Data/
│       ├── PlantDatabase.swift       # All plant definitions (JSON)
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

---

## 3. Dialogue System

### 3.1 Dialogue Tree Format (JSON)

```json
{
  "id": "rose_morning_greeting",
  "speaker": "rose",
  "conditions": {
    "timeOfDay": "morning",
    "mood": ["happy", "neutral"],
    "season": "spring",
    "metBefore": true,
    "lastTopic": "dreams"
  },
  "lines": [
    { "text": "Good morning, dear. Did you sleep well?", "speaker": "rose" },
    { "text": "I was dreaming about the rain last night.", "speaker": "rose" }
  ],
  "choices": [
    {
      "text": "Tell me about your dream.",
      "next": "rose_dream_story",
      "effects": { "relationship": +1, "setTopic": "dreams" }
    },
    {
      "text": "You look beautiful today.",
      "next": "rose_compliment_response",
      "effects": { "mood": "happy", "relationship": +2 }
    },
    {
      "text": "I should water the others.",
      "next": "rose_farewell",
      "effects": { "setTopic": "departure" }
    }
  ]
}
```

### 3.2 Mood System

Each plant has a `mood: PlantMood` (happy, contemplative, grumpy, sleepy, excited). Mood shifts based on:
- **Time of day** — plants get sleepy at night
- **Season** — some love summer, hate winter
- **Player behavior** — neglect → sad; regular watering → trusting
- **Weather** — rain makes most plants happy
- **Conversation choices** — empathy → warm; dismissive → withdrawn

Dialogue trees check mood as a gate: a grumpy plant gives short, terse answers. A happy plant opens up.

### 3.3 Memory Model

Each plant maintains a **Memory Bank**:

| Memory Type | Example | Persistence |
|-------------|---------|-------------|
| Topics discussed | "dreams", "loneliness", "roots" | Permanent |
| Player choices | Chose to listen vs. leave | Permanent (last 50) |
| Nurturing history | Watered 3 times this week | Rolling 7-day window |
| Emotional peaks | Made Rose cry (joy) on Day 12 | Permanent (top 10) |
| Seasonal references | "Last winter was hard" | Current + previous season |

**How memory surfaces in dialogue:**
- Condition system checks memory in `conditions` block
- Template variables: `{{memory.lastTopic}}`, `{{memory.daysSinceWatered}}`
- Writers use "callback nodes" — dialogue only appears if a specific past event occurred

### 3.4 Personality Profiles

Each plant has personality vectors that modulate dialogue selection and emotional response:

```
Rose:  warmth=0.9, formality=0.7, philosophical=0.6, playfulness=0.3
Fern:  warmth=0.5, formality=0.2, philosophical=0.8, playfulness=0.1
Daisy: warmth=0.8, formality=0.1, philosophical=0.2, playfulness=0.9
Oak:   warmth=0.6, formality=0.9, philosophical=0.9, playfulness=0.0
```

These values affect:
- **Word choice** (which dialogue variant is selected)
- **Nurturing response** (Oak barely notices watering; Daisy is overjoyed)
- **Seasonal mood shifts** (Fern loves rain, Rose wilts in heat)

### 3.5 Authoring Workflow

1. Write dialogue in Google Sheets with columns: ID, Speaker, Conditions, Lines, Choices, Effects
2. Export as JSON via custom script
3. Run `DialogueCompiler` at build — validates: no dead ends, all IDs resolve, conditions reference valid states
4. In-game debug overlay: tap any plant → see its current memory + available dialogue nodes

---

## 4. Art & Audio Style Guide

### 4.1 Visual Style: "Storybook Watercolor"

| Element | Style |
|---------|-------|
| **Characters** | Chibi-proportioned, large expressive features, soft outlines, idle breathing animation. Think: if Totoro were a rose bush. |
| **Environment** | Layered parallax backgrounds, hand-painted watercolor textures, soft edge blending. Grass tiles with subtle sway. |
| **UI** | Paper texture overlays, hand-drawn borders, serif fonts, ink-style dividers. Warm cream/off-white backgrounds — never pure white. |
| **Color palette** | Warm earth tones: moss green (#4A6741), warm cream (#F5E6C8), soft terracotta (#C4725A), sky blue (#8BBBD9). Jewel-tone accents for magical moments. |
| **Player character** | Minimalist — simple silhouette or cloak, doesn't distract from the garden |
| **Plants** | Exaggerated, expressive — leaves droop when sad, perk up when watered, glow when happy |
| **Particles** | Fireflies (evening), dandelion seeds (spring), falling leaves (autumn), snowflakes (winter). Always soft, never sharp. |
| **Animation** | 12fps sprites (intentionally hand-made feel). Plants bob gently. All transitions ease in/out over 0.5s+. |

**Seasonal palette shifts:**
- **Spring:** Fresh greens, cherry blossom pink, soft yellow
- **Summer:** Deep greens, warm gold, bright sky
- **Autumn:** Amber, rust, deep red, warm brown
- **Winter:** Cool blue-white, silver, muted green (evergreens only)

### 4.2 Audio Landscape

| Layer | Description |
|-------|-------------|
| **Music** | Solo piano + gentle strings + soft woodwinds. Tempo: 60–80 BPM (resting heart rate). Predominantly major, occasional modal mixture for emotional depth. Reference: Joe Hisaishi, C418 (Minecraft), Toby Fox (Undertale calm tracks). 4 seasonal variations per zone. Day/night variants (major daytime, relative minor at night). |
| **Ambient** | Layered: wind through leaves (varies by season), distant bird calls, soft stream, crickets at night, bees in summer |
| **Plant voices** | NOT human speech — each plant has a unique instrumental motif (Rose = soft harp glissando, Oak = deep cello note, Daisy = piccolo trill, Fern = wind chime). Motif plays when dialogue begins; varies with mood (happy = major, sad = minor). |
| **UI sounds** | Paper rustling on menu transitions, soft chime on successful action |
| **Weather** | Rain patter, distant thunder, spring showers, summer storms, autumn drizzle, winter near-silence |
| **Nurturing** | Water = gentle pour + plant sigh motif, Fertilize = soft chime, Prune = snip + relieved motif |

---

## 5. Feature Prioritization Matrix

| Feature | Impact | Effort | Priority | Phase |
|---------|--------|--------|----------|-------|
| Player movement (tap-to-move) | 🔴 Critical | Low | P0 | 1 |
| Dialogue engine | 🔴 Critical | High | P0 | 1 |
| Plant memory system | 🔴 Critical | High | P0 | 1 |
| Single plant character (Rose) | 🔴 Critical | Medium | P0 | 1 |
| Day/night cycle | 🟡 High | Medium | P1 | 1 |
| Watering mechanic | 🟡 High | Low | P1 | 1 |
| Ambient audio | 🟡 High | Medium | P1 | 1 |
| 5 total plant characters | 🟡 High | Medium | P1 | 2 |
| Multiple zones | 🟡 High | High | P1 | 2 |
| Season system | 🟡 High | High | P1 | 2 |
| Plant mood model | 🟡 High | Medium | P1 | 2 |
| Player journal | 🟡 High | Medium | P1 | 2 |
| Fertilizing + pruning | 🟠 Medium | Low | P2 | 2 |
| Save/load | 🟠 Medium | Medium | P2 | 2 |
| Narrative arcs | 🟠 Medium | High | P2 | 3 |
| Full art + audio production | 🟠 Medium | High | P2 | 3 |
| Accessibility (VoiceOver, Dynamic Type, reduced motion) | 🔵 Standard | Medium | P3 | 3 |
| Localization (EN + 3 languages) | 🔵 Standard | Medium | P3 | 3 |
| Photo mode | 🟢 Nice-to-have | Low | P4 | 4 |
| iCloud sync | 🟢 Nice-to-have | Medium | P4 | 4 |
| Daily gentle quests | 🟢 Nice-to-have | Low | P4 | 4 |
| Multiplayer garden visits | 🟢 Nice-to-have | High | P5 | 5 |
| AR mode | 🟢 Nice-to-have | High | P5 | 5 |
| Modding support | 🟢 Nice-to-have | Very High | P5 | 5 |
| Godot cross-platform port | 🟢 Nice-to-have | Very High | P5 | 5 |

---

## 6. Development Roadmap

### Phase 0 — Pre-Production (Weeks 1–4)

| Week | Focus | Deliverable |
|------|-------|-------------|
| 1 | Concept lock, core loop definition | Game Design Document v1 |
| 2 | Art style exploration, prototype UI | Mood board, style frames |
| 3 | Tech spike: SwiftUI + SpriteKit integration | Spike report |
| 4 | Architecture design, data model, CI setup | Architecture doc, pipeline |

**Gate:** GDD approved → Phase 1

### Phase 1 — MVP: "A Single Conversation" (Months 2–4)

*Goal: One garden zone, one talkative plant, one nurturing action. Prove the feeling.*

- 1 hand-crafted zone (Meadow, 20×20 tiles)
- 1 sentient plant (Rose) with ~30 dialogue nodes
- Walk + interact + water
- Day/night visual cycle (no seasons yet)
- Placeholder art + 3 music loops
- Session-only (no save yet)

**Gate:** Internal playtest confirms the feeling works → Phase 2

### Phase 2 — "A Garden of Friends" (Months 5–9)

- 5 total plants (Rose, Fern, Oak, Daisy, Mushroom) — each 25+ dialogue nodes
- 3 zones (Meadow, The Pond, The Grove)
- Dialogue memory system: plants reference past conversations
- Seasons (1 season = 7 real days default, configurable)
- Plant mood model
- Fertilizing + pruning
- Save/load, settings, accessibility, haptics
- Second playtest

**Gate:** Closed beta with 10 testers → Phase 3

### Phase 3 — "The Garden Remembers" (Months 10–18)

- Narrative arc system: plants have multi-week storylines that resolve emotionally
- 10+ total plant characters
- Procedural garden decoration (rocks, paths, mushrooms)
- Full art production: final sprites, zone backgrounds, VFX, animations
- Full audio: 15+ music tracks, ambient loops per zone/season/time, plant voice SFX
- Localization (EN + 3 languages)
- Accessibility (VoiceOver, Dynamic Type, reduced motion)
- Performance optimization
- App Store submission → Ship v1.0

**Gate:** Ship v1.0 on iOS App Store

### Phase 4 — "Seasons Grow" (Months 19–24)

- 3 new zone DLCs (The Greenhouse, The Moonlit Path, The Ancient Roots)
- 5 new plant characters
- Garden photo mode + sharing
- iCloud save sync
- Gentle daily quests ("Visit someone who seems lonely today")
- Godot port evaluation

### Phase 5 — Long-Term Vision (Years 3–5)

- **Year 3:** Multiplayer gardens (visit friends, leave notes), weather system, full Godot release (Android, desktop, Switch)
- **Year 4:** Modding support (community plants + dialogue), physical merch, potential animated short
- **Year 5:** Major expansion or sequel — new biome type, crossbreeding, AR mode via ARKit

---

### 6.1 Agent Orchestration Layer

Four agent types, each can have multiple instances:

| Agent | Role | Plant Metaphor |
|-------|------|---------------|
| **Mayor** | Receives tasks from player, assigns to Planners, monitors all agents | The oldest tree — talks to you, delegates work |
| **Planner** | Reads a task, writes a step-by-step implementation plan | A wise plant — thinks before acting |
| **Implementer** | Reads a plan, writes code, commits and pushes | A hardy plant — gets to work |
| **Tester** | Verifies the implementation solves the original problem | A careful plant — checks everything |

**Simple flow:**
```
Player talks to Mayor → Mayor assigns Planner → Planner writes plan
→ Mayor assigns Implementer → Implementer writes code → Mayor assigns Tester → Tester verifies
```

**Multiple instances:** You can have 2 Planners, 3 Implementers, etc. Each is its own plant in the garden.

**Visibility is mandatory:**
- Glowing/pulsing = working
- Blooming = done
- Wilted = failed (water to retry)
- Tap any plant to see what it's working on

---

## 7. Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| **Dialogue writing bottleneck** | High | High | Use JSON scripts; non-devs can write. Build dialogue editor tool early. AI-assisted drafts (human-edited). Hire freelance writer for Phase 2+. |
| **Solo burnout** | High | High | Phase 1 MVP is deliberately small (1 plant). Build in rest weeks. Automate testing. |
| **"Boring" perception** — no combat/puzzles | Medium | High | Make personalities extreme early — grumpy IS grumpy, not polite. Every playtest asks "did you feel something?" Polish micro-interactions. |
| **Scope creep** — too many plants/zones | High | High | Lock MVP at 1 plant, 1 zone. Lock Phase 2 at 5 plants, 3 zones. No additions until each gate passes. |
| **Dialogue memory combinatorial explosion** | High | Medium | Limit references to last 5 interactions + top 10 emotional peaks. Dialogue compiler catches unreachable nodes. |
| **SpriteKit + SwiftUI integration friction** | Medium | Medium | Spike in Phase 0. Use UIViewRepresentable bridge. SpriteKit for rendering only, SwiftUI for all UI. |
| **Performance on older iPhones** | Low | Medium | Target 60fps on iPhone 12+. Profile early. Pool sprites. Limit active particles per zone. |
| **Monetization feels pay-to-win** | Low | High | Nurturing is OPTIONAL; core experience free. Cosmetics only. |
| **Cloud agent reliability** — agents crash, stall, or produce bad output | High | Medium | GUPP Nudge system auto-restarts stalled agents. Refinery handles merge conflicts. Failed tasks = wilted plants (water to retry). |
| **Merge conflicts from parallel agents** | Medium | High | Refinery merges one at a time. Agents work in branches. No direct-to-main pushes. |
| **Agent cost** — multiple cloud agents running simultaneously | Medium | Medium | Default to 1-2 active agents. Player controls concurrency. Show cost estimate before spinning up. |
| **Context loss between agent sessions** | High | Medium | Plant memory persists in SwiftData. New session reads plant's conversation history (like `gt seance`). |

---

## 8. Tools & Team

### Solo Developer Stack

| Category | Tool | Cost |
|----------|------|------|
| IDE | Xcode 16+ | Free |
| 2D Art | Aseprite (sprites) + Procreate (backgrounds) | $33 one-time |
| Music | Logic Pro | $200 one-time |
| Sound FX | Ableton Live or Freesound.org | Free–$99 |
| Dialogue authoring | Google Sheets + custom JSON exporter | Free |
| Project management | Linear | Free |
| Version control | GitHub | Free |
| CI/CD | GitHub Actions + Xcode Cloud | Free tier |
| Analytics | PostHog (self-hosted) or Firebase | Free tier |
| Crash reporting | Sentry | Free tier |

### Budget Estimate (Solo, Year 1)

| Item | Cost |
|------|------|
| Apple Developer Program | $99/yr |
| Freelance writer (5 plants) | $800 |
| Freelance composer (Phase 1) | $500 |
| Aseprite + Procreate + Logic Pro | $233 one-time |
| Hosting (PostHog, assets) | ~$240/yr |
| **Total Year 1** | **~$1,900** |

### Team Expansion

**MVP (Phase 0–2):** Solo + freelance writer + freelance composer

**Launch (Phase 3):**
| Role | Focus | Time |
|------|-------|------|
| Game Designer/Writer | Dialogue, systems, playtesting | Full-time |
| 2D Artist | Sprites, backgrounds, VFX, UI | Full-time |
| Composer/Sound Designer | Music, ambient, plant motifs | Part-time |
| iOS Developer | Core systems, SpriteKit, performance | Full-time |

---

## Appendix: MVP Playtest Checklist

The MVP is successful if playtesters report:

- [ ] "I felt something when Rose talked about her dream"
- [ ] "I wanted to come back and talk to Rose again"
- [ ] "The garden felt alive / peaceful"
- [ ] "Watering felt meaningful, not like a chore"
- [ ] "The music made me calm"

If 3/5 playtesters check 3+ boxes, the core loop works. Build outward from there.

---

*"This game doesn't need to be technically impressive — it needs to be emotionally real. Five plants with deep, surprising dialogue are worth more than fifty with shallow exchanges. Invest early in making each plant feel like a character you'd actually miss if you stopped visiting."*

---

*Document version: 1.0 | Date: 2026-04-20 | Synthesized from Google + GLM 5.1 responses*
