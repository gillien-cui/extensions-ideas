# feature-dev-auto — Build Handoff

A short brief for the agent building an autonomous "approve the plan once, then run to done" version of the feature-dev workflow.

> **Status: built.** Option A is implemented in [`plugins/feature-dev-auto/`](plugins/feature-dev-auto/README.md). Test results are in [`plugins/feature-dev-auto/TEST-REPORT.md`](plugins/feature-dev-auto/TEST-REPORT.md).
>
> Two answers from building it:
> - **Skills can't start `/goal`.** The official skills docs confirm this, so the approval step is the user pasting the printed `/goal` line.
> - **The command is now a skill.** It runs as `/feature-dev-auto:plan`, because skills are now the recommended format for plugin commands.

## 1. What the user wants

- Keep the strengths of Anthropic's `feature-dev` plugin: explore the codebase, ask clarifying questions, compare architectures.
- **Cut the human checkpoints to one.** Today feature-dev stops 5 times (confirm goal, answer questions, pick an approach, approve the build, decide on review fixes).
- **Every plan must include a clear test plan.** Each task says how it will be proven: a test, a build, a lint run or a manual check.
- **After the plan is approved, run unattended to the end.** Build, test, review and fix in a loop, using Claude Code's built-in `/goal` command.
- **Finish with a clear summary for a human to review.**

## 2. Background you need

### feature-dev (installed in this repo, project scope)
- Full teardown: [`feature-dev-plugin-teardown.md`](feature-dev-plugin-teardown.md)
- Source: `anthropics/claude-plugins-official` → `plugins/feature-dev`
- The plugin is pure Markdown: one command file (`commands/feature-dev.md`) plus three read-only `model: sonnet` agents:
  - `code-explorer`: traces existing code and returns 5–10 key files.
  - `code-architect`: produces one decisive blueprint.
  - `code-reviewer`: reviews `git diff` and reports only issues it scores 80/100 or higher.
- Seven phases: Discovery, Explore, Questions, Architecture, Implement, Review, Summary.

### `/goal` (built into Claude Code since v2.1.139; this environment has 2.1.292)
- `/goal <condition>` makes Claude keep taking turns until the condition is met. After each turn, a small fast model (Haiku by default) judges the condition. It returns **met**, **not yet met** (Claude keeps working, using the reason as guidance) or **impossible** (the goal clears).
- **The evaluator only reads the transcript.** It doesn't run commands or read files, so the condition must name checks whose output Claude prints: "`npm test` exits 0", "`git status` clean".
- **Add a cap** such as "or stop after N turns". The condition can be up to 4,000 characters.
- **Use auto mode for unattended runs.** `/goal` removes the pauses between turns; auto mode removes the per-tool-call approval prompts.
- **Background work delays evaluation.** If a subagent or background shell is still running when a turn ends, evaluation waits.
- `/goal clear` cancels a goal. `claude -p "/goal …"` runs headless. An active goal survives `--resume`.
- Under the hood, `/goal` is a session-scoped, prompt-based Stop hook.
- Docs: https://code.claude.com/docs/en/goal

## 3. Options

### Option A: build `feature-dev-auto` (recommended)
A small plugin in this repo that reuses feature-dev's agents and replaces its back half with `/goal`. It fits the user's exact flow, it's about 5 Markdown files, and you control the test-plan format and the summary.

### Option B: adopt Superpowers (worth trying side by side)
- **What it is:** `obra/superpowers`, in the official directory.
  - Install: `/plugin install superpowers@claude-plugins-official`
  - Or from its own marketplace: `/plugin marketplace add obra/superpowers-marketplace`, then `/plugin install superpowers@superpowers-marketplace`
- **Flow:**
  1. Brainstorm, then present a design for **approval #1**.
  2. Create a git worktree on a new branch.
  3. Write a plan of 2–5-minute tasks, each with exact files and verification steps, for **approval #2**.
  4. Execute through subagent-driven development: a fresh subagent per task, strict test-first (red, green, refactor) cycles, and a code review after each task.
  5. Finish the branch: verify the tests, then offer merge or PR options.
- **Pros:** mature and widely used. Test-first is enforced and verification is built into each task. The author reports it runs for hours on its own after approval.
- **Cons:**
  - Two human gates instead of one.
  - It's a large skills library, so it's harder to customise.
  - Its "keep going" relies on the plan, not on `/goal`'s independent evaluator.
  - The final summary format is not one we defined.
- **Possible hybrid:** use Superpowers for brainstorming and plan writing, then hand the approved plan to `/goal` (see the condition template below).

### Option C: other references, not recommended as the base
- **Goal Composer** (directory): interviews the user and writes a `/goal` mandate that the transcript can verify, with red-team and recheck steps. Good to borrow condition-writing ideas from.
- **ralph-loop** (Anthropic, directory): a Stop hook and a promise string (`<promise>DONE</promise>`) with a cap on loops. It's the do-it-yourself predecessor of `/goal`; use it only if `/goal` is unavailable.
- **GitHub Spec Kit, BMAD, sdd-superpowers:** spec-driven development with human review between steps. Too many gates for this use.
- **Anthropic harness articles:** separate planner, generator and evaluator roles, plus durable progress files (a feature list with pass/fail flags, a progress log, git commits). Borrow the progress-file idea.

## 4. Recommended design (Option A)

```
/feature-dev-auto <feature>
  1 Discover    restate the request; ask questions ONLY if truly blocking
  2 Explore     2–3 code-explorer agents in parallel → main agent reads key files
  3 Decide      main agent answers its own open questions with stated assumptions
  4 Architect   2–3 code-architect agents → main agent picks one, records why
  5 Test plan   test-planner agent turns acceptance criteria into concrete checks
  6 Write PLAN.md (design + tasks + test plan + assumptions + /goal condition)
  ══ ONE HUMAN GATE: user reviews PLAN.md, then runs the printed /goal line ══
  7 /goal loop  implement task → run its checks → mark done → next task
                after all tasks: 3 code-reviewer agents → fix issues scored 80+ → re-run all checks
  8 SUMMARY.md  what was built, decisions/assumptions, test results, open risks
```

**The approval and the start are one action.** A slash command can't reliably launch `/goal` itself. So phase 6 ends by printing the exact `/goal …` line, and the user approves by running it, which also starts the autonomous run.

- Verify early whether the command body can invoke `/goal` directly.
- If it can't and you want zero copy-paste, the alternative is a plugin-level Stop hook gated on a state file (the ralph-loop pattern).

### Plugin layout
```
feature-dev-auto/
├── .claude-plugin/plugin.json        name, version "0.1.0", description
├── commands/feature-dev-auto.md      phases 1–6 + prints the /goal line
├── commands/feature-dev-run.md       optional: re-print / resume the goal from PLAN.md
└── agents/test-planner.md            new; read-only tools, model: sonnet
```
- **Reuse feature-dev's agents.** Refer to them as `feature-dev:code-explorer`, `feature-dev:code-architect` and `feature-dev:code-reviewer`, and list feature-dev as a prerequisite. Copy the agents in only if a standalone plugin is needed.
- **Fix the README contradiction if you copy the reviewer.** feature-dev's README promises "Important 50–74" issues, but the agent only reports 80+. Keep the 80+ rule.

### PLAN.md format (write to `docs/plans/<feature>-PLAN.md`)
```markdown
# Plan: <feature>
## Goal & scope            (in / out of scope)
## Assumptions             (questions Claude answered itself; user can veto at the gate)
## Architecture decision   (chosen approach, 2 rejected alternatives, why)
## Tasks
- [ ] T1 <change> — files: a.ts, b.ts — proof: `npm test -- a.spec.ts` passes
- [ ] T2 ...
## Test plan
| Acceptance criterion | Check (command or manual step) | Type (unit/integration/e2e/lint/build) |
## Done condition (/goal)
<the exact condition, also printed for the user>
```

### `/goal` condition template
```
/goal Every task in docs/plans/<feature>-PLAN.md is checked off; each task's proof command
was run and its passing output shown; the full suite `<test cmd>` exits 0; `<lint cmd>` and
`<build cmd>` exit 0; three code-reviewer passes report no issue scored ≥80 (or every such
issue is fixed and re-verified); no file outside the plan's listed files was modified unless
recorded in PLAN.md; docs/plans/<feature>-SUMMARY.md exists with the sections What was built,
Decisions & assumptions, Test results, Review findings, Open risks, Files changed.
Stop after 40 turns and write the summary with status INCOMPLETE if not done.
```

### SUMMARY.md sections (for the human reviewer)
- **Status:** DONE or INCOMPLETE.
- **What was built.**
- **Decisions and assumptions:** flag any made without user input.
- **Test results:** each command and its pass/fail, plus any tests added.
- **Review findings:** fixed, and deferred with the reason.
- **Open risks and follow-ups.**
- **Files changed.**

### Guardrails to build in
- **Only the main agent edits.** All subagents stay read-only.
- **Commit after each task** with a small, descriptive message, so the run is easy to audit and roll back.
- **Never skip, disable or weaken a test to get green.** Say so explicitly in the command prompt and in the goal condition.
- **Print every proof.** Run checks in the foreground and show their output, so the evaluator can see the proof.
- **Don't push** or open PRs during the loop. That stays a human decision after reading SUMMARY.md.

## 5. Acceptance criteria for this build
1. `claude plugin validate ./feature-dev-auto` passes with no errors.
2. On a small sample repo (e.g. a tiny Node or Python project with an existing test suite), `/feature-dev-auto "add <small feature>"` produces a PLAN.md in the format above, including a filled test plan and a printed `/goal` line, with no human prompts before the gate except for truly blocking questions.
3. Running the printed `/goal` in auto mode completes without human input and produces SUMMARY.md with every section filled. Every test command listed in the plan appears in the transcript with passing output.
4. With a deliberately impossible requirement, the run ends at the turn cap or as "impossible", with a SUMMARY.md marked INCOMPLETE. It must not loop forever or fake a pass.
5. Run Option B (Superpowers) on the same sample feature. Record a short comparison in the repo covering human touches, wall time, test coverage and summary quality.

## 6. Open questions for the user
- Should Phase 1 be allowed to ask any questions, or should it always assume and record?
- What turn cap and token budget should a goal have?
- Should the run end with a pushed branch or PR, or only local commits?
- Should it be a standalone plugin, or depend on feature-dev being installed?

## Sources
- Claude Code `/goal` docs: https://code.claude.com/docs/en/goal
- Superpowers: https://github.com/obra/superpowers
- Ralph loop technique: https://www.atcyrus.com/stories/ralph-wiggum-technique-claude-code-autonomous-loops
- Anthropic, Effective harnesses for long-running agents: https://anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Anthropic, Harness design for long-running apps: https://anthropic.com/engineering/harness-design-long-running-apps
- Spec-driven development overview: https://datacamp.com/tutorial/spec-driven-development-with-claude-code
