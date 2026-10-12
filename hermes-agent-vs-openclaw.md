# Hermes Agent vs OpenClaw — Full Comparison

> Companion to `hermes-agent-101.md`, `hermes-agent-alternatives.md` and
> `hermes-agent-vs-openclaw-memory.md` (the memory deep dive).
> Sources: fresh clones of both repos and their bundled docs. Hermes: `NousResearch/hermes-agent`
> @ `cbffbeec` (2026-10-06). OpenClaw: `openclaw/openclaw` @ `856ae491` (2026-10-12, v2026.10.1).
> Both projects change quickly; counts below are approximate.

## TL;DR

They cover very similar ground: a self-hosted personal agent with a gateway to chat apps, any
model, tools, skills, memory, cron and sub-agents. **Each has copied the other's best ideas**, so
the gap is narrower than older blog posts suggest. Hermes now does chat channels; OpenClaw now has
self-learning skills and `/goal`.

| | **Hermes Agent** | **OpenClaw** |
|---|---|---|
| **One-liner** | "The agent that grows with you": a self-improving agent built around a **learning loop**. | "The AI that actually does things": a **gateway/control plane** connecting your devices and chats. |
| **Center of gravity** | The agent loop, skills, research/training data | The gateway, channels, devices, plugins, teams |
| **Pick it if…** | You want a lean core, cheap and predictable context, strong goal/kanban workflows, and many places to run code (incl. serverless) | You want the widest channel and device reach, native apps, strong memory retrieval, team deployments, and the biggest ecosystem |

---

## 1. Project & governance

| | Hermes Agent | OpenClaw |
|---|---|---|
| Maintainer | **Nous Research** (an AI lab that also trains the Hermes models) | **OpenClaw Foundation**, an independent 501(c)(3) that employs the core team. OpenAI is a donor, not an owner. |
| Origin | Released early 2026. Ships `hermes claw migrate` to pull users over from OpenClaw. | Peter Steinberger's personal project: Warelay → Clawdbot → Moltbot → OpenClaw. The original "claw" agent. |
| License | MIT | MIT |
| Business model | Free; optional paid **Nous Portal** subscription (300+ models + a gateway for web search, image generation, TTS and browser in one plan) | "No paid tier, hosted service, or token" |
| Telemetry | None | A daily version check; anonymous feature stats are **opt-in**. Both can be turned off. |
| Ecosystem | agentskills.io Skills Hub, plugin catalog | **ClawHub** (skills and plugins), the larger community. Many third-party "claw" forks (NanoClaw, etc.). |

## 2. Architecture & tech stack

| | Hermes Agent | OpenClaw |
|---|---|---|
| Core language | **Python 3.11+** (uv / own `pm` env manager) | **TypeScript on Node 24/26** (pnpm monorepo) |
| UIs | Ink TUI, Electron desktop app, web dashboard | Control UI (web), CLI, TUI, **native companion apps for macOS, iOS, Android, Windows and Linux** |
| Agent loop | `AIAgent` (OpenAI-format messages; adapters for Anthropic and the OpenAI Responses API); **3 API modes** | Own runtime, `@openclaw/agent-core` (originally built on Mario Zechner's *pi*). **Swappable "harnesses"**: you can run the Codex or Claude harness in place of the built-in loop. |
| Shape | Agent-centric: CLI, gateway, cron, ACP and the API all create an `AIAgent` | Gateway-centric: one long-running **Gateway** is the control plane for sessions, tools, events, channels and devices ("nodes") |
| Design rule | "Prompt caching is sacred"; small core, features at the edges | "Trusted gateway, untrusted execution, deterministic policy"; lean core, everything else in plugins |
| Code organisation | `facade + siblings` modules; CI limits on function and file size; ~25k tests | ~175 extensions in `extensions/` (providers, channels, memory, tools all as plugins); plugin SDK |
| Install | `curl …/install.sh \| bash` / PowerShell / Termux APT / Docker / Nix | `curl openclaw.ai/install.sh \| bash` / PowerShell / `npm i -g openclaw` → `openclaw onboard --install-daemon` |

## 3. Models

| | Hermes Agent | OpenClaw |
|---|---|---|
| Providers | ~40 provider plugins + any OpenAI-compatible endpoint; Nous Portal (300+ models); OpenRouter, Anthropic, OpenAI, local | ~70 provider docs: OpenAI, Anthropic (incl. Vertex/Bedrock), Google, xAI, Mistral, DeepSeek, Qwen, Groq, Cerebras, OpenRouter, LiteLLM, Vercel AI Gateway, Ollama, LM Studio, vLLM, SGLang, llama.cpp, Apple Foundation Models… |
| Switching | `hermes model`, `/model provider:model` mid-chat | `/model`, per-agent and per-sub-agent models |
| Fallbacks | Fallback provider chain, credential pools | Model fallback chains, auth profiles |
| Subscription logins | Nous Portal OAuth | Uses **existing subscriptions** where allowed (Codex OAuth, GitHub Copilot, Claude harness) |

## 4. Where you talk to it

| | Hermes Agent | OpenClaw |
|---|---|---|
| Chat channels | ~20+: Telegram, Discord, Slack, WhatsApp, Signal, Matrix, Mattermost, Email, SMS, Teams, Google Chat, IRC, LINE, Feishu, DingTalk, WeCom, WeChat, QQ, BlueBubbles/iMessage, Home Assistant… | ~30+: all of those plus **native iMessage**, Twitch, Nostr, X, Zalo, Nextcloud Talk, Synology Chat, Tlon, Yuanbao, **A2A** (agent-to-agent), Zoom / Google Meet / Teams meetings, voice calls, FaceTime |
| Devices | — | **Nodes**: phone and desktop apps provide camera, screen, location, HealthKit, Canvas, voice/talk mode and device-local actions |
| IDE | ACP adapter (VS Code, Zed, JetBrains) | ACP agents (`acpx`) |
| API | OpenAI-compatible API server, Python library, batch runner | Gateway RPC/HTTP APIs, `openclaw agent exec` for CI |
| Multi-user | Per-profile islands; DM pairing; one process can serve many profiles | **Team server** mode: shared Gateway, individual sign-in (Cloudflare Access), GitHub identity, operator roles, shared sessions with attribution |

## 5. Tools

| | Hermes Agent | OpenClaw |
|---|---|---|
| Built-in tools | 70+ tools in 28 toolsets: terminal, files/patch, web search/extract, browser, vision, image gen, TTS, `execute_code`, delegate, cron, memory, skills, MCP, computer use, kanban | exec, apply-patch, browser (+ **Chrome extension**, logged-in browser), web search (Brave, Exa, Tavily, Perplexity, SearXNG, DDG, Gemini, Grok, Kimi…), web fetch, PDF, image/music/video generation, TTS, screen, canvas, MCP, ask-user, diffs |
| Too many tools for the prompt | Toolsets you enable or disable per platform; **tool search** | **Code Mode**: the model sees only `exec` and writes JS against a hidden tool catalog. Plus **tool search**. |
| Scripted pipelines | `execute_code`: Python scripts call tools over RPC ("zero-context-cost turns") | **Lobster**: a typed pipeline DSL with approval checkpoints and resume tokens; Code Mode scripts |
| Where code runs | **7 terminal backends**: local, Docker, SSH, Singularity, **Modal**, **Daytona**, **Vercel Sandbox** (serverless sandboxes that sleep when idle) | Host by default; optional **sandbox** backends: Docker, Podman, SSH, OpenShell (+ sandboxed browser) |

## 6. Skills & self-improvement

| | Hermes Agent | OpenClaw |
|---|---|---|
| Skill format | `SKILL.md` + references; agentskills.io standard; every skill becomes a slash command; stack up to 5 at once | Skills (`SKILL.md`), ClawHub, skill bundles in package manifests |
| Self-written skills | ✅ **Core identity.** Background review "nudges" + `skill_manage`; `/learn` turns books or docs into knowledge-base skills; **Curator** marks skills stale and archives them (never deletes); `/journey` learning timeline | ✅ **Skill Workshop / Self-learning** (on by default): the foreground agent saves procedures and patches bad skills; a background review fills gaps; unused skills archived after 30 days; every change announced and **undoable** |
| Write gating | `skills.write_approval` | Undo + versioning |
| Verdict | Older, deeper loop (curator with LLM merging, `/learn`) | Caught up; stronger UX for undo and announcements |

## 7. Memory (summary; see the deep-dive file)

| | Hermes Agent | OpenClaw |
|---|---|---|
| Philosophy | Small, curated, hard-capped (~1.3k tokens), fixed for the session | Large, background-processed |
| Search by meaning | ❌ built in (keyword search only); ✅ through one provider plugin (Mem0, Honcho, Hindsight, OpenViking, Supermemory…) | ✅ built in: hybrid vector + BM25 + recency/importance + MMR; local embeddings possible |
| Consolidation | Agent edits by hand; nudges | **Dreaming** (light/REM/deep), `DREAMS.md` diary |
| Deep recall | — | **Active Memory** recall agent |
| Governance | Injection/exfiltration scan on writes; approval gate | Provenance, taint gating, admission policy, `memory forget` |
| Interop | Imports OpenClaw memory | Imports Hermes, Claude Code and Codex memory |

## 8. Automation, goals & multi-agent

| | Hermes Agent | OpenClaw |
|---|---|---|
| Goal loop | `/goal`: **a judge model** checks after each turn and auto-continues until done or out of budget | `/goal`: durable session goal with statuses (active/paused/blocked/budget-limited/complete), a **token budget**, model-facing goal tools, TUI footer |
| Scheduling | `hermes cron` (natural language, delivery to any platform) | Cron jobs, webhooks, IMAP triggers |
| In-session recurring | `/loop` (fixed or self-paced), `/heartbeat` | Heartbeat |
| Standing policy | Context files (`AGENTS.md`, `SOUL.md`) | **Standing orders**: permanent "programs" with scope, triggers, approval gates and escalation rules |
| Event-driven | Gateway hooks | Internal hooks, plugin hooks (`api.on`), **standing intents** (event-conditioned), webhooks |
| Sub-agents | `delegate_task` (runs in background by default); Mixture-of-Agents | Sub-agents (isolated sessions, configurable nesting, cheaper models); **Swarm** for big fan-out from Code Mode |
| Multi-agent board | ✅ **Kanban**: SQLite board across profiles, dependencies, review/handoff, worker processes, goal-mode cards | Multi-agent routing, agent-to-agent tools, A2A channel; no direct kanban equivalent found in docs |

## 9. Security

| | Hermes Agent | OpenClaw |
|---|---|---|
| Inbound messages | DM pairing, allowlists | DM pairing **by default** for unknown senders; access groups; bot-loop protection |
| Command execution | Detects dangerous commands and asks for approval; container backends | Exec approvals, permission modes, "elevated" mode, tool policy; sandbox **off by default** (tools run on the host for the main session) |
| Secrets | `.env` only, credential pools/vault | Secrets tool, 1Password plugin, vault plugin |
| Memory/skills | Injection scan, write approval | Taint gating, provenance, undo |
| Watch-outs | Two processes on one `HERMES_HOME` will corrupt memory; small models fake tool calls | Default `tools.sessions.visibility: "all"` (on a shared gateway, agents can search other users' sessions); host execution by default. Read the security guide before exposing the Gateway. |

## 10. Research / ML angle

Hermes is unique here. It does batch trajectory generation, trajectory compression and RL/eval
environments, and is used to train Nous' own tool-calling models. OpenClaw has trajectory export
and a QA lab, but it is not a research platform.

---

## 11. Scorecard (subjective, 1–5)

| Area | Hermes | OpenClaw |
|---|---|---|
| Ease of setup | 4 | 4 |
| Model breadth | 4 | 5 |
| Channel / device reach | 4 | **5** |
| Tool breadth | 4 | **5** |
| Places to run code / sandboxing | **5** | 4 |
| Self-improving skills | **5** | 4 |
| Fact memory & retrieval | 3 (5 with a plugin) | **5** |
| Goals / workflows / multi-agent | **5** (goal judge + kanban) | 4 (standing orders, swarm) |
| Team / multi-user | 3 | **5** |
| Cost predictability | **5** | 3 |
| Ecosystem / community size | 3 | **5** |
| Simplicity of codebase | **4** | 3 |

## 12. Recommendation

- **Solo power user who wants one agent that gets better at *your* tasks, runs cheaply on a VPS or
  serverless, and coordinates work through goals and kanban → Hermes.**
- **Someone who wants an assistant everywhere (phone, iMessage, meetings, desktop), with strong
  long-term recall, or a shared team assistant → OpenClaw.**
- Switching is cheap either way: `hermes claw migrate` imports OpenClaw, and OpenClaw's
  `migrate-hermes` / Import Memory imports Hermes.

## 13. Product-idea angles for this repo

1. **Cross-agent browser extension:** "send this tab, selection or form to my agent", with a
   switchable backend (Hermes API server / OpenClaw Gateway RPC). Neither project owns this well;
   OpenClaw's Chrome extension controls the browser *for* the agent, not the other way round.
2. **Universal skill converter and linter:** agentskills.io ↔ ClawHub ↔ Claude Code skills, scored
   for quality and safety.
3. **Agent ops dashboard:** goals, cron, kanban or standing orders, memory diffs and token spend,
   across both agents.
4. **Memory interop service:** hybrid search as a service, plus a memory-file editor and linter
   (see the memory deep-dive file).
