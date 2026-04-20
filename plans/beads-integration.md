# Beads → GardenManager Integration Plan

## What Is Beads?

Beads is a Dolt-backed issue tracker built for AI agents. Key features:
- **Persistent task state** in a SQL database (survives agent restarts)
- **Dependency graph** — `bd ready` shows only unblocked work
- **Hash-based IDs** — no merge collisions when multiple agents work concurrently
- **Hierarchical epics** — `bd-a3f8` → `bd-a3f8.1` → `bd-a3f8.1.1`
- **Compaction** — "memory decay" summarizes old closed tasks to save context
- **Molecules/Formulas** — declarative workflow templates (design → plan → implement → test)
- **Gates** — async coordination (human approval, timers, GitHub checks)
- **Stealth mode** — works without git, useful for local-only or evaluation

## Why Integrate Into GardenManager?

GardenManager's current task system uses flat `.md` files in `tasks/`. Problems:
1. **No dependency tracking** — can't express "Implementer can't start until Planner finishes"
2. **No state machine** — just file renames (new → planning → planned)
3. **No merge safety** — two agents writing to same file = conflict
4. **No compaction** — completed tasks pile up
5. **No agent identity** — can't track who's working on what

Beads solves all of these.

## Integration Architecture

### Layer 1: Beads as the Data Layer (Backend)

Replace flat `.md` files with Beads issues:

| Current | Beads Equivalent |
|---------|-----------------|
| `tasks/task-name.md` | `bd create "Task name"` |
| File rename (new→planning→planned) | `bd update bd-xxx --status in_progress` |
| Manual dependency tracking | `bd dep add bd-child bd-parent` |
| No ready-work detection | `bd ready` (shows unblocked tasks) |
| No agent assignment | `bd update bd-xxx --claim` |
| No audit trail | `bd show bd-xxx` (full history) |
| Stale completed tasks | `bd compact` (memory decay) |

### Layer 2: Garden Visual Layer (Frontend)

SwiftUI views that read from Beads via JSON:

```
Beads (Dolt DB) → bd list --json / bd ready --json / bd show --json
    ↓
GardenManager PlantViewModel
    ↓
SwiftUI Garden View (plants = beads, status = plant state)
```

| Beads State | Plant Visual |
|------------|-------------|
| `open` + no assignee | Seed (waiting to be planted) |
| `open` + assigned | Sprouting |
| `in_progress` | Growing (pulsing glow) |
| `blocked` | Wilted (needs water/unblock) |
| `review` | Budding (almost done) |
| `closed` (done) | Blooming 🌸 |
| `closed` (won't fix) | Dead leaves 🍂 |

### Layer 3: Agent Orchestration (Pipeline)

The 4-agent pipeline (Mayor → Planner → Implementer → Tester) maps to Beads molecules:

```
bd create "Feature X" -p 0                    → Epic
bd create "Plan Feature X" -p 0               → Planner task (blocks implement)
bd create "Implement Feature X" -p 0           → Implementer task (blocks test)
bd create "Test Feature X" -p 0                → Tester task
bd dep add <plan> <implement> --type blocks
bd dep add <implement> <test> --type blocks
bd dep add <plan> <epic> --type parent-child
bd dep add <implement> <epic> --type parent-child
bd dep add <test> <epic> --type parent-child
```

Mayor runs: `bd ready --json` → picks next unblocked task → spawns the right agent → agent claims via `bd update bd-xxx --claim`

## Implementation Steps

### Phase 1: Install & Initialize
1. `brew install beads`
2. `cd GardenManager && bd init --stealth` (stealth = no git commits of beads data)
3. Create initial beads for existing tasks
4. Test: `bd ready`, `bd list --json`

### Phase 2: Manager Agent Integration
1. Update Foreman (me) to use `bd` commands instead of flat files
2. Replace `tasks/` folder reads with `bd ready --json`
3. Replace file-based state tracking with `bd update --status`
4. Add dependency creation when spawning pipeline agents
5. Test: full pipeline (Mayor → Planner → Implementer → Tester)

### Phase 3: SwiftUI Garden Views
1. Create `BeadsClient` — wraps `bd` CLI calls with JSON parsing
2. Create `PlantViewModel` — maps bead → plant state
3. Create `GardenView` — renders plants with visual states
4. Add tap-to-detail — shows bead title, status, assignee, dependencies
5. Add real-time refresh — poll `bd list --json` every 30s

### Phase 4: Molecules & Formulas
1. Create a "standard pipeline" formula (plan → implement → test)
2. Create a "bug fix" formula (implement → test, skip planning)
3. Create a "spike" formula (plan only, no implementation)
4. Store formulas in `GardenManager/formulas/`

### Phase 5: Auto-Fix Integration
1. Connect the ATG auto-fix system to Beads
2. Each build failure creates a bead
3. Fixer agents claim beads, fix, close them
4. Garden view shows build-health plant

## File Structure

```
GardenManager/
├── .beads/                    ← Beads database (gitignored)
├── formulas/
│   ├── standard-pipeline.toml ← Plan → Implement → Test
│   ├── bug-fix.toml           ← Implement → Test
│   └── spike.toml             ← Plan only
├── GardenManager/
│   ├── Models/
│   │   ├── Bead.swift         ← Decodable bead from JSON
│   │   └── PlantState.swift   ← Maps bead status → plant visual
│   ├── Services/
│   │   └── BeadsClient.swift  ← Wraps `bd` CLI, JSON parsing
│   └── Views/
│       ├── GardenView.swift   ← Main garden scene
│       └── PlantDetailView.swift ← Bead details
├── roles/                     ← Agent role definitions (unchanged)
└── plans/                     ← Existing plans (unchanged)
```

## Open Questions
1. **Stealth vs git mode?** Stealth is simpler (no dolt push/pull) but loses multi-machine sync. Start with stealth, upgrade later.
2. **SwiftUI polling vs WebSocket?** Start with 30s polling of `bd list --json`. WebSocket would require a beads server.
3. **Beads MCP server?** There's a `beads-mcp` Python package — could use MCP protocol instead of CLI wrapping. Worth investigating.
4. **Dolt server mode?** Single-writer embedded mode is fine for now. Server mode needed for concurrent writers (multiple agents at once).
