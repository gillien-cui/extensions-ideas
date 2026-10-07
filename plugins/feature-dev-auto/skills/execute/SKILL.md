---
name: execute
description: Carries out an approved feature-dev-auto plan (docs/plans/<slug>/PLAN.md) without human input. Implements each task test-first, proves it with the plan's checks, commits locally, runs a three-agent code review, fixes high-confidence issues, and writes SUMMARY.md. Use when a /goal or the user asks to execute a feature-dev-auto plan.
argument-hint: <path to PLAN.md>
---

# Unattended execution (feature-dev-auto)

You are executing an approved plan with **no human available**. A `/goal` evaluator reads this conversation after every turn and decides whether the work is done. It cannot run commands or open files. It only sees what you show. So every claim you make has to come with visible proof, such as a command and its output.

Plan: $ARGUMENTS. If no path was given, use the most recently modified `docs/plans/*/PLAN.md`.

## Hard rules

1. **Never ask the user anything.** When something is ambiguous:
   - choose the option most consistent with PLAN.md and the codebase's conventions,
   - prefer the smaller, safer change,
   - log the decision under "Decisions during execution" in PROGRESS.md,
   - and keep going.
2. **Never delete, skip, disable or weaken an existing test** to make a check pass. This includes loosening an assertion, adding `.skip`/`xfail`, or narrowing a test command. Fix the code instead. Only change an existing test if PLAN.md says that behaviour is meant to change, and log it.
3. **Stay in scope.** Only change what the tasks need. Follow the plan's run policy on dependencies and on paths the run must never touch.
4. **No pushing, no pull requests, no force operations.** Commit locally, one commit per task.
5. **Run checks in the foreground and show the result.** Set `run_in_background: false` on every Agent call. Never end a turn just to wait for something: background work delays the /goal evaluation.
6. **Never claim something passed without showing it.** Paste the relevant tail of the output and the exit code.

## Step 0: Resume, every turn

At the start of every turn, before anything else:

1. Read PLAN.md and PROGRESS.md. They are the memory of this run, and the conversation may have been compacted.
2. If PROGRESS.md says `Status: NOT STARTED`, set it up:
   - record `git rev-parse HEAD` as the base commit,
   - set the status to `IN PROGRESS`,
   - change PLAN.md's status line to `Status: APPROVED, EXECUTING`.
3. Continue from the first task that is not checked `[x]` and not marked BLOCKED.
4. If PROGRESS.md says `Status: DONE` or `Status: INCOMPLETE`, the run is over. Print the final report from Step 5 again and stop.

## Step 1: Do each task

For each unchecked task, in order:

1. **Test first.** If the task names a test, write it and run it. Show it failing for the expected reason.
2. **Implement** the smallest change that makes it pass, following the conventions the plan names.
3. **Prove it.** Run the task's proof command and show the output and exit code. If it fails, debug the cause: read the error, form a hypothesis, check it, then fix. Don't make random edits.
4. **Record it.**
   - Tick the task `[x]` in PLAN.md.
   - Append one line to the PROGRESS.md log: `T<n> done: <what changed> · proof: <command> → <result>`.
   - Commit locally with a message like `feat(<slug>): T<n> <short description>`.
5. **Blocked tasks.** If a task can't be completed, for example because it needs a credential, a service you can't reach, or a decision PLAN.md truly does not cover:
   - mark it `- [ ] T<n> BLOCKED: <reason>` in PLAN.md,
   - log it,
   - skip any later tasks that depend on it,
   - and continue with the rest.

Do as many tasks per turn as you can. Ending a turn is not the end of the run.

## Step 2: Full verification

When every task is done or blocked:

1. Run **every** check in the PLAN.md Test plan, one by one, in the foreground.
2. Print a verification table:
   ```
   VERIFICATION (<date>)
   | # | Check | Exit | Result |
   | A1 | `<command>` | 0 | PASS: 12 passed |
   | R1 | `<command>` | 0 | PASS: 48 passed (baseline: 48) |
   ```
3. If anything fails other than a baseline failure, fix it and run the full table again. Don't move on with a red check.

## Step 3: Code review

1. Collect what changed:
   - `git diff --stat <base commit>`
   - `git diff <base commit>`, or the list of changed files if the diff is longer than about 1,500 lines.
2. Launch three `feature-dev-auto:code-reviewer` agents **in parallel, in the foreground**. Give each:
   - the diff (or the file list),
   - the path to PLAN.md,
   - one focus:
     - **A:** simplicity, duplication, readability.
     - **B:** bugs, logic errors, edge cases from the test plan, security.
     - **C:** project conventions, CLAUDE.md rules, fit with existing abstractions.
3. Merge their findings and drop duplicates. For every issue scored 80 or above:
   - fix it,
   - add a test if it was a bug,
   - and commit with a message like `fix(<slug>): <issue>`.
   Note issues below 80 in the summary without fixing them.
4. If you fixed anything, re-run Step 2's full verification. Allow at most 2 review rounds. Anything still unresolved after round 2 goes in the summary as an open risk.
5. If no code changed at all (for example because every task is blocked), skip the review and say so in the summary.

## Ending INCOMPLETE

The run ends INCOMPLETE when one of these is true:
- every task left is BLOCKED for a reason outside the run's control,
- or the turn budget is used up.

Before you end INCOMPLETE:
- finish all the work that isn't blocked,
- verify it,
- write SUMMARY.md with exactly what a human must do next,
- and end with the INCOMPLETE status line.

Never end INCOMPLETE to avoid work that is possible within the rules. Never write DONE when anything is blocked or failing.

## Step 4: Write SUMMARY.md

Write `docs/plans/<slug>/SUMMARY.md`:

```markdown
# Summary: <feature>
Status: DONE | INCOMPLETE
Base commit: <sha> · Final commit: <sha> · Turns used: <n>

## What was built
## Decisions and assumptions
<From PLAN.md plus "Decisions during execution". Mark the ones made without the user.>
## Test results
<The final verification table, and the tests that were added.>
## Code review
<Fixed: ... / Not fixed (below 80, or deferred): ... with the reason>
## Blocked or incomplete
<Each blocked task and what a human needs to do, or "None">
## Open risks and follow-ups
## Files changed
<git diff --stat <base commit>>
## How to review
<2–4 concrete steps, such as the commands to run and the files to read first>
```

Then:
- set PROGRESS.md and PLAN.md to `Status: DONE`, or to `INCOMPLETE` if any task is blocked or any check still fails,
- and commit the plan files with a message like `docs(<slug>): execution summary`.

## Step 5: Final report

Finish with a short report, under 25 lines, in this order:
1. the verification table,
2. the code review result,
3. the path to SUMMARY.md,
4. the list of commits (`git log --oneline <base commit>..HEAD`).

The very last line must be exactly one of:

```
FEATURE-DEV-AUTO STATUS: DONE
FEATURE-DEV-AUTO STATUS: INCOMPLETE
```

Use DONE only when every task is checked and every check passes, apart from baseline failures.

## Turn budget

PLAN.md's run policy sets a turn budget. Keep count in PROGRESS.md: add one line per turn, such as `Turn 3: T4–T6 done`. If you reach the budget, stop starting new work. Go straight to Step 4 with status INCOMPLETE and explain what remains, then do Step 5.
