# Garden Interface — Comprehensive Development Plan

> *"The garden speaks to those who listen."*

---

## 1. Phased Development Roadmap

### Phase 0: Pre-Production (Weeks 1–4 | ~160 hours)

| Week | Focus | Deliverable |
|------|-------|-------------|
| 1 | Concept lock, core loop definition | Game Design Document (GDD) v1 |
| 2 | Art style exploration, prototype UI | Mood board, style frames |
| 3 | Tech spike: SwiftUI SpriteKit integration + Godot comparison | Spike report, recommendation |
| 4 | Architecture design, data model, tooling setup | Architecture doc, CI pipeline |

**Gate:** GDD approved → proceed to Phase 1

---

### Phase 1: MVP — "A Single Conversation" (Months 2–4 | ~480 hours)

*Goal: One garden zone, one talkative plant, one nurturing action. Prove the feeling.*

| Sprint | Focus | Effort |
|--------|-------|--------|
| 1–2 | Player movement + tap-to-move on a simple tilemap | 80h |
| 3–4 | Dialogue engine: branching trees, state tracking, basic UI | 100h |
| 5 | First character: Rose (personality, 3 conversation arcs, memory) | 60h |
| 6 | Nurturing: watering mechanic with simple VFX + plant response | 60h |
| 7 | Day/night cycle (visual only, no season yet) + ambient audio | 60h |
| 8 | Polish pass, onboarding, first playtest | 40h |

**MVP Scope:**
- 1 hand-crafted garden zone (20×20 tiles)
- 1 sentient plant (Rose) with ~30 dialogue nodes
- Walk + interact + water
- Day/night visual cycle
- Placeholder art + 3 music loops
- No save system yet (session-only)

**Gate:** Internal playtest confirms the feeling works → Phase 2

---

### Phase 2: "A Garden of Friends" (Months 5–9 | ~800 hours)

*Goal: 5+ plants, multiple zones, memory that matters, seasons begin.*

| Month | Focus |
|-------|-------|
| 5 | 4 new plant characters (Fern, Oak, Daisy, Mushroom), each with unique personality + 25+ dialogue nodes |
| 6 | Zone 2 (The Pond) + Zone 3 (The Grove) — hand-crafted, distinct biomes |
| 7 | Dialogue memory system: plants reference past conversations, player choices affect mood |
| 8 | Seasons (Spring → Summer → Autumn → Winter), each affecting dialogue + garden appearance |
| 9 | Save/load, settings, accessibility, haptics, second playtest |

**New Systems:**
- Seasonal time system (1 season = 7 real days by default, configurable)
- Plant mood model (happy/neutral/wilted) affected by nurturing + conversation choices
- Fertilizing + pruning added as nurturing actions
- Background music per zone + season

**Gate:** Closed beta with 10 testers → Phase 3

---

### Phase 3: "The Garden Remembers" (Months 10–18 | ~1,200 hours)

*Goal: Deep narrative, procedural elements, full audio/visual polish, App Store readiness.*

| Quarter | Focus |
|---------|-------|
| Q1 (Mo 10–12) | Narrative arc system: plants have multi-week storylines that resolve emotionally. 10+ total characters. Procedural garden decoration (rocks, paths, mushrooms spawn based on season + care). |
| Q2 (Mo 13–15) | Full art production: final character sprites, zone backgrounds, VFX (fireflies, rain, falling leaves), animations. Full audio: 15+ music tracks, ambient loops per zone/season/time, plant voice SFX. |
| Q3 (Mo 16–18) | Localization (EN + 3 languages), accessibility (VoiceOver, Dynamic Type, reduced motion), performance optimization, App Store submission, launch. |

**Gate:** Ship v1.0 on iOS App Store

---

### Phase 4: "Seasons Grow" (Months 19–24 | ~600 hours)

*Goal: Post-launch content, community features, platform expansion.*

- 3 new zone DLCs (The Greenhouse, The Moonlit Path, The Ancient Roots)
- 5 new plant characters
- Garden photo mode + sharing
- iCloud save sync
- Godot port evaluation (if cross-platform demand exists)
- Gentle daily quest system ("Visit someone who seems lonely today")

---

### Phase 5: Long-Term Vision (Years 3–5)

- **Year 3:** Multiplayer gardens (visit friends' gardens, leave notes on their plants), weather system affecting mood, full Godot cross-platform release (Android, desktop, Switch)
- **Year 4:** Modding support (community-created plants + dialogue), physical merch (plant character plushies), potential animated short
- **Year 5:** "Garden Interface 2" or major expansion — new biome type, deeper nurturing (crossbreeding, garden design), AR mode (place plants in your real room via ARKit)

---

## 2. Tech Stack Decision

### Recommendation: **SwiftUI + SpriteKit** (Primary) with **Godot 4.x** evaluated at Phase 4

| Factor | SwiftUI + SpriteKit | Godot 4.x |
|--------|-------------------|-----------|
| **iOS native feel** | ✅ First-class | ⚠️ Requires wrapper |
| **UI/Dialogue system** | ✅ SwiftUI is ideal for text-heavy UI | ⚠️ Godot UI is functional but less polished |
| **2D rendering** | ✅ SpriteKit mature for 2D | ✅ Excellent 2D engine |
| **App Store integration** | ✅ Native IAP, Game Center, iCloud | ❌ Manual integration |
| **Accessibility** | ✅ VoiceOver, Dynamic Type free | ⚠️ Must implement manually |
| **Haptics** | ✅ CoreHaptics native | ⚠️ Limited |
| **Cross-platform** | ❌ Apple only | ✅ Win/Mac/Linux/Mobile/Console |
| **Scene editing** | ⚠️ Code-driven (no visual editor) | ✅ Excellent visual editor |
| **Learning curve** | ✅ Swift is approachable | ⚠️ GDScript or C# |
| **Community/plugins** | ✅ Large iOS ecosystem | ✅ Growing, strong indie community |
| **Performance (2D)** | ✅ Great for our scope | ✅ Great |

**Why SwiftUI+SpriteKit wins for MVP:**
1. Dialogue is 70% of the game — SwiftUI excels at text UI
2. iOS is the primary target — native is always smoother
3. Accessibility comes nearly free
4. SpriteKit handles the 2D garden rendering well
5. No engine licensing concerns

**When to reconsider Godot:**
- If Android/desktop become priority before Phase 4
- If the visual editor would save significant art iteration time
- If the team includes Godot-experienced developers

**Architecture hybrid approach:** Design the data layer (dialogue, state, save) as engine-agnostic JSON/SwiftData. This makes a future Godot port a rendering-layer swap rather than a rewrite.

---

## 3. High-Level Architecture

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
│  │           Entity Component System       │  │
│  │  (Plant entities: Mood, Memory, Story) │  │
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

**Key Architectural Decisions:**
- **ECS-lite for plants:** Each plant is an entity with components (MoodComponent, MemoryComponent, DialogueComponent, VisualComponent). Lightweight — no full ECS framework, just protocols + structs.
- **Dialogue as data:** All dialogue lives in JSON files, not code. A dialogue compiler validates trees at build time.
- **Time as a service:** `GardenClock` is a singleton that broadcasts time events (hourChanged, seasonChanged). Systems subscribe, not poll.
- **Save as snapshots:** SwiftData stores the full garden state on a timer + on background. Portable format for future Godot port.

---

## 4. Dialogue System Design

### 4.1 Dialogue Tree Format

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

### 4.2 Memory Model

Each plant maintains a **Memory Bank** — a structured history:

| Memory Type | Example | Persistence |
|-------------|---------|-------------|
| **Topics discussed** | "dreams", "loneliness", "roots" | Permanent |
| **Player choices** | Chose to listen vs. leave | Permanent (last 50) |
| **Nurturing history** | Watered 3 times this week | Rolling 7-day window |
| **Emotional peaks** | Made Rose cry (joy) on Day 12 | Permanent (top 10) |
| **Seasonal references** | "Last winter was hard" | Current + previous season |

**How memory surfaces in dialogue:**
- Condition system checks memory in `conditions` block
- Dialogue lines can reference `{{memory.lastTopic}}` or `{{memory.daysSinceWatered}}` as template variables
- Writers use "callback nodes" — dialogue that only appears if a specific past event occurred

### 4.3 Plant Personality Engine

Each plant has a **Personality Profile**:

```
Rose:  warmth=0.9, formality=0.7, philosophical=0.6, playfulness=0.3
Fern:  warmth=0.5, formality=0.2, philosophical=0.8, playfulness=0.1
Daisy: warmth=0.8, formality=0.1, philosophical=0.2, playfulness=0.9
Oak:   warmth=0.6, formality=0.9, philosophical=0.9, playfulness=0.0
```

These values modulate:
- **Word choice** (which dialogue variant is selected)
- **Response to nurturing** (Oak barely notices watering; Daisy is overjoyed)
- **Seasonal mood shifts** (Fern loves rain, Rose wilts in heat)

### 4.4 Dialogue Authoring Workflow

1. Write dialogue in a spreadsheet (Google Sheets) with columns: ID, Speaker, Conditions, Lines, Choices, Effects
2. Export as JSON via custom script
3. Run `DialogueCompiler` at build — validates: no dead ends, all IDs resolve, conditions reference valid states
4. In-game debug overlay: tap any plant → see its current memory + available dialogue nodes

---

## 5. Art & Audio Style Guide

### 5.1 Visual Style

**Keywords:** Soft, watercolor-like, warm, hand-painted, Studio Ghibli meets children's book illustration

| Element | Style |
|---------|-------|
| **Characters (Plants)** | Chibi-proportioned, large expressive eyes (or eye-like features), soft outlines, idle breathing animation. Think: if Totoro were a rose bush. |
| **Environment** | Layered parallax backgrounds, hand-painted watercolor textures, soft edge blending. Grass tiles with subtle sway animation. |
| **UI** | Rounded corners, parchment/paper textures for dialogue boxes, ink-style borders, hand-drawn icons. Warm cream/off-white backgrounds, never pure white. |
| **Color Palette** | Warm earth tones base: moss green (#4A6741), warm cream (#F5E6C8), soft terracotta (#C4725A), sky blue (#8BBBD9). Seasonal accent palettes. |
| **Particles** | Fireflies (evening), dandelion seeds (spring), falling leaves (autumn), snowflakes (winter). Always soft, never sharp. |
| **Animations** | 12fps sprite animations (intentionally not smooth — gives hand-made feel). Plants bob gently. No harsh transitions — everything eases in/out over 0.5s+. |

**Seasonal Palette Shifts:**
- Spring: Fresh greens, cherry blossom pink, soft yellow
- Summer: Deep greens, warm gold, bright sky
- Autumn: Amber, rust, deep red, warm brown
- Winter: Cool blue-white, silver, muted green (evergreens only)

### 5.2 Audio Style

**Music:**
- Solo piano + gentle strings + soft woodwinds
- Tempo: 60–80 BPM (resting heart rate range)
- Key: Predominantly major, occasional modal mixture for emotional depth
- Reference: Joe Hisaishi, C418 (Minecraft), Toby Fox (Undertale calm tracks)
- 4 seasonal variations of each zone theme
- Day/night variations (major key daytime, relative minor at night)

**Ambient Soundscapes:**
- Wind through leaves (varying by season — gentle spring breeze vs. winter gust)
- Birdsong (species change by season + time of day)
- Water features (stream in The Grove, pond ambience)
- Insects (crickets at night, bees in summer)
- Rain (seasonal: spring showers, summer storms, autumn drizzle, winter silence)

**Plant Voice SFX:**
- NOT human voices — each plant has a unique instrumental motif (Rose = soft harp glissando, Oak = deep cello note, Daisy = piccolo trill, Fern = wind chime)
- Motif plays when dialogue begins, varies with mood (happy = major, sad = minor)
- Nurturing sounds: Water = gentle pour + plant sigh motif, Fertilize = soft chime, Prune = snip + relieved motif

---

## 6. Feature Prioritization Matrix

| Feature | Impact | Effort | Priority | Phase |
|---------|--------|--------|----------|-------|
| Player movement | 🔴 Critical | Low | P0 | 1 |
| Dialogue engine | 🔴 Critical | High | P0 | 1 |
| Plant memory system | 🔴 Critical | High | P0 | 1 |
| Single plant character | 🔴 Critical | Medium | P0 | 1 |
| Watering mechanic | 🟡 High | Low | P1 | 1 |
| Day/night cycle | 🟡 High | Medium | P1 | 1 |
| Ambient audio | 🟡 High | Medium | P1 | 1 |
| Multiple plant characters | 🟡 High | Medium | P1 | 2 |
| Multiple zones | 🟡 High | High | P1 | 2 |
| Season system | 🟡 High | High | P1 | 2 |
| Plant mood model | 🟡 High | Medium | P1 | 2 |
| Fertilizing + pruning | 🟠 Medium | Low | P2 | 2 |
| Save/load | 🟠 Medium | Medium | P2 | 2 |
| Narrative arcs | 🟠 Medium | High | P2 | 3 |
| Procedural decoration | 🟠 Medium | Medium | P2 | 3 |
| Full art production | 🟠 Medium | High | P2 | 3 |
| Accessibility | 🔵 Standard | Medium | P3 | 3 |
| Localization | 🔵 Standard | Medium | P3 | 3 |
| Photo mode | 🟢 Nice-to-have | Low | P4 | 4 |
| iCloud sync | 🟢 Nice-to-have | Medium | P4 | 4 |
| Daily quests | 🟢 Nice-to-have | Low | P4 | 4 |
| Multiplayer visits | 🟢 Nice-to-have | High | P5 | 5 |
| AR mode | 🟢 Nice-to-have | High | P5 | 5 |
| Modding support | 🟢 Nice-to-have | Very High | P5 | 5 |

---

## 7. Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **Dialogue writing bottleneck** — Content-heavy game, solo writer = slow | High | High | Use template system for variations. Hire freelance writer for Phase 2+. AI-assisted draft generation (human-edited). |
| **"Boring" perception** — No combat/puzzle may make game feel shallow | Medium | High | Emotion is the mechanic. Every playtest should ask "did you feel something?" Polish micro-interactions (plant reactions, VFX) to make every moment feel alive. |
| **Scope creep in dialogue** — Plant memories create combinatorial explosion | High | Medium | Limit memory references to last 5 interactions + top 10 emotional peaks. Dialogue compiler catches unreachable nodes. |
| **SwiftUI + SpriteKit integration friction** | Medium | Medium | Spike in Phase 0. Use `UIViewRepresentable` bridge. Keep SpriteKit for rendering only, SwiftUI for all UI. |
| **Performance on older devices** — Particle systems + many sprites | Low | Medium | Target 60fps on iPhone 12+. Profile early. Pool sprite objects. Limit active particles per zone. |
| **Season pacing feels wrong** — 7 real days per season may be too slow/fast | Medium | Low | Configurable in settings. Default to 7 days. Let players preview seasons in settings. |
| **App Store rejection** — Unusual gameplay may confuse reviewers | Low | Medium | Include clear onboarding. Ensure IAP guidelines compliance. Submit with detailed reviewer notes. |
| **Solo burnout** | High | High | Phase 1 MVP is deliberately small (1 plant). Build in rest weeks. Automate testing early. |

---

## 8. Tools, Plugins & Team Roles

### 8.1 Recommended Tools

| Category | Tool | Purpose |
|----------|------|---------|
| **IDE** | Xcode 16+ | Primary development |
| **2D Art** | Aseprite | Sprite creation, tilesets |
| **Art (painterly)** | Procreate | Backgrounds, character art |
| **Music** | Logic Pro | Composition + production |
| **Sound FX** | Ableton Live | Ambient design, plant motifs |
| **Dialogue authoring** | Google Sheets + custom JSON exporter | Non-technical writer friendly |
| **Project management** | Linear | Task tracking |
| **Version control** | GitHub | Code + assets |
| **CI/CD** | GitHub Actions + Xcode Cloud | Build, test, archive |
| **Analytics** | PostHog (self-hosted) | Privacy-first event tracking |
| **Crash reporting** | Sentry | Stability monitoring |

### 8.2 Key Swift Packages

| Package | Purpose |
|---------|---------|
| **SwiftData** | Persistence layer |
| **Kingfisher** | Asset loading (if remote assets needed later) |
| **AudioKit** | Advanced audio (crossfading, spatial) if AVFoundation insufficient |
| **SwiftUI Introspect** | Fine-grained UIKit control when needed |

### 8.3 Team Roles

**Solo Developer (Phase 0–2):**
- You do everything. Lean on:
  - Freelance writer for dialogue (Fiverr/Upwork, ~$500-1000 for 5 plants)
  - Freelance musician for initial tracks (~$300-600 for 3 loops)
  - AI tools (Midjourney for concept art reference, ChatGPT for dialogue draft variations)

**Small Team (Phase 3+):**
| Role | Focus | Time |
|------|-------|------|
| **Game Designer/Writer** (you or hire) | Dialogue, systems design, playtesting | Full-time |
| **2D Artist** | Character sprites, backgrounds, VFX, UI | Full-time Phase 3 |
| **Composer/Sound Designer** | Music, ambient, plant motifs | Part-time |
| **iOS Developer** (you or hire) | Core systems, SpriteKit, performance | Full-time |

**Budget Estimate (Solo, Year 1):**
| Item | Cost |
|------|------|
| Apple Developer Program | $99/yr |
| Freelance writing (5 plants) | $800 |
| Freelance music (Phase 1) | $500 |
| Aseprite | $20 (one-time) |
| Procreate | $13 (one-time) |
| Logic Pro | $200 (one-time) |
| Hosting (PostHog, assets) | $20/mo |
| **Total Year 1** | **~$1,900** |

---

## Appendix: MVP Playtest Checklist

The MVP (Phase 1) is successful if playtesters report:

- [ ] "I felt something when Rose talked about her dream"
- [ ] "I wanted to come back and talk to Rose again"
- [ ] "The garden felt alive / peaceful"
- [ ] "Watering felt meaningful, not like a chore"
- [ ] "The music made me calm"

If 3/5 playtesters check 3+ boxes, the core loop works. Build outward from there.

---

*"A garden is a grand teacher. It teaches patience and careful watchfulness."* — Kahlil Gibran

---

*Document version: 1.0 | Date: 2026-04-20 | Author: Foreman (ManagerAgent)*
