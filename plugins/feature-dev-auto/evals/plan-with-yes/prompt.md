---
description: Planning with --yes writes a complete PLAN.md (with a test plan and a /goal line) without asking questions or touching source files.
expected_outcome: docs/plans/<slug>/PLAN.md and PROGRESS.md exist; the reply ends with a /goal line that runs feature-dev-auto:execute.
max_turns: 80
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet]
---

/feature-dev-auto:plan Add a slugify(text, options) function to textkit that turns any string into a URL-safe slug (lowercase, ASCII, words joined by a separator), exported from src/index.js. --yes
