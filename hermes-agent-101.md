# Hermes Agent — 101

> Research notes on **Hermes Agent** by Nous Research. Sources: the project's GitHub repo
> (`NousResearch/hermes-agent`, read at commit `cbffbeec`, 2026-10-06) and its developer docs.

## TL;DR

Hermes Agent is an **open-source (MIT), self-hosted, general-purpose personal AI agent**. It works
with whatever model you choose (300+ models through Nous Portal, OpenRouter, OpenAI, Anthropic, or a
local or custom endpoint). It has real tools: a terminal, files, a browser, web search, code
execution and MCP servers. You can reach it from a terminal UI, a desktop app, an IDE, or chat apps
like Telegram, Discord, Slack and WhatsApp.

What sets it apart is the **learning loop**: Hermes writes its own notes about you and your setup,
turns hard tasks it has solved into reusable "skills", searches its past conversations, and has a
background "curator" that prunes and merges those skills over time.

In short, it is closer to a persistent assistant that lives on a server than to a coding CLI you run
for one task. Claude Code and Codex are the coding CLIs; Hermes sits nearer to OpenClaw, and it
ships an `hermes claw migrate` command to import OpenClaw setups.

---

## 1. What you can do with it

| Use case | How |
|---|---|
| **Chat + do real work in a terminal** | `hermes` opens a terminal UI. The agent can run shell commands, edit files, browse the web and run code. |
| **Talk to it from your phone** | `hermes gateway setup && hermes gateway start` → message it on Telegram, Discord, Slack, WhatsApp, Signal, Email, Matrix, Teams and others (about 20 platforms). It transcribes voice memos. Conversations carry across platforms. |
| **Scheduled automations** | Built-in cron, set up in plain language ("every morning at 8, summarise my inbox and send it to Telegram"). Each run starts a fresh agent, can attach skills, and delivers the result to any platform. |
| **Long-running personal assistant** | It keeps memory about you (`USER.md`) and your environment (`MEMORY.md`) across sessions, and can search all past sessions (SQLite full-text search + LLM summarisation). |
| **Teach it things** | `/learn <pdf / url / folder>` turns a book, a spec or a docs folder into a knowledge-base skill it can load when needed. |
| **Reusable workflows** | Every skill is a slash command: `/github-pr-workflow`, `/excalidraw`, and so on. You can stack up to 5 in one message. Skills follow the open **agentskills.io** standard, and there is a public Skills Hub. |
| **Parallel / delegated work** | It can spawn isolated subagents for parallel work. It can also write Python scripts that call its tools over RPC, so a multi-step pipeline runs in one turn without filling the context. |
| **Run it somewhere other than your laptop** | 7 terminal backends: local, Docker, SSH, Singularity, Modal, Daytona, Vercel Sandbox. Modal and Daytona environments sleep when idle, so it costs almost nothing between uses. The README pitches it as running on a "$5 VPS". |
| **IDE agent** | An ACP adapter lets VS Code, Zed and JetBrains use it as the coding agent. |
| **Extend it** | Connect any MCP server, write plugins (memory providers, model providers, image generation, web search, platforms, and more) or write skills. |
| **ML research** | Batch trajectory generation and trajectory compression, used to build training data for tool-calling models (Nous trains the Hermes model family). |

### Getting started

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash   # Linux/macOS/WSL2
# Windows: iex (irm https://hermes-agent.nousresearch.com/install.ps1)
hermes setup            # wizard (or: hermes setup --portal for one Nous subscription)
hermes                  # start chatting
hermes model            # switch provider/model, no code changes
hermes tools            # enable/disable toolsets
hermes gateway start    # messaging bots
hermes doctor           # diagnose issues
```

Handy in-chat commands: `/new`, `/model`, `/personality`, `/retry`, `/undo`, `/compress`, `/usage`,
`/skills`, `/plan`, `/stop`.

**Tip from the docs:** run `/new` at natural break points. Memory is loaded as a fixed snapshot at
session start, so new memories and past-session recall only take effect once a new session begins.
This matters most on chat platforms, where one conversation can otherwise run for weeks.

---

## 2. How it's built

### Stack

- **Python ≥ 3.11** for the core (agent loop, CLI, gateway, tools, cron). It uses `uv` and its own
  `pm` environment manager.
- **TypeScript**: an Ink-based terminal UI (`ui-tui/`), an **Electron desktop app**
  (`apps/desktop/`), a web dashboard (`web/`) and a Docusaurus docs site.
- **SQLite + FTS5** for session storage and search (`hermes_state*.py`).
- About 25,000 tests across about 1,250 files. Some code-size limits are enforced in CI: functions
  ≤ 300 lines, files ≤ 2,000 lines.

### Architecture at a glance

```text
 Entry points:  CLI (cli.py) · TUI · Desktop · Gateway (gateway/run.py) · ACP (IDE) · API server · Python lib
                                   │
                                   ▼
                      AIAgent  (run_agent.py → agent/turn_*.py)
        ┌──────────────┬───────────────────┬────────────────────┐
        │ Prompt       │ Provider runtime  │ Tool dispatch      │
        │ builder      │ 3 API modes:      │ model_tools.py +   │
        │ (+ memory,   │ chat_completions, │ tools/registry.py  │
        │  skills idx) │ codex_responses,  │ 70+ tools,         │
        │              │ anthropic_messages│ 28 toolsets        │
        └──────┬───────┴─────────┬─────────┴─────────┬──────────┘
               │ compression &   │ fallback models,  │
               │ prompt caching  │ retries           │
               ▼                                     ▼
   Session store (SQLite+FTS5)          Tool backends: terminal (7), browser (5),
   ~/.hermes/ (config, memories,        web (4), MCP (dynamic), files, vision,
   skills, logs, profiles)              code exec, delegation, cron …
```

### The agent loop (`AIAgent`)

A standard tool-calling loop:

1. Add the user message → build the system prompt, or reuse the cached one.
2. If the context is more than about 50% full, compress it first.
3. Convert the conversation history to the provider's format. Internally everything uses
   **OpenAI-style messages**. Separate adapters handle the Anthropic Messages API and the OpenAI
   Responses API.
4. Make an **interruptible** API call. It runs on a background thread, so a new message or `/stop`
   abandons it cleanly.
5. If the model asked for tools → run them (several at once in a thread pool; interactive tools
   like `clarify` run one at a time) → add the results → go back to step 3. If the model replied
   with text → save the session, write memory if needed, and return.

Two design rules shape most of the code (from `AGENTS.md`):

- **Never break the prompt cache.** The system prompt, toolset and memory snapshot stay fixed for a
  whole conversation. Changes wait for the next session. Context compression is the only exception.
- **Keep the core small; add features at the edges.** Every tool schema is sent on every API call,
  so new features should arrive as a skill, a plugin, an MCP server or a CLI command, not as a new
  core tool.

### The learning loop (the "self-improving" part)

| Piece | What it is |
|---|---|
| **Memory** | Two small files in `~/.hermes/memories/`: `MEMORY.md` (≈2,200 characters: facts about the environment, conventions) and `USER.md` (≈1,375 characters: your preferences). The agent edits them itself with a `memory` tool. They are capped on purpose: when one is full, the agent has to merge or remove entries. |
| **Nudges** | Every so often, a background copy of the agent (with its own cache) reviews the conversation and decides whether to save memories or write a skill. The interval is configurable (`memory.nudge_interval`, `skills.creation_nudge_interval`). |
| **Skills** | Markdown `SKILL.md` + `references/` folders in `~/.hermes/skills/`. They load in stages to save tokens: first a list of names, then the full skill, then individual reference files. The agent creates and patches skills with the `skill_manage` tool. An approval gate is available. |
| **Curator** | A background job that runs when the agent is idle (default: every 7 days). Agent-made skills go `active → stale (14 days unused) → archived (30 days)`. An auxiliary model proposes merges and fixes. It never deletes anything; archived skills can be restored. |
| **Session search** | Full-text search (SQLite FTS5) over all past sessions, with LLM summaries, for recall across sessions. |
| **Honcho (optional)** | A plug-in user model from Plastic Labs that builds a profile of the user through question-and-answer. |

### Gateway (messaging)

A single process runs every platform adapter. The message flow is:
platform event → adapter → `MessageEvent` → **authorise** (DM pairing, allowlists) → resolve the
session → `AIAgent.run_conversation()` → deliver the reply through the adapter. **Profiles** keep
memory, skills and config separate for different personas or bots. One process can serve several
profiles.

### Safety model

Dangerous commands need approval (`tools/approval.py`). There is DM pairing for chat bots and
container isolation through the Docker, Modal and Daytona backends. Memory and skill writes can be
held for approval. Secrets go only in `.env`; everything else goes in `config.yaml`. Your data stays
on your machine and the docs say there is no telemetry.

---

## 3. Key takeaways (for our product ideas)

- **What makes it hard to copy:** memory and skills that persist and improve over time, plus being
  always on through messaging apps. That is not a coding CLI.
- **Patterns worth borrowing:** memory files with a hard size cap (forces the agent to curate);
  skills that load in stages; a background "curator" so self-written skills don't pile up; keeping
  the prompt fixed per session for caching; and adding features as skills, plugins or MCP servers
  rather than core tools.
- **Ecosystem gaps that could become products:** skills and plugins for the agentskills.io Hub,
  new MCP servers, platform adapters, a hosted "Hermes on a VPS" setup, browser-extension bridges
  (e.g. sending the current page or tab to your Hermes instance).
- **Known weak spot (from its own docs):** small or local models (< ~30B) often *say* they saved a
  memory without actually calling the tool. The learning loop needs a model that is good at tool
  calling.

## Links

- Repo: https://github.com/NousResearch/hermes-agent
- Docs: https://hermes-agent.nousresearch.com/docs/
- Architecture: https://hermes-agent.nousresearch.com/docs/developer-guide/architecture
- Skills standard: https://agentskills.io
