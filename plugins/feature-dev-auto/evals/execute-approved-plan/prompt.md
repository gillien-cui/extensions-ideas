---
description: Executing an approved plan builds the feature test-first, proves every check, runs the three-reviewer pass, writes SUMMARY.md and ends with the DONE status line, without asking anything.
expected_outcome: 'slugify is implemented and exported, npm test passes, docs/plans/slugify/SUMMARY.md exists, and the last line is "FEATURE-DEV-AUTO STATUS: DONE".'
max_turns: 150
timeout_seconds: 3000
allowed_tools: [Read, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet]
---

/feature-dev-auto:execute docs/plans/slugify/PLAN.md
