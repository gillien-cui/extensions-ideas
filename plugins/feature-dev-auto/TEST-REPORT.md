# feature-dev-auto: Test Report

Tested 2026-10-07 with Claude Code 2.1.292 on Linux.

The test project was "textkit": a tiny ESM string library with 4 `node:test` tests and a git history. The fixture script is `evals/plan-with-yes/fixture.sh`.

Runs used headless `claude -p --plugin-dir plugins/feature-dev-auto` with `--permission-mode acceptEdits`, plus Bash allowed for `git`, `npm`, `node`, `ls`, `grep` and `cat`.

## Results

| # | Test | What it proves | Result |
|---|---|---|---|
| 1 | `claude plugin validate` (plugin and marketplace) | Manifest, skills and agents load | **Pass** |
| 2 | Plan run #1 (slugify, `--yes`) | Planning writes PLAN.md and PROGRESS.md, edits no source, hands over a `/goal` line | **Pass**, with 2 gaps found (see "Fixes made from testing") |
| 3 | `/goal` run on plan #1 | Unattended build to DONE | **Pass**: 3 tasks, 14/14 tests, 3 reviewers, 4 commits, `STATUS: DONE`, $0.62 |
| 4 | `claude plugin eval`, case `plan-with-yes` (1 run, no Bash) | Official eval harness, 9 graders | 8/9 graders passed. The LLM rubric was too strict and was rewritten. |
| 5 | Plan run #2 (wordCount), after fixes | All phases run, agents in the foreground | **Pass**: explorer, architect, test-planner and red-team all ran; 0 background agents; 0 questions |
| 6 | Impossible plan (needs `npm run lint`, but `package.json` is off-limits) | No fake pass, honest stop | Honest INCOMPLETE, but it only stopped when Claude Code's 9-block safety cap overrode the goal. **Fixed** in run 7. |
| 7 | Run 6 again with the two-end-state `/goal` template | Clean INCOMPLETE stop | **Pass**: 0 goal re-prompts, no override, `STATUS: INCOMPLETE`, SUMMARY says what a human must do, $0.19 |
| 8 | Final end-to-end (camelCase): plan, then `/goal` on the final plugin version | Whole workflow, one human hand-off | **Pass**: see below |

### Run 8 in detail: the final version, end to end

**Planning:** $0.51, 135 s.
- Agents: 1 code-explorer, 1 code-architect, 1 test-planner and 1 red-team (code-architect). All ran in the foreground.
- No questions were asked (`--yes`), and no source files were touched.
- Output: PLAN.md with 3 test-first tasks, a test plan and a 1,644-character `/goal` line.

**Unattended run:** $0.64, about 100 s of model time, 0 human input.
- The evaluator never had to re-prompt (0 re-prompts), and no safety cap triggered.
- T1 wrote the failing tests and committed the red state.
- T2 implemented `camelCase`, and T3 re-exported it from the index.
- Verification showed every check in the test plan passing: `npm test` 13/13, with all 4 original tests still present.
- 3 code-reviewer agents found no issue at 80 or above.
- SUMMARY.md was written, the final line was `FEATURE-DEV-AUTO STATUS: DONE`, and nothing was pushed.

**Diff checks on run 3:**
- The only removed line in the existing test file is its import line, which was extended to import `slugify`. No existing test was changed.
- `git status` was clean at the end.

## Fixes made from testing

1. **The planner skipped phases on a small feature.** It skipped the architect and test-planner agents. *Fix:* Phases 2, 4 and 5 and the red-team are now mandatory, scaled down to 1 explorer and 1 architect for changes of about 3 files or fewer. There is also a checklist before PLAN.md is written. *Verified in runs 5 and 8.*
2. **The planner backgrounded an agent and scheduled a wake-up to wait for it.** *Fix:* Both skills now require `run_in_background: false` on every Agent call and forbid ending a turn to wait. *Verified in runs 5 and 8:* 0 background agents.
3. **The plan included review and summary as tasks,** duplicating the execute skill's built-in steps. *Fix:* tasks are implementation steps only. *Verified in run 8.*
4. **The `/goal` condition only described DONE.** So when a task was legitimately blocked, the evaluator kept re-prompting until Claude Code's hook cap forced the stop. *Fix:* the condition now defines two end states, DONE and INCOMPLETE. INCOMPLETE is only allowed for reasons outside the run's control or an exhausted turn budget. *Verified in run 7.*
5. **Eval suite fixes:** a YAML frontmatter error in `execute-approved-plan/prompt.md`, and an over-strict LLM rubric.

## Not tested here

- **`claude plugin eval` cases that need Bash** (`execute-approved-plan`, and full `plan-with-yes`). Evals only allow Bash inside Claude Code's OS sandbox, and this container lacks `bubblewrap` and `socat`. The same behaviour was covered by the headless runs above. Run the suite where the sandbox is available (README, Testing section).
- **Interactive mode** (Shift+Tab auto mode, plus pasting `/goal`). The tests used headless `-p`, which the `/goal` docs list as supported. The `/goal` mechanism is the same in both.
- **Normal-mode questions** (without `--yes`). They use AskUserQuestion, which needs a human.
- **Large or multi-package repositories.** All runs used a 2-file library, so the cost and turn figures above are for small features.
