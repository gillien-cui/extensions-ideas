# Hermes Agent — Alternatives & Feature Landscape

> Follow-up to `hermes-agent-101.md`. Question: are there other popular agents that work with many
> model providers and have a broad set of tools? How do they handle workflows and automations, goal
> setting, and semantic memory search?
> Researched 2026-10-07. Hermes details come from its source code and docs. Details for other tools
> come from public write-ups and docs, plus general knowledge where marked "≈". Check those before
> relying on them.

## 1. Hermes' own answer first (it covers more than the README suggests)

| Capability | What Hermes ships |
|---|---|
| **Goal setting** | `/goal <objective>`: a "Ralph loop", inspired by Codex CLI's `/goal`. After each turn, a separate judge model checks whether the goal is met. If not, Hermes prompts itself to keep going until it is done, you pause it, or it runs out of turns. |
| **Recurring work in a session** | `/loop 5m <prompt>` re-runs a prompt on a timer (Claude Code-style). `/heartbeat every 10m <prompt>` sends one recurring prompt into the current conversation whenever it is idle. |
| **Unattended schedules** | `hermes cron`: a durable scheduler. Each run starts a fresh agent, can load skills, and sends the result to any chat platform. |
| **Multi-agent workflows** | **Kanban**: a task board stored in SQLite and shared by all your profiles. Tasks can have dependencies, assignees, review and handoff steps, and each worker runs as its own process. A card created with `--goal` keeps working until its acceptance criteria are met. Also available: `delegate_task` subagents and the Mixture-of-Agents feature. |
| **Semantic memory search** | ⚠️ **Not built in.** The built-in recall is SQLite **FTS5** (keyword) search plus LLM summarisation, alongside the small `MEMORY.md`/`USER.md` files. Embedding (meaning-based) search comes from **memory-provider plugins**, and only one can be active at a time: Mem0, Supermemory, Honcho, Hindsight, OpenViking, RetainDB, ByteRover, Holographic. The active plugin pre-loads relevant memories before each turn and syncs every turn back to its store. |

## 2. The closest equivalents (self-hosted, always-on, many models, many tools)

| Agent | What it is | Models | Workflows / goals | Memory |
|---|---|---|---|---|
| **OpenClaw** | Hermes' main peer. Popular open-source personal assistant that answers on 20+ chat channels (WhatsApp, iMessage, Slack, Teams, Telegram, Discord…). Large skills marketplace (ClawHub, "700+ skills"). | Any provider | Cron jobs + heartbeat | Markdown memory files with **hybrid search**: embedding chunks (~400 tokens) **+ BM25** keyword ranking. A `memory` CLI manages indexing and promotion. Has semantic search out of the box. |
| **NanoClaw** | Lightweight OpenClaw alternative that runs each agent in its own Linux container (isolation from the OS, not from permission checks). | ≈ fewer providers | ≈ scheduled tasks | ≈ simple per-group memory files |
| **Agent Zero** (Python, agent0ai) | ≈ General-purpose agent running in Docker. Agents can spawn subordinate agents in a hierarchy. Fully customisable prompts. | ≈ any (via LiteLLM) | ≈ scheduler, multi-agent delegation | ≈ **Vector memory** (FAISS embeddings) for facts and past solutions |
| **Goose** (Block) | ≈ Desktop app + CLI agent; tools come from MCP "extensions". | ≈ any | ≈ **Recipes**: shareable, parameterised workflows. ≈ Scheduled recipes. | ≈ Memory extension; lighter weight |
| **Eigent** (CAMEL-AI) | "Open-source Cowork desktop". Splits a task across a small team: Developer, Browser, Document and Multi-modal agents. | Multi | Task decomposition across that team | ≈ basic |
| **Letta** (formerly MemGPT) | Agent *runtime* built around memory. The agent edits its own tiered memory, OS-style. Runs as a server with an agent development environment (ADE). | Any | Long-lived stateful agents; tool rules | **Strongest memory design**: core memory blocks + archival (vector) memory + recall memory + recursive summarisation |

**Bottom line:** For a "lives on a server, reachable over chat, many models, many tools" agent, the
field is really **Hermes vs OpenClaw**, with NanoClaw and Agent Zero behind them. OpenClaw has the
bigger ecosystem and **semantic memory built in**. Hermes has the stronger self-improvement loop
(skills it writes, nudges, curator) and richer **goal/workflow** features (`/goal`, Kanban,
`/loop`, `/heartbeat`).

## 3. Adjacent categories (overlap, but a different shape)

- **Coding agents (multi-model):** OpenHands (≈89k⭐, "open-source Devin"), OpenCode, Aider, Goose.
  Claude Code and Codex CLI are tied to their own vendor's models but set the standard for features
  like `/goal` and `/loop`, which Hermes copied.
- **Visual workflow builders with AI agents:** n8n, Dify, Flowise, Langflow. They have the strongest
  *workflow* tooling: triggers, branching, hundreds of integrations, built-in RAG/vector stores, and
  any model. They are less of an autonomous agent with its own personality and memory.
- **Agent frameworks (you build the agent):** LangGraph (graph workflows, checkpoints,
  human-in-the-loop), CrewAI (role-based teams), Microsoft Agent Framework/AutoGen, Google ADK,
  Pydantic AI, MetaGPT (simulates a whole "software company").
- **Self-hosted chat UIs with agents/RAG:** Open WebUI, LibreChat, AnythingLLM (built-in vector
  RAG), Jan (local-first, offline).
- **Bolt-on memory layers** (add semantic memory to any agent): Mem0, Zep/Graphiti (a temporal
  knowledge graph), Supermemory, Honcho. Several of these are Hermes plugins.
- **Commercial hosted agents:** ChatGPT agent, Claude (Cowork / Claude Code), Manus. Polished, but
  locked to one vendor's models and hosted by them.

## 4. Feature cheat-sheet

| | Hermes | OpenClaw | Agent Zero | Goose | Letta | n8n/Dify |
|---|---|---|---|---|---|---|
| Many model providers | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Chat-app gateway | ✅ ~20 | ✅ 20+ | ✗ | ✗ | ≈ via API | ✅ via nodes |
| Self-written skills | ✅ + curator | ≈ partial | ≈ via memory | ✗ | ✗ | ✗ |
| Goal loop (until done) | ✅ `/goal` | ≈ | ≈ | ≈ | ✗ | ✗ |
| Scheduled jobs | ✅ cron | ✅ cron | ≈ | ≈ | ✗ | ✅ triggers |
| Multi-agent board/workflow | ✅ Kanban | ≈ | ✅ hierarchy | ≈ recipes | ≈ | ✅ visual |
| Semantic (embedding) memory | 🔌 plugin | ✅ hybrid | ✅ | ≈ | ✅ | ✅ RAG |

✅ = ships it · 🔌 = needs a plugin · ≈ = partial or unverified · ✗ = not a focus

## 5. Product-idea angles

- **Semantic memory is now expected.** Hermes needs a plugin for it, which leaves room for a
  memory product that is easy to self-host (a hybrid vector + BM25 store, or a knowledge graph)
  shipped as a plugin for both Hermes and OpenClaw.
- **Goal and workflow features are converging** on the same few building blocks: a goal loop with a
  judge, timed loops, heartbeats, cron, and a task board. A **UI that shows and manages these
  across agents** (a dashboard, or a browser extension that turns a tab into a goal or task card)
  is under-served.
- **The skill ecosystem is fragmented** (agentskills.io, ClawHub, Goose recipes). Tools that
  translate, lint or score skills across these formats are an opening.

## Sources

- Hermes Agent repo & docs (`website/docs/user-guide/features/{goals,loops,heartbeat,kanban,memory-providers}.md`): https://github.com/NousResearch/hermes-agent
- https://openalternative.co/blog/best-open-source-ai-agents
- https://dev.to/sonotommy/10-best-open-source-ai-agents-for-2026-2l6p
- https://clawtank.dev/blog/best-open-source-ai-agents-2026
- https://www.vellum.ai/blog/best-open-source-personal-ai-assistants
- https://huggingface.co/spaces/nikhtu10/OpenClawBot/blob/main/docs/concepts/memory.md (OpenClaw memory docs mirror)
- https://www.neura.market/ai-agents/integrations/open-claw/docs/cli/memory
- https://vectorize.io/articles/mem0-vs-letta
- https://toolhalla.ai/compare/letta-vs-openclaw
