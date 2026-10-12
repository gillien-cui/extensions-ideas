# Hermes Agent vs OpenClaw — Memory Layer Deep Dive

> Follow-up to `hermes-agent-101.md` and `hermes-agent-alternatives.md`. Sources: each project's
> own docs, read from fresh clones of the source repos. Hermes: `NousResearch/hermes-agent`,
> `website/docs/user-guide/features/memory*.md`, as of 2026-10-06. OpenClaw: `openclaw/openclaw`,
> `docs/concepts/memory*.md`, `dreaming.md`, `active-memory.md`, `session-search.md`, as of 2026-10-12.

## TL;DR

The two projects take opposite approaches to memory:

- **Hermes keeps memory small and has the agent curate it.** It stores two hand-curated files
  (~1,300 tokens in total) that are always in the prompt. Everything else is found with **keyword
  search** over raw past sessions. Its "learning" goes mostly into **skills** (procedures), not into
  facts. If you want search by meaning, you plug in an external provider (Mem0, Honcho, Hindsight,
  OpenViking…).
- **OpenClaw keeps a lot of memory and processes it in the background.** Notes are written freely
  to daily Markdown files. **Hybrid search** finds them (vector + BM25 keywords, then ranking by
  recency, importance and diversity). A scheduled job called **"dreaming"** decides which items get
  promoted into long-term memory. It also has a separate recall agent for "what did we decide last
  month?" questions, plus provenance tracking and a `forget` command. Search by meaning works out of
  the box.

If **remembering facts and finding them again** is what matters, OpenClaw's memory layer is more
complete. If you want **a small, predictable, cheap context** and an agent that gets better
at *procedures* over time, Hermes' approach is the better fit.

---

## 1. Side-by-side

| Dimension | **Hermes Agent** | **OpenClaw** |
|---|---|---|
| **Storage** | `~/.hermes/memories/MEMORY.md` + `USER.md` (plain text, `§`-separated entries). Sessions live in `state.db` (SQLite). | Workspace Markdown: `USER.md`, `MEMORY.md`, `memory/YYYY-MM-DD[-slug].md` daily notes, `DREAMS.md`. Index and state live in SQLite. |
| **Always-in-prompt memory** | Both files, **hard-capped**: 2,200 + 1,375 characters (~1,300 tokens). Loaded once per session and never changed mid-session (keeps the prompt cache valid). | `USER.md` + `MEMORY.md` + today's and yesterday's daily notes, loaded at session start. `MEMORY.md` is **soft-capped**: if it is too big, only the copy injected into the prompt is cut; the file on disk is untouched. |
| **How things get saved** | The agent calls the `memory` tool (add/replace/remove) **plus** a background self-review every N turns (`memory.nudge_interval`) that may save facts or skills. | The agent writes notes as it works **plus** an automatic **memory flush**: before old context is summarised away, a hidden turn asks the agent to save what matters into the daily note. It may only append new text; duplicated text is rejected. |
| **When memory is full** | The `memory` tool **returns an error**. The agent must merge or delete entries in the same turn. Nothing is dropped silently. | The full file stays on disk. Old material is pushed down into `memory/*.md`, and dreaming condenses `MEMORY.md`. |
| **Consolidation** | None for facts; the agent edits them by hand. A **Curator** handles *skills* only (active → stale → archived). | **Dreaming** (on by default, cron-driven) in three phases: *light* (sort and stage), *REM* (reflect on themes), *deep* (score candidates on score, how often recalled and how many different queries hit them; then merge or replace against `MEMORY.md`). Writes a human-readable diary to `DREAMS.md`. Promoted entries get `trigger` and `importance` tags. |
| **Search by meaning (built in)** | ❌ None. | ✅ `memory_search`: hybrid **vector + BM25**, plus filename search → weighted merge → recency decay + importance + project affinity → **MMR** (removes near-duplicate results). Uses SQLite FTS5 + optional sqlite-vec. 11 embedding providers, including **local** llama.cpp/Ollama/LM Studio (no API key needed). |
| **Search over past conversations** | `session_search`: **FTS5 keyword** search over every past session, ~20 ms, **no LLM calls**, returns the raw messages; can scroll within a session. | `sessions_search` + `sessions_history` (keyword search, then open the matched passage). Transcripts can **also** be indexed into `memory_search` (meaning-based). |
| **Deep / multi-step recall** | None built in (Hindsight's `hindsight_reflect` via plugin). | **Active Memory**: a recall agent that runs only when a message asks about the past and the cheap search found nothing strong. Aimed at time-based and multi-session questions (cites the LongMemEval benchmark). |
| **User model** | `USER.md` (agent-curated). Optional **Honcho** plugin builds a deeper user model. | `USER.md` written as instructions, with observed-date and active/superseded labels; outdated entries are marked superseded in place. Optional Honcho plugin. |
| **Structured knowledge** | **Skills** (`SKILL.md` + `references/`), including `/learn` turning a book or docs into a knowledge-base skill. | **memory-wiki** plugin: a wiki of structured claims with evidence, contradiction and freshness checks, dashboards, Obsidian-friendly. |
| **Safety / governance** | Writes are **scanned** for prompt injection, credential exfiltration and invisible Unicode before they are accepted. Optional `write_approval` holds writes (including background-review writes) for `/memory approve`. Memory is separate per profile. | **Taint gating**: untrusted or system-generated items never reach consolidation. Admission policy excludes chosen channels or sources. Content is redacted before transcripts are ingested. **`memory forget`** uses provenance to delete memories that came from specific sessions. Notes can record "action-sensitive" boundaries (approvals, expiry). |
| **Pluggable backends** | 1 external provider at a time **added on top of** the built-in files: Honcho, Mem0, Supermemory, Hindsight, OpenViking, RetainDB, ByteRover, Holographic. | Replaceable memory **engine**: builtin (SQLite) by default; Honcho; LanceDB (auto-recall and auto-capture). memory-wiki can be layered alongside. |
| **Migration** | `hermes claw migrate` imports OpenClaw's `SOUL.md`, `MEMORY.md`, `USER.md` and skills. | Control UI → **Import Memory** from Codex, Claude Code **and Hermes** (into `memory/imports/hermes/`, searchable but not merged into `MEMORY.md`). |
| **Token cost per turn** | Low and fixed (~1.3k tokens). | Higher and variable (bootstrap files + daily notes + any search results pulled in). Active Memory adds a blocking model call when it escalates. |

## 2. How each one "saves a memory"

**Hermes**
```text
turn → (agent decides) memory.add("User's API lives at ~/code/myapi")
        → security scan → [write_approval? stage : write] → MEMORY.md on disk
every N turns → background copy of the agent reviews the chat → may save memory or create/patch a skill
next session → files loaded into the system prompt (unchanged for the whole session)
recall of anything else → session_search (FTS5 keyword) over state.db
```

**OpenClaw**
```text
turn → agent writes notes into memory/2026-10-12.md as it works
context nearly full → hidden "memory flush" turn → append-only save to the daily note → summarise old context
always → chunk + embed + BM25-index all memory files (and optionally transcripts)
cron (dreaming) → light → REM → deep: score/gate → model merges into MEMORY.md → DREAMS.md diary
recall → memory_search (hybrid + recency/importance/MMR) → if weak and about the past → Active Memory recall agent
```

## 3. Strengths & weaknesses

**Hermes — strengths**
- Predictable and cheap. The memory cost per turn is fixed, and the prompt cache is never broken.
- Errors when full instead of truncating silently. Easy to inspect: `cat` two small files.
- Security scanning on writes, plus an optional approval gate.
- What it learns turns into **reusable skills** (how to do things), which a plain fact store can't do.

**Hermes — weaknesses**
- **No built-in search by meaning.** Recall depends on keyword matches over raw sessions.
- A ~1.3k-token budget is tight for a long-lived assistant. Facts that are cut have to be rediscovered.
- Relies on the model actually calling the tool. The docs warn that small models (< ~30B) claim to
  have saved something without doing it.
- New memories only appear after `/new`, which is easy to forget on chat platforms.

**OpenClaw — strengths**
- A complete retrieval stack out of the box: hybrid search, local embedding options, MMR, recency and importance.
- Background consolidation (dreaming) with **human-reviewable** diaries and preimages for rollback.
- Deep-recall agent for time-based and multi-session questions.
- The most developed governance: provenance, taint gating, admission policy, `forget`.

**OpenClaw — weaknesses**
- Much more complexity: many settings and plugins, schema migrations, index rebuilds.
- Higher and less predictable token and latency cost per turn.
- Needs an embedding provider for search by meaning. Without one it falls back to keyword search.
- By default, session-tool visibility is `"all"`, which lets one agent search other agents' or users'
  conversations on the same gateway. Tighten `tools.sessions.visibility` if several people share one.

## 4. Which to pick (memory-only lens)

| If you want… | Pick |
|---|---|
| A long-lived personal assistant that recalls months of facts and decisions | **OpenClaw** |
| Search by meaning with zero extra services (local embeddings) | **OpenClaw** |
| Audit and deletion of what was learned from which conversation | **OpenClaw** |
| Minimal, predictable context cost; an agent that improves at *tasks* | **Hermes** |
| Choose your own memory vendor (Mem0, Hindsight, Honcho…) on top of a simple core | **Hermes** |
| Both | Hermes + a vector provider plugin (Mem0, Hindsight or OpenViking) gets close to OpenClaw's recall. You can also run OpenClaw and import Hermes memory into it. |

## 5. Product-idea angles

- **A shared memory layer for both agents:** an MCP server or plugin that gives Hermes
  OpenClaw-style hybrid search (vector + BM25 + MMR, local embeddings) and exports in both file
  layouts.
- **A memory viewer and editor:** a UI or browser extension to inspect and edit `MEMORY.md`/`USER.md`
  and daily notes, approve staged writes, and see what got promoted and why (Hermes `/memory
  pending`, OpenClaw `DREAMS.md`).
- **"Memory lint":** detect contradictions, outdated facts and secrets across agent memory files. It
  would work for Hermes, OpenClaw, Claude Code and Codex, since all of them use Markdown memory.
