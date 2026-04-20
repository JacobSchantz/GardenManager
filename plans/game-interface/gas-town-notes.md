# Gas Town — Key Takeaways

**Author:** Steve Yegge | **Date:** Jan 1, 2026 | **Source:** https://steve-yegge.medium.com/welcome-to-gas-town-4f25ee16dd04

**Repo:** https://github.com/steveyegge/gastown | **Beads:** https://github.com/steveyegge/beads

---

## What Is Gas Town?

An agent orchestrator — "Kubernetes for AI coding agents." Manages 20-30 Claude Code instances simultaneously. Built on top of Beads (a git-backed issue tracker). Written in Go. 100% vibe-coded.

---

## The 8 Stages of Developer AI Evolution

1. Zero/near-zero AI (completions, chat questions)
2. Agent in IDE, permissions on
3. Agent in IDE, YOLO mode
4. Wide agent fills the screen, code is just diffs
5. CLI single agent, YOLO
6. CLI multi-agent (3-5 parallel)
7. 10+ agents hand-managed
8. Building your own orchestrator

**Gas Town targets Stage 7-8 developers.**

---

## 7 Worker Roles

| Role | Scope | Purpose |
|------|-------|---------|
| **Mayor** 🎩 | Town | Your concierge/chief-of-staff. Main agent you talk to. Kicks off work convoys. |
| **Polecats** 😺 | Per-Rig | Ephemeral swarm workers. Spin up on demand, produce MRs, get decommissioned after merge. |
| **Refinery** 🏭 | Per-Rig | Merge Queue engineer. Intelligently merges polecats' changes one at a time to main. No work lost. |
| **Witness** 🦉 | Per-Rig | Watches polecats, helps unstick them, hustles MRs and refinery. |
| **Deacon** 🐺 | Town | Patrol agent. Runs a loop of steps. Daemon pings it every few min. Propagates "do your job" signal down. |
| **Dogs** 🐶 | Town | Deacon's helpers. Maintenance, cleanup, plugin work. Keeps Deacon from getting bogged down. |
| **Crew** 👷 | Per-Rig | Long-lived named agents for the Overseer (you). Design work, back-and-forth tasks. Your daily drivers. |

**8th role: Overseer (you)** — has an identity, inbox, can send/receive town mail.

---

## Key Concepts

### Town & Rigs
- **Town** = HQ (~/gt), manages all workers across projects
- **Rig** = one project/repo under Gas Town management

### Beads (Data Layer)
- Atomic unit of work (like an issue-tracker issue)
- Stored as JSON, tracked in Git alongside your project
- Two-tier: Rig beads (project work) and Town beads (orchestration)
- Cross-rig routing built in
- **Everything** lives in Beads: work, mail, events, agent identities, hooks

### GUPP — Gastown Universal Propulsion Principle
- **"If there is work on your hook, YOU MUST RUN IT."**
- Solves the core problem: Claude Code sessions end when context fills up
- Each worker has a **Hook** (a pinned bead) where molecules (workflows) are hung
- Work is persistent in Beads; sessions are ephemeral "cattle"
- `gt sling` — assign work to a worker's hook
- **GUPP Nudge**: Agents sometimes wait for input instead of auto-starting. Gas Town nudges them 30-60s after startup. Always within 5 min.

### Handoff & Seance
- Any worker can say "let's hand off" → gracefully restarts → GUPP picks up where it left off
- `gt seance` — new worker can talk to its predecessor (via Claude Code's /resume) to recover context

---

## MEOW Stack — Molecular Expression of Work

The deeper framework under Gas Town. May outlast Gas Town itself.

| Layer | What | Description |
|-------|------|-------------|
| **Beads** | Work units | Lightweight issues in Git/JSON. The atoms. |
| **Epics** | Bead hierarchies | Beads with children. Parallel by default, explicit dependencies for sequencing. |
| **Molecules** | Workflows | Chained beads. Arbitrary shapes. Survive crashes/restarts. Agents walk the chain. |
| **Protomolecules** | Templates | Pre-built workflow graphs (design→plan→implement→review→test). Instantiated with variable substitution. |
| **Formulas** | Source form | TOML files describing workflows. "Cooked" into protomolecules. Composable with loops and gates. |
| **Guzzoline** | All the work | The sea of molecularized work molecules. |

**Key insight:** Molecules survive agent crashes, compactions, restarts. Agent just finds its place in the chain and continues.

---

## Relevant to Garden Interface

Gas Town validates the "plants as agents" concept:
- ✅ Multiple AI agents running simultaneously → plants in a garden
- ✅ Each agent has a persistent identity and role → each plant has a personality/specialty
- ✅ Work is visible and trackable → plant visual states (glowing, blooming, wilted)
- ✅ GUPP = "if work is on your hook, run it" → "if someone talks to you, start working"
- ✅ Beads as persistent state → SwiftData/garden state
- ✅ Orchestrator manages agent lifecycle → Manager role manages Planner/Implementer/Tester
- ✅ Merge Queue / Refinery → need a way to merge multiple agents' work
- ✅ Degrades gracefully → garden should work offline, agents queue when disconnected

**Key difference:** Gas Town uses tmux + CLI. Garden Interface would be a visual/garden metaphor for the same orchestration.

---

*Summarized by Foreman (ManagerAgent) | 2026-04-20*
