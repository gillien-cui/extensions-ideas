# Claude Code: Agent SDK, Plugins, MCP and Connectors

This is a companion to `claude-code-features-productivity-guide.md`. It covers the parts that extend Claude Code beyond what it does out of the box: the **Agent SDK** for building your own agents, **plugins and skills** you can install, **MCP servers**, and the **connectors** on claude.ai.

> These ecosystems change fast. The names and repos below are the well-known ones as of 2026. Check `/plugin`, `/mcp` and https://code.claude.com/docs before relying on any one of them, and only install servers and plugins from sources you trust, because they run with your permissions.

---

## 1. Mind Map

```mermaid
mindmap
  root((Extending Claude Code))
    Agent SDK
      TypeScript: @anthropic-ai/claude-agent-sdk
      Python: claude-agent-sdk
      query() loop
      Custom tools as in-process MCP
      Hooks, subagents, permissions
      Sessions and resume
      Use cases: CI bots, support agents, internal tools
    Plugins
      /plugin marketplace
      Official: commit, PR review, feature-dev, security, hookify
      Output styles: explanatory, learning
      Community: superpowers, agent collections
      Your team's own marketplace
    Skills
      docx, pdf, pptx, xlsx
      skill-creator, mcp-builder
      webapp-testing, frontend-design
    MCP servers
      Code: GitHub, GitLab, Sentry
      Docs: Context7
      Browser: Playwright, Chrome DevTools
      Data: Postgres, Supabase, SQLite, BigQuery
      Work: Linear, Jira/Confluence, Notion, Slack
      Design: Figma
      Cloud: Cloudflare, Vercel, AWS, Stripe
      Search: Brave, Exa, Firecrawl
    Connectors on claude.ai
      Gmail, Calendar, Drive
      GitHub, Slack, Notion, Linear
      Asana, Atlassian, Figma, Canva
      Zapier for everything else
```

---

## 2. Claude Agent SDK

The **Claude Agent SDK** is the engine behind Claude Code packaged as a library. You get the same agent loop and tools (file read/edit, bash, search, web), plus context management, permissions, hooks and subagents, inside your own program.

| | |
|---|---|
| TypeScript | `npm install @anthropic-ai/claude-agent-sdk` |
| Python | `pip install claude-agent-sdk` |
| Auth | `ANTHROPIC_API_KEY` (also supports Bedrock, Vertex and similar providers) |
| Docs | https://docs.claude.com → Agent SDK |

### Minimal example (TypeScript)
```ts
import { query } from "@anthropic-ai/claude-agent-sdk";

for await (const msg of query({
  prompt: "Find TODOs in src/ and write a summary to TODO_REPORT.md",
  options: {
    allowedTools: ["Read", "Grep", "Glob", "Write"],
    permissionMode: "acceptEdits",
    systemPrompt: { type: "preset", preset: "claude_code" },
  },
})) {
  if (msg.type === "result") console.log(msg.result);
}
```

### Minimal example (Python)
```python
import anyio
from claude_agent_sdk import query, ClaudeAgentOptions

async def main():
    async for msg in query(
        prompt="Summarize failing tests in test-results.xml",
        options=ClaudeAgentOptions(allowed_tools=["Read", "Grep"]),
    ):
        print(msg)

anyio.run(main)
```

### Key capabilities
| Capability | What it gives you |
|---|---|
| **Built-in tools** | Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, Task (subagents) |
| **Custom tools** | Define functions as an in-process MCP server (`createSdkMcpServer` + `tool()` in TS, the `@tool` decorator in Python), so Claude can call your APIs |
| **External MCP** | Pass `mcpServers` to attach any MCP server |
| **Permissions** | `allowedTools`, `disallowedTools`, `permissionMode`, and a `canUseTool` callback to approve or deny each call in code |
| **Hooks** | The same events as the CLI (PreToolUse, PostToolUse, Stop…), registered as callbacks |
| **Subagents** | `agents` option: named specialists with their own prompt and tools |
| **Sessions** | Resume or fork a conversation by session id; streaming input for chat UIs |
| **Settings** | `settingSources` controls whether it loads CLAUDE.md, project settings and skills |
| **Output** | Streamed messages, a final `result` with cost and usage |

### What people build with it
- **CI/CD bots:** auto-fix lint, triage failing tests, write release notes. (`anthropics/claude-code-action` for GitHub Actions is built on it.)
- **Internal dev tools:** "migrate this API across 40 repos", codemods, dependency upgrades.
- **Support or ops agents:** read logs and dashboards through MCP, then open tickets.
- **Personal automation:** an inbox summarizer, a research assistant that writes markdown notes, a file organizer.
- **Product features:** an agent inside your own app, such as a chat panel that edits user documents.

> **Tip:** Prototype the workflow interactively in Claude Code first, turn it into a slash command or skill, and move it to the SDK only when it needs to run unattended or inside another product.

The headless CLI (`claude -p "…" --output-format json`) is a lighter option than the SDK for shell scripts.

---

## 3. Plugins

A **plugin** bundles slash commands, subagents, skills, hooks and MCP servers into one install.

```
/plugin                                   # browse and install interactively
/plugin marketplace add <owner/repo>      # add a marketplace (any git repo with a marketplace.json)
/plugin install <name>@<marketplace>
```

### Official and well-known plugins
These come from Anthropic's marketplace and the `anthropics/claude-code` repo. Names may change.

| Plugin | What it adds | Good for |
|---|---|---|
| **commit-commands** | `/commit`, commit + push + PR commands | Faster git workflow |
| **pr-review-toolkit** | Specialist review agents (tests, comments, types, error handling) | Thorough PR reviews |
| **code-review** | Automated PR review command | Review before merge |
| **feature-dev** | A guided explore → architect → implement → review workflow with agents | Building bigger features |
| **security-guidance** | A hook that warns about risky patterns while editing | Security checks as you code |
| **hookify** | Creates hooks from plain-English rules ("warn me when…") | Hooks without writing JSON |
| **frontend-design** | Guidance for distinctive, polished UI | Frontend work |
| **agent-sdk-dev** | Scaffolding and verification for Agent SDK apps | Starting an SDK project |
| **plugin-dev** | Tools for writing your own plugins | Building plugins |
| **explanatory / learning output styles** | Claude explains its choices, or leaves parts for you to write | Learning a codebase or language |

### Community favorites
- **obra/superpowers:** a large skills library (TDD, debugging, brainstorming, planning workflows).
- **Agent collections** such as `wshobson/agents`: dozens of ready-made subagents (language experts, DevOps, review).
- **Team marketplaces:** put your company's commands, agents and hooks in one repo, and everyone gets the same setup with one `marketplace add`.

---

## 4. Skills (Agent Skills)

Skills are folders with a `SKILL.md`. Claude loads one automatically when a task matches its description. They work in Claude Code, claude.ai and the API.

| Skill (`anthropics/skills`) | Use |
|---|---|
| **docx / pdf / pptx / xlsx** | Create and edit Office files and PDFs (forms, tables, charts) |
| **skill-creator** | Write and evaluate your own skills |
| **mcp-builder** | Build an MCP server step by step |
| **webapp-testing** | Test a local web app with Playwright |
| **frontend-design / canvas-design / algorithmic-art** | Visual output |
| **brand-guidelines / internal-comms** | Write in a house style |

**Making your own:** any checklist you follow repeatedly (release process, PR template, report format) is a good candidate. Ask: *"Use skill-creator to make a skill for X."*

---

## 5. MCP Servers: the most useful ones

**MCP (Model Context Protocol)** is an open standard that gives Claude tools for outside systems.

```bash
claude mcp add <name> -- <command> [args]                   # local (stdio) server
claude mcp add --transport http <name> <url>                # remote server
claude mcp add --scope project ...                          # shared via .mcp.json
/mcp                                                        # status, OAuth login, tool list
```

Scopes: `local` (just you, this project), `project` (`.mcp.json`, committed), `user` (you, every project).

### Coding and dev workflow
| Server | What Claude can do | Why it helps |
|---|---|---|
| **GitHub** (`github/github-mcp-server`, remote) | Issues, PRs, reviews, Actions logs, code search | Manage PRs and issues without leaving the terminal |
| **Context7** (Upstash) | Fetch current docs for libraries | Fewer hallucinated or outdated APIs. **Very popular.** |
| **Playwright** (Microsoft) | Drive a real browser: click, fill forms, screenshot | UI testing, checking visual changes, scraping |
| **Chrome DevTools** (Google) | Console, network and performance traces of a live page | Debug frontend bugs and performance |
| **Sentry** | Pull errors, stack traces, releases | "Fix the top Sentry error" |
| **GitLab / Bitbucket** | Same idea as GitHub | If you use those |

### Data
| Server | Use |
|---|---|
| **Postgres / SQLite / MySQL** | Inspect the schema and run queries (use a read-only user) |
| **Supabase / Neon / PlanetScale** | Manage projects, branches and migrations |
| **BigQuery / Snowflake** | Analytics questions in plain English |

### Project management and docs
| Server | Use |
|---|---|
| **Linear** | "Pick up ticket ENG-123, implement it, update the status" |
| **Atlassian (Jira + Confluence)** | Tickets and wiki pages |
| **Notion** | Read specs, write meeting notes and docs |
| **Slack** | Search threads, post summaries |
| **Asana / Monday** | Task tracking |

### Design, cloud and payments
| Server | Use |
|---|---|
| **Figma (Dev Mode MCP)** | Read frames, components and tokens, then build UI to match the design |
| **Cloudflare / Vercel / Netlify** | Deploys, logs, Workers, DNS |
| **AWS / GCP / Azure** | Cloud resources and docs |
| **Stripe** | Customers, payments, docs |

### Search and web
| Server | Use |
|---|---|
| **Brave Search / Exa / Tavily** | Web search with an API key |
| **Firecrawl** | Crawl and scrape whole sites into clean markdown |
| **Fetch** (reference server) | Turn a URL into markdown |

### General-purpose reference servers (`modelcontextprotocol/servers`)
**Filesystem** (access to dirs outside the project), **Memory** (knowledge graph), **Sequential Thinking**, **Git**, **Time**.

> **Tip:** Every MCP server's tool definitions take up context. Enable only what you use in a project (use project-scoped `.mcp.json`), and check `/context` if a session gets sluggish.

### Build your own MCP server
If your company has an internal API, wrap it in a small MCP server (the official SDKs are in TS, Python, Go and others, or use the `mcp-builder` skill). Then Claude Code, claude.ai and your Agent SDK apps can all use it.

---

## 6. Connectors (claude.ai / Claude apps)

**Connectors** are MCP servers that are already hosted and set up for the Claude apps (web, desktop, mobile, and cloud Claude Code sessions). You connect one with OAuth under **Settings → Connectors**, with no local install.

| Category | Connectors |
|---|---|
| Google | **Gmail, Google Calendar, Google Drive** (Docs/Sheets/Slides) |
| Dev | **GitHub**, Sentry, Vercel, Cloudflare |
| Work | **Slack, Notion, Linear, Asana, Atlassian (Jira/Confluence)**, Monday, Intercom |
| Design | **Figma, Canva** |
| Files | Box, Dropbox, OneDrive/SharePoint (Microsoft 365) |
| Business | Stripe, HubSpot, PayPal, Square |
| Glue | **Zapier**: thousands of apps through one connector |

**In this workspace:** Gmail, Google Drive and GitHub are already connected, so things like *"summarize unread email from this week"* or *"find my Q3 doc in Drive"* work now.

### Everyday combos
- **Morning brief:** Gmail + Calendar + GitHub, as a scheduled routine at 8am.
- **Ticket → PR:** Linear/Jira → code → GitHub PR → Slack post.
- **Meeting follow-up:** Calendar event + Drive notes → draft follow-up email in Gmail.
- **Design → code:** Figma frame → component → Playwright screenshot to compare.
- **Bug triage:** Sentry error → reproduce → fix → PR that links the issue.

---

## 7. Recommended Starter Stack

| Priority | Add | Type | Why |
|---|---|---|---|
| 1 | **GitHub** | MCP / connector | PRs, issues and CI from the chat |
| 2 | **Context7** | MCP | Current library docs, fewer wrong APIs |
| 3 | **Playwright** (or Chrome DevTools) | MCP | Claude can see and test your UI |
| 4 | **Your tracker** (Linear / Jira / Notion) | MCP / connector | Work from tickets end to end |
| 5 | **commit-commands + pr-review-toolkit** | Plugins | Faster git and better reviews |
| 6 | **hookify** or **security-guidance** | Plugin | Guardrails without writing config |
| 7 | **Gmail + Calendar + Drive** | Connectors | Everyday non-coding automation |
| 8 | **Your DB** (read-only) | MCP | Answer data questions directly |
| 9 | **Agent SDK** | Library | Once a workflow needs to run unattended |
