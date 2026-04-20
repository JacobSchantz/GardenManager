# GardenManager — Agent Instructions

This file provides instructions for any AI agent (Claude Code, Codex, Gemini CLI, OpenClaw, etc.) working on this project.

## Before Writing Prompts

**ALWAYS read `plans/game-interface/prompts/tips.md` before writing any prompt.** Follow the 8 keys: clarity, role, few-shot examples, chain-of-thought, exact format, constraints, structured sections, iteration.

## Beads Issue Tracker

This project uses **bd (beads)** for task tracking. All agents use the same CLI.

### Quick Reference

```bash
bd ready              # Find available (unblocked) work
bd list               # See all issues
bd show <id>          # View issue details + audit trail
bd create "Title" -p 0 -t task   # Create a new issue
bd update <id> --claim           # Claim work (sets assignee + in_progress)
bd update <id> --status closed   # Close an issue
bd update <id> --notes "..."     # Log progress
bd dep add <child> <parent>      # Add dependency
bd dolt push          # Push beads database to remote
bd remember "key fact"           # Save persistent knowledge
```

### Rules

- Use `bd` for ALL task tracking — no markdown TODO lists
- Always `bd update <id> --claim` before starting work
- Always `bd update <id> --notes "..."` to log progress at each milestone
- Always close issues when done: `bd update <id> --status closed`
- Always `bd dolt push` after changes to share state with other agents
- Use `bd remember` for persistent knowledge that other agents should see

## Session Completion

When ending a work session, complete ALL steps:

1. **File issues** for remaining work
2. **Run quality gates** (tests, builds)
3. **Close finished issues**: `bd update <id> --status closed`
4. **Push everything**:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   ```
5. **Verify**: `git status` must show "up to date with origin"

## Architecture

- **SwiftUI** app with SpriteKit + SwiftData
- AI features: `GardenManager/AI/` — FastVLM, LocalAIClient
- Voice: `GardenManager/GrokVoice/`, `GardenManager/OpenClawVoice/`
- Plans: `plans/` — game-interface, beads-integration
- Roles: `roles/` — manager, planner, implementer, tester
- Tasks: `tasks/` — flat .md files (being replaced by Beads)

## Conventions

- Always `git pull` before changes, `git push` after
- Plans go in `plans/<project>/prompts/` and `plans/<project>/plans/`
