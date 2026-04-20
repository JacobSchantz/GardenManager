# Garden Interface — GLM Prompt (Refined)

You are an expert game designer, technical architect, and iOS developer specializing in cozy, agent-driven experiences. Create a comprehensive development plan for "Garden Interface" – a garden simulation where plants are AI coding agents.

**Core Concept:**
- The player walks around a peaceful garden. Music plays. It feels calm.
- The player walks up to a plant and talks to it.
- Each plant is actually an AI agent that can do coding or other tasks for you.
- When you talk to a plant, an agent is spun up in the cloud.
- That agent can do things — write code, push to GitHub, run builds, etc.
- You can see the results of what the agent did, reflected within the garden.
- You can always see clearly what each agent is currently working on.

**That's the whole game. Everything else serves this loop.**

**Core Loop:**
1. Walk through the garden (2D top-down, tap-to-move)
2. Ambient music plays
3. Approach a plant → conversation triggers
4. You tell the plant what you need (a feature, a bug fix, a refactor)
5. The plant (agent) spins up in the cloud and starts working
6. You can see — clearly, at a glance — what each plant is working on
7. The agent completes its task, pushes to GitHub
8. You see the result reflected in the garden (new growth, a flower blooming, a path appearing)

**Key Design Requirements:**

**Walking & Atmosphere:**
- Simple, peaceful garden to walk around in
- Ambient music (calm, looping, seasonal)
- 2D top-down or 2.5D isometric view
- The garden should feel alive — gentle animations, weather, day/night

**Talking to Plants:**
- Walk up to a plant → conversation UI opens
- Natural language input (type or speak)
- The plant responds in character (each has a personality)
- What you say becomes the task prompt for the agent

**Plants as Agents:**
- Each plant IS an AI agent with a specific role or specialty
- When you give a plant a task, a cloud agent spins up
- The agent works autonomously: writes code, runs tests, pushes to GitHub
- Plants have names, personalities, and specialties (e.g., "Oak" handles architecture, "Daisy" does UI, "Fern" writes tests)
- You can have multiple plants working simultaneously

**Visibility — See What's Happening:**
- At a glance, you MUST be able to see what each plant/agent is working on
- Visual indicators on each plant: working (glowing/pulsing), idle (still), done (blooming/sparkling)
- A status view showing: agent name, current task, progress, logs
- Real-time or near-real-time updates from the cloud agent
- Notifications when a task completes or fails

**Seeing Results:**
- When an agent finishes a task and pushes to GitHub, the result shows in the garden
- New growth, visual changes, a "harvest" mechanic — the garden reflects your productivity
- You can review what was done (diff, summary, build status) without leaving the garden
- Failed tasks = wilted plants (water them = retry)

**Technical Requirements:**
- Primary platform: Native iOS/iPadOS app (SwiftUI)
- Cloud agent integration: OpenClaw or similar agent orchestration
- GitHub integration: commits, PRs, build status
- Real-time agent status: WebSocket or polling
- Offline: Garden walks work offline; agent tasks queue and sync when online
- Data: SwiftData for local state; cloud services for agent orchestration

**What This Is NOT:**
- NOT a farming sim — no heavy resource management
- NOT a chatbot wrapper — the garden IS the interface, not a sidebar
- NOT just monitoring — you interact with agents through conversation, not dashboards
- NOT complex — the core is simple: walk, talk, see results

**Deliverables:**
1. Full phased development roadmap (MVP → 2 years → 5 years) with estimated effort
2. Recommended tech stack (SwiftUI, SpriteKit, cloud agent framework) with rationale
3. High-level architecture — how the iOS app connects to cloud agents and GitHub
4. Agent conversation design — how talking to a plant becomes a task prompt
5. Art & audio style guide — garden aesthetics, agent status visual language
6. Feature prioritization matrix
7. Risks & mitigation — cloud latency, agent reliability, GitHub API limits
8. Tools, plugins, and team roles

Be practical and focused. This game has one job: make working with AI agents feel like tending a garden. Keep it simple, make it beautiful, make it work.
