---
name: goal
description: Prints the ready-to-paste /goal line (the stopping condition) for a feature-dev-auto plan, so the user can start the unattended run. Use when the user asks for the /goal line, the stopping condition, or how to start or approve a feature-dev-auto plan.
argument-hint: "[path to PLAN.md or GOAL.md]"
---

# Show the /goal line (feature-dev-auto)

The user wants the exact `/goal` line that starts the unattended run for a plan. Plan path: $ARGUMENTS. If no path was given, use the most recently modified `docs/plans/*/GOAL.md`. If there is none, use the most recent `docs/plans/*/PLAN.md`.

1. Find the line.
   - Read `GOAL.md` in the plan's folder.
   - If that file is missing or doesn't start with `/goal `, take the first line that starts with `/goal ` from the `## Done condition` section of `PLAN.md`.
   - If you found it in PLAN.md, write it to `GOAL.md` so it's there next time.
   - If neither file has a `/goal` line, the plan is incomplete. Say so, and tell the user to run `/feature-dev-auto:plan` again or ask you to finish the plan.
2. Run the plan checker and show its result in one line:
   ```
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-plan.sh" <path to PLAN.md>
   ```
   If it fails, list the FAIL lines before showing the `/goal` line.
3. Reply in this shape, and change nothing in the `/goal` line:

   > Plan: `docs/plans/<slug>/PLAN.md` (plan check: PASS or FAIL). To approve and start the unattended run, switch to auto mode (Shift+Tab), then paste this into the session or project thread that should do the work:

   Then put the full `/goal …` line in a fenced code block as the last thing in the message.

Don't start the run yourself, and don't change any files except to create a missing GOAL.md.
