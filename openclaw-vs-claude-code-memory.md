# OpenClaw vs Claude Code — Memory Layer

> Follow-up to `hermes-agent-vs-openclaw-memory.md`. Sources: OpenClaw docs in `openclaw/openclaw`
> @ `856ae491` (`docs/concepts/memory*.md`, `dreaming.md`, `active-memory.md`); Claude Code docs
> at https://code.claude.com/docs/en/memory (fetched 2026-10-12).

## TL;DR

**Claude Code's memory is project instructions plus a notebook.** It is plain Markdown that Claude
reads with its normal file tools. There is no embedding index and no background consolidation, and
it is scoped to *one repo*. That fits a coding agent: most of what it needs is in the codebase.

**OpenClaw's memory is a retrieval system.** It indexes Markdown files with hybrid vector + BM25
search, promotes notes on a schedule ("dreaming"), escalates hard questions to a recall agent, and
tracks where each memory came from. It is scoped to a *person or agent* across every chat channel.
That fits a personal assistant that has to recall months of life admin.

They are built for different jobs. They do **interoperate**: OpenClaw's *Import Memory* copies
Claude Code's `~/.claude/projects/*/memory` files into `memory/imports/claude-code/` and indexes
them for `memory_search`. OpenClaw can also run Claude Code itself (CLI backend / ACP).

---

## 1. Side-by-side

| | **Claude Code** | **OpenClaw** |
|---|---|---|
| **Main unit** | A **repository/project** | A **person/agent** (one workspace for every channel) |
| **Human-written layer** | `CLAUDE.md` in layers: managed policy (org) → `~/.claude/CLAUDE.md` (user) → `./CLAUDE.md` (project, in git) → `CLAUDE.local.md` (personal). `@imports` (up to 4 levels), `.claude/rules/` with **path-scoped** rules, `AGENTS.md` support, per-subdirectory `CLAUDE.md` loaded when Claude touches that folder | `AGENTS.md`, `SOUL.md`, `USER.md` and other workspace bootstrap files; **standing orders** |
| **Agent-written layer** | **Auto memory**: `~/.claude/projects/<repo>/memory/` = a `MEMORY.md` **index** (one line per memory) + one topic file per memory, with a `type` field: `user`, `feedback`, `project`, `reference` | `MEMORY.md` (curated long-term) + `memory/YYYY-MM-DD.md` **daily notes** + `USER.md` (directives with observed dates and active/superseded status) + `DREAMS.md` |
| **What it chooses not to save** | Anything it can work out from the code or git history; anything already in CLAUDE.md | Untrusted or system-generated items are kept out of promotion (taint gating); admission policy excludes chosen sources |
| **Loaded at session start** | All CLAUDE.md files in the folder path + rules + first **200 lines / 25 KB** of `MEMORY.md`. Topic files are **not** loaded; Claude opens them when needed. | `USER.md` + `MEMORY.md` (cut to fit the bootstrap budget) + today's and yesterday's daily notes |
| **Size control** | Warns when `MEMORY.md` nears its limit; an error tells Claude to rewrite the index when over. CLAUDE.md warns past ~200 lines; files over 4 MiB are skipped. | Prompt copy is cut, the file on disk is kept; dreaming condenses it; `/context detail` shows what was cut |
| **How it finds things** | **No search engine.** The index line points to a topic file, which Claude opens with Read, Grep or Glob. Exact text matching only. | `memory_search`: **hybrid vector + BM25** + filename search → recency decay, importance, project affinity → MMR diversity. 11 embedding providers, including local llama.cpp, Ollama, LM Studio. |
| **Past conversations** | Transcripts are saved per project and can be reopened with `/resume`, `--continue`, `/rewind`. They are not searched as memory. Deleted after `cleanupPeriodDays`; memory files are exempt. | `sessions_search` + `sessions_history`. Transcripts can also be **indexed into `memory_search`** and fed into dreaming (redacted). |
| **Deep recall** | — | **Active Memory**: a blocking recall sub-agent when a question is about the past and the quick search found nothing strong |
| **Consolidation** | Claude tidies the index itself (merge or drop stale entries) when nudged by the size limit. Adds a `modified` timestamp to the frontmatter on each write. | **Dreaming** cron (light → REM → deep): score and gate candidates, model-led merge or supersede into `MEMORY.md`, diary in `DREAMS.md`, preimages kept for rollback |
| **Before old context is summarised** | The project-root CLAUDE.md is **re-read from disk** after `/compact`; nested files and path rules reload when needed. Anything said only in conversation is lost unless saved. | A hidden **memory-flush** turn saves important context to the daily note *before* summarisation (append-only, rejects duplicates) |
| **Sharing / teams** | `CLAUDE.md` is committed to git (team-shared). The managed-policy file covers the whole org. Auto memory stays **on one machine**, but is shared across worktrees of the same repo. Sub-agents can have their own memory directory. | One workspace per agent. Shared Gateway / team server with session-visibility rules. `memory-wiki` plugin for a shared knowledge base. |
| **Control & deletion** | Plain files: `/memory` to browse, edit, toggle; `/context` shows what loaded; `autoMemoryEnabled`, `autoMemoryDirectory`, `CLAUDE_CODE_DISABLE_AUTO_MEMORY`; `InstructionsLoaded` hook for debugging. **Hooks** for anything that must be enforced. | Files + SQLite index; provenance tracking; `openclaw memory forget --session … --dry-run`; admission policy; `memory index`, `openclaw doctor` |
| **Pluggable backends** | No (files only; MCP memory servers can be added as tools) | Yes: builtin SQLite, Honcho, LanceDB; `memory-wiki` alongside |
| **Infra needed** | None | None for keyword search; an embedding provider (API or local) for search by meaning |
| **Token cost** | Predictable: CLAUDE.md + ≤25 KB index; topic files only when read | Higher and variable; Active Memory adds a model call when it escalates |

## 2. Same idea, different execution

Both use **Markdown files you can open and edit**, with a **small always-loaded index or summary**
and **detail kept in other files**. The difference is how the detail gets found again:

```text
Claude Code:  MEMORY.md index line ──(Claude decides)──▶ Read topic file
OpenClaw:     query ──▶ embed + BM25 ──▶ rank (recency/importance/MMR) ──▶ snippets
                         └─ weak & about the past ──▶ Active Memory recall agent
```

Claude Code relies on the model's judgement and a well-kept index. OpenClaw relies on a retrieval
system plus background curation.

## 3. When each approach wins

| Situation | Better fit |
|---|---|
| Coding conventions, build commands, "don't do X in this repo" | **Claude Code**: git-shared, scoped to paths, team-reviewed. OpenClaw's own docs say codebase knowledge belongs in the repo's `AGENTS.md`, not in memory. |
| Org-wide policy for many developers | **Claude Code** (managed-policy CLAUDE.md) |
| "What did we decide about the Berlin trip in March?" | **OpenClaw** (search by meaning + time-aware recall) |
| Hundreds of notes built up over months | **OpenClaw**: Claude Code's 200-line index would become the bottleneck |
| Zero setup, predictable cost, easy to audit | **Claude Code** |
| Deleting what was learned from a specific conversation | **OpenClaw** (`memory forget`) |

## 4. Using both together

- Run Claude Code **inside** OpenClaw (`/acp spawn claude --bind here`). The repo's CLAUDE.md and
  Claude Code's auto memory still apply inside that session, while OpenClaw's memory handles the
  personal and assistant side.
- Use **Import Memory** in OpenClaw's Control UI so your Claude Code auto-memory notes become
  searchable from your phone or Discord.

## 5. Product-idea angles

- **Search by meaning for Claude Code memory:** an MCP server or plugin that indexes
  `~/.claude/projects/*/memory` and CLAUDE.md files with hybrid search, so the 200-line index
  limit stops mattering.
- **A cross-tool memory viewer:** one UI for Claude Code auto memory, OpenClaw `MEMORY.md`/daily
  notes/`DREAMS.md` and Hermes `MEMORY.md`/`USER.md`: diff, dedupe, flag outdated entries, scan
  for secrets.
- **A two-way sync:** promote recurring Claude Code `feedback` memories into the team's
  `CLAUDE.md` or rules through a pull request, and the reverse.
