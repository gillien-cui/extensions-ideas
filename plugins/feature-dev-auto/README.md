# feature-dev-auto

Plan a feature with a human once, then let Claude Code build, test, review and summarize it unattended.

It's a reworking of Anthropic's [`feature-dev`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/feature-dev) plugin. feature-dev stops for a human five times. This plugin moves every human decision into one planning session and makes the test plan mandatory. After you approve, the built-in [`/goal`](https://code.claude.com/docs/en/goal) command keeps Claude working until the plan is provably done.

## How it works

```
 YOU ARE HERE ─────────────────────────────┐   UNATTENDED ──────────────────────────────────────┐
                                           │                                                     │
 /feature-dev-auto:plan <feature> [--yes]  │   /goal Use the feature-dev-auto:execute skill …    │
   1 understand the request                │     every turn: re-read PLAN.md + PROGRESS.md        │
   2 explore (code-explorer ×2–3)          │     per task: test first → implement → prove →       │
     + record test baseline                │               tick → log → local commit              │
   3 ONE batch of questions (or --yes)     │     verify: run every test-plan check, show table    │
   4 architecture (code-architect ×2–3)    │     review: code-reviewer ×3 → fix issues ≥80        │
   5 test plan (test-planner)              │     SUMMARY.md + "FEATURE-DEV-AUTO STATUS: DONE"     │
   6 PLAN.md + red-team + plan checker     │                                                     │
   7 hand-over: the only approval ─────────┼──►  /goal evaluator checks the transcript after      │
                                           │     every turn and stops when the condition holds    │
───────────────────────────────────────────┘─────────────────────────────────────────────────────┘
                                                 YOU AGAIN: read docs/plans/<slug>/SUMMARY.md
```

| | feature-dev | feature-dev-auto |
|---|---|---|
| Human checkpoints | 5, spread across the run | 1 round of questions + 1 approval, all before any code is written |
| Test plan | Not required | Required: every task and criterion has a runnable check |
| Test baseline | No | Recorded before changes, so known failures aren't chased |
| Architecture choice | User picks from 2–3 options | Claude picks one, records the alternatives; user can veto in the plan |
| Plan red-team | No | Yes, an architect agent attacks the plan before hand-over |
| Implementation loop | Single pass | `/goal`: runs until a separate evaluator sees the done condition proven |
| Memory across compaction/resume | Conversation only | `PLAN.md` checkboxes + `PROGRESS.md` log |
| Review | 3 reviewers, then ask the user | 3 reviewers, fix issues ≥80 automatically, max 2 rounds |
| Output | Chat summary | `SUMMARY.md` + one local commit per task |

## Install

From this repository's root:

```bash
claude plugin marketplace add ./
claude plugin install feature-dev-auto@extensions-ideas --scope project
```

Or load it for one session without installing: `claude --plugin-dir ./plugins/feature-dev-auto`.

## Use

1. In the project you want to change, run:
   ```
   /feature-dev-auto:plan Add CSV export to the reports page
   ```
   Answer the single batch of questions, or add `--yes` to let Claude choose and record its assumptions.
2. Read the hand-over. It always shows the **test plan** table and the **stopping condition** (the `/goal` line), and `scripts/check-plan.sh` has confirmed both are in `docs/plans/<slug>/PLAN.md`. Ask for changes if you want them.
3. Switch to auto mode (Shift+Tab) and paste the `/goal …` line Claude gives you. That's the approval, and it starts the run.
   The hand-over always ends with that line, and it's also saved in `docs/plans/<slug>/GOAL.md`.
   If it ever gets lost, for example because a project coordinator summarized the thread's report, run `/feature-dev-auto:goal` to print it again.

   For a terminal or CI, run it headless instead:
   ```bash
   claude -p --permission-mode auto --output-format stream-json --verbose "/goal …"
   ```
4. When it ends, review:
   - `docs/plans/<slug>/SUMMARY.md`,
   - `git log`, which has one commit per task,
   - the verification table in the final message.

Nothing is pushed. You decide what to do with the branch.

Check on a running goal with `/goal`, and stop it with `/goal clear`.

## Files

```
feature-dev-auto/
├── .claude-plugin/plugin.json
├── skills/
│   ├── plan/SKILL.md        /feature-dev-auto:plan: all human interaction happens here
│   ├── execute/SKILL.md     run by /goal: build → prove → review → summarize, no questions
│   └── goal/SKILL.md        /feature-dev-auto:goal: prints the ready-to-paste /goal line for a plan
├── agents/
│   ├── code-explorer.md     adapted from feature-dev; also discovers test/lint/build commands
│   ├── code-architect.md    adapted from feature-dev; adds testable build sequence + red-team mode
│   ├── code-reviewer.md     adapted from feature-dev; reviews a supplied diff, guards test integrity
│   └── test-planner.md      new: acceptance criteria → runnable checks
├── scripts/
│   └── check-plan.sh        validates PLAN.md: tasks, test plan, /goal stopping condition (run before hand-over)
├── evals/                   claude plugin eval suite (see Testing)
└── LICENSE                  Apache-2.0 (agents derived from Anthropic's feature-dev)
```

Each plan gets its own folder in the target project:

```
docs/plans/<slug>/
├── GOAL.md                  just the /goal line (the stopping condition), ready to paste
├── PLAN.md                  scope, decisions, assumptions, run policy, architecture, baseline,
│                            tasks with proofs, test plan, done condition (/goal line)
├── PROGRESS.md              status, base commit, per-task and per-turn log, decisions made while running
└── SUMMARY.md               written at the end, for the human reviewer
```

## Design choices and where they come from

- **The 7-phase skeleton and three specialist agents** come from Anthropic's feature-dev plugin. The agents are read-only, so only the main session edits code.
- **The `/goal` done condition** follows Anthropic's [/goal docs](https://code.claude.com/docs/en/goal).
  - The evaluator only sees the transcript, so every check runs in the foreground and its output is shown.
  - The condition names the exact commands and ends on a fixed status line.
  - There's a turn budget.
  - Subagents run in the foreground, because background work delays evaluation.
- **The skill can't start `/goal` itself.** Skills cannot invoke built-in slash commands ([skills docs](https://code.claude.com/docs/en/skills)). So pasting the `/goal` line is both your approval and the trigger for the run.
- **Durable progress files and commits** follow Anthropic's [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents). PLAN.md checkboxes, the PROGRESS.md log and one commit per task let a resumed or compacted session pick up where it stopped.
- **The independent judgement of "done"** follows Anthropic's [Harness design for long-running apps](https://www.anthropic.com/engineering/harness-design-long-running-apps). There, a planner, a generator and an evaluator agree on what "done" means before building starts. Here the `/goal` evaluator, not the agent doing the work, decides when it's done.
- **Test-first tasks, small tasks with exact files and a proof each, and "evidence before claims"** come from [obra/superpowers](https://github.com/obra/superpowers).
- **The red-team pass and the baseline** come from the Goal Composer plugin (Anthropic plugin directory). It red-teams a `/goal` mandate and records a baseline before the run.

## Testing

- `claude plugin validate plugins/feature-dev-auto` passes.
- `evals/` contains a [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals) suite. To run it:
  ```bash
  claude plugin eval plugins/feature-dev-auto --scaffold --ablation none --runs 1 --allow-tools Write Edit "Bash(git *)" "Bash(npm *)" "Bash(node *)"
  ```
  The cases need Bash, which evals only allow inside Claude Code's OS sandbox. On Linux that means installing `bubblewrap` and `socat` first.
- An end-to-end run on a sample project is recorded in [`TEST-REPORT.md`](TEST-REPORT.md).

## Limits

- The run can only be as good as the plan's checks. Features with no automatable checks, such as visual design, end with manual steps listed in SUMMARY.md.
- "Never ask" means the run makes judgement calls. They're all logged in PROGRESS.md and SUMMARY.md, and you review them afterwards rather than during the run.
- `/goal` needs Claude Code v2.1.139 or later, and hooks must be allowed (`disableAllHooks` off).
