---
name: plan
description: Plans a feature for unattended implementation. Explores the codebase, asks the user one batch of questions, chooses an architecture, writes PLAN.md with a concrete test plan, and hands back a single /goal command that builds, tests, reviews and summarizes the feature without further human input.
argument-hint: <feature description> [--yes]
disable-model-invocation: true
---

# Feature planning (feature-dev-auto)

You are planning a feature so that it can be implemented **without any further human input** once the plan is approved. Every question for the human happens in this session. After the user approves, a `/goal` loop runs the `feature-dev-auto:execute` skill until the work is done, and the human reviews only the final summary.

Feature request: $ARGUMENTS

If the request contains `--yes`, the user wants no questions at all: skip the question batch in Phase 3, choose sensible defaults, and record each one under **Assumptions** in the plan.

## Rules for this session

- **Ask once.** Collect every question into one batch in Phase 3. Never ask in any other phase, except Phase 1 when the request is too vague to explore at all.
- **Do not edit source files.** The only files you write are the plan files under `docs/plans/<slug>/`.
- **Make decisions, then show them.** Pick the architecture and the defaults yourself, explain why in the plan, and let the user veto them at the approval step.
- **Everything must be provable.** Every task and every acceptance criterion needs a check whose output can be shown in a transcript: a command and its expected result, or, only when nothing can be automated, a manual step with what to look for.
- **Run agents in the foreground.** Set `run_in_background: false` on every Agent call in this skill, and launch parallel agents in a single message. Never end your turn or schedule a wake-up while you wait for an agent.
- **Never skip a phase.** Phases 2, 4 and 5 and the red-team in Phase 6 always launch their agents. Scale them to the feature's size:
  - For a change of about three files or fewer, one explorer and one architect are enough.
  - The test-planner and the red-team review always run.
- Track the phases with the task tools.

---

## Phase 1: Understand the request

1. Restate the feature in 2–3 sentences: the problem, the expected behaviour, and what is out of scope.
2. Choose a short kebab-case slug for it, such as `csv-export`. All plan files go in `docs/plans/<slug>/`.
3. If the request is so vague that you cannot tell which part of the codebase it touches, ask the user one short question now. Otherwise do not ask anything yet.

## Phase 2: Explore the codebase

1. Run these yourself and keep the results: `git rev-parse --abbrev-ref HEAD`, `git status --short`, and `git log --oneline -5`. If the directory is not a git repository, note that the run will not be able to commit per task.
2. Launch 2–3 `feature-dev-auto:code-explorer` agents **in parallel, in the foreground**. Give each a different focus, for example:
   - "Find features similar to <feature> and trace how they are implemented end to end."
   - "Map the architecture, abstractions and conventions of <area>, including CLAUDE.md rules."
   - "Find how this project is tested, linted and built: exact commands, test file locations and naming, frameworks, CI config, and any currently failing tests."
   Ask each to end with its list of 5–10 essential files.
3. Read every essential file the agents list.
4. Work out the project's real check commands (test, lint, typecheck, build) from package.json, Makefile, pyproject.toml, CI config and similar. Note which ones do not exist.
5. **Record a baseline.** Run the existing test suite (and lint/build if they exist) now, in the foreground, and keep the pass/fail counts. Pre-existing failures go in the plan so the unattended run does not chase them or get blamed for them.

## Phase 3: One batch of questions

Collect everything that is underspecified: behaviour, edge cases, error handling, scope boundaries, backward compatibility, performance, UX, data migration. Also collect the run policy:

- whether the run may add new dependencies,
- the turn budget for the unattended run (default 25 turns),
- anything the run must never touch.

Then:

- **Normal mode:** ask them all at once. Use the AskUserQuestion tool for up to 4 questions with concrete options, putting your recommended option first and labelling it "(Recommended)". If there are more than 4, put the rest in a single numbered list in the same message, each with your proposed default. Say clearly that this is the only round of questions. Wait for the answers.
- **`--yes` mode, or when the user says "you decide":** do not ask. Use your recommended option for each and record it as an assumption.

Keep questions that would not change the plan out of the batch. Fewer, sharper questions are better.

## Phase 4: Architecture

1. Launch 2–3 `feature-dev-auto:code-architect` agents **in parallel, in the foreground**, with different briefs: "minimal change, maximum reuse", "clean architecture", and "pragmatic balance". Pass each the user's answers and the explorer findings.
2. Choose one approach yourself, based on the size of the feature and the codebase's conventions. Record the choice, the two alternatives and why you rejected them. Do not ask the user to choose. They can override at the approval step.

## Phase 5: Test plan

1. Launch one `feature-dev-auto:test-planner` agent in the foreground. Give it the feature, the user's answers, the chosen architecture, and the check commands and baseline from Phase 2.
2. Make sure the result has:
   - at least one check per acceptance criterion, automated wherever possible,
   - new tests written before the code they cover, where the project has a test framework,
   - the full regression suite as a final check,
   - lint, typecheck and build as final checks, where they exist.

## Phase 6: Write the plan and red-team it

Before writing, check that you have all of these. If one is missing, go back and get it:
- the explorer report(s) and the essential files read,
- the baseline results,
- the user's answers, or the `--yes` assumptions,
- the architect report(s) and your recorded choice,
- the test-planner's test plan.

1. Write `docs/plans/<slug>/PLAN.md` using the template below.
   - Tasks are **implementation steps only**: tests and code.
   - Don't add tasks for full verification, code review or the summary. The execute skill always does those after the last task.
2. Write `docs/plans/<slug>/PROGRESS.md` containing only:
   ```
   # Progress: <feature>
   Status: NOT STARTED
   Base commit: (set by the first execute turn)

   ## Log
   ```
3. Launch one `feature-dev-auto:code-architect` agent in the foreground with this brief: "Red-team this plan. Read docs/plans/<slug>/PLAN.md and the files it names. Report anything that would make an unattended run fail or produce the wrong result: missing tasks, tasks in the wrong order, checks that cannot prove the criterion, commands that do not exist, ambiguities the run would have to guess at, scope creep." Fix the plan for every real problem it finds.
4. Write the `/goal` condition into the plan's last section, using the template below. Keep it under 3,500 characters.

### PLAN.md template

```markdown
# Plan: <feature>

Status: AWAITING APPROVAL
Created: <date> · Branch: <branch> · Slug: <slug>

## Goal and scope
<2–4 sentences. What it does.>
- In scope: ...
- Out of scope: ...

## Decisions from the user
<Each question and the user's answer. In --yes mode write "None: planned with --yes".>

## Assumptions
<Every default chosen without the user. The user can veto any of these before approving.>

## Run policy
- Turn budget: <N> turns
- New dependencies: <allowed / not allowed / only: ...>
- Never touch: <paths, or "nothing extra">
- Commits: one local commit per task. No push, no pull request.

## Architecture decision
- Chosen: <approach>. Why: ...
- Rejected: <approach A>, because ...
- Rejected: <approach B>, because ...
- Key files: <path>: <change>

## Baseline (before any change)
- `<test command>`: <N passed, M failed (names of failing tests)>
- `<lint/build command>`: <result, or "not configured">

## Tasks
Tasks run in order. Each one names its files and the proof that it is done.
- [ ] T1 <change>. Files: `a`, `b`. Test first: <test to write>. Proof: `<command>` exits 0.
- [ ] T2 ...

## Test plan
| # | Acceptance criterion | Check | Type | Expected result |
|---|---|---|---|---|
| A1 | ... | `<command>` | unit | exit 0, includes "<test name>" |
| R1 | No regressions | `<full test command>` | regression | exit 0, or only the baseline failures |
| Q1 | Lint/build clean | `<command>` | quality | exit 0 |

## Done condition
<the exact /goal condition, in a fenced block>
```

### /goal condition template

Fill this in. Keep every command exactly as written in the test plan.

```
/goal Use the feature-dev-auto:execute skill to carry out docs/plans/<slug>/PLAN.md. The goal is met when the conversation shows the run reaching ONE of these two end states. DONE: (1) every task in PLAN.md is checked [x]; (2) a final verification turn runs every check in the Test plan, including <list each command>, and shows each one passing with the expected result (baseline failures listed in PLAN.md may remain); (3) three feature-dev-auto:code-reviewer agents reviewed the changes and no issue scored 80 or above is left unresolved; (4) docs/plans/<slug>/SUMMARY.md is written and the last message ends with the line "FEATURE-DEV-AUTO STATUS: DONE". INCOMPLETE, which also ends the goal: every task is either checked [x] or marked BLOCKED with a reason outside the run's control (such as a missing credential, a file the run policy forbids, or a decision the plan does not cover), or <N> turns have been used; all other work has been done and verified as far as possible; SUMMARY.md is written with status INCOMPLETE and says what a human must do; and the last message ends with the line "FEATURE-DEV-AUTO STATUS: INCOMPLETE". Reporting INCOMPLETE for work that could be done within the rules does not count. Constraints for the whole run: never ask the user a question; do not delete, skip or weaken any existing test; do not push or open a pull request; stay within the plan's scope and run policy.
```

## Phase 7: Hand over for approval

Present a short summary of the plan, under 30 lines:
- what will be built,
- the chosen architecture, in one line,
- the assumptions the user should check,
- the number of tasks,
- the test plan checks, as commands,
- the turn budget.

Then give the user the approval step, worded like this:

> **This is the only approval.** Review `docs/plans/<slug>/PLAN.md`. To change anything, tell me now and I'll update the plan. To approve and start the unattended run, switch to auto mode (Shift+Tab) so tool calls don't stop for permission, then paste this:

Follow it with the full `/goal …` line in a fenced code block.

Then add a headless alternative for running it in a terminal or in CI:

```
claude -p --permission-mode auto --output-format stream-json --verbose "/goal …"
```

After the run, the user reads `docs/plans/<slug>/SUMMARY.md` and the commits on the branch.

Stop here. Do not start implementing. If the user asks for changes, update PLAN.md and the `/goal` line, then present the approval step again.
