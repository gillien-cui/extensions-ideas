#!/usr/bin/env bash
# Checks that a feature-dev-auto PLAN.md has everything an unattended run needs:
# tasks, a test plan with real rows, and a /goal done condition with both end states.
# Usage: check-plan.sh docs/plans/<slug>/PLAN.md
# Prints one PASS/FAIL line per check and exits 1 if any check fails.

plan="${1:-}"
fail=0
check() { # check <description> <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $desc"; else echo "FAIL  $desc"; fail=1; fi
}

if [ -z "$plan" ] || [ ! -f "$plan" ]; then
  echo "FAIL  plan file exists: '${plan}' not found"
  exit 1
fi
echo "PASS  plan file exists: $plan"

section_rows() { # number of table rows with an ID like A1/R1/Q1 under "## Test plan"
  awk '/^## /{in_tp = ($0 ~ /^## Test plan/)} in_tp && /^\| *[A-Z][0-9a-z]* *\|/{n++} END{print n+0}' "$plan"
}
goal_line() { grep -m1 '^/goal ' "$plan"; }

check "has '## Tasks' with at least one task" grep -Eq '^- \[[ x]\] T[0-9]+' "$plan"
check "has '## Test plan' section" grep -q '^## Test plan' "$plan"
rows=$(section_rows)
check "test plan has at least 2 checks (found $rows)" test "$rows" -ge 2
check "test plan has an acceptance check (A1…)" sh -c "awk '/^## /{t=(\$0 ~ /^## Test plan/)} t && /^\\| *A[0-9]/{f=1} END{exit !f}' \"$plan\""
check "test plan has a regression check (R1…)" sh -c "awk '/^## /{t=(\$0 ~ /^## Test plan/)} t && /^\\| *R[0-9]/{f=1} END{exit !f}' \"$plan\""
check "has '## Done condition' section" grep -q '^## Done condition' "$plan"
check "done condition has a /goal line" grep -q '^/goal ' "$plan"
len=$(goal_line | wc -c | tr -d ' ')
check "/goal line is under 4,000 characters (found $len)" test "$len" -gt 0 -a "$len" -lt 4000
check "/goal names the execute skill" sh -c "grep -m1 '^/goal ' \"$plan\" | grep -q 'feature-dev-auto:execute'"
check "/goal defines the DONE end state" sh -c "grep -m1 '^/goal ' \"$plan\" | grep -q 'FEATURE-DEV-AUTO STATUS: DONE'"
check "/goal defines the INCOMPLETE end state" sh -c "grep -m1 '^/goal ' \"$plan\" | grep -q 'FEATURE-DEV-AUTO STATUS: INCOMPLETE'"
check "/goal sets a turn budget" sh -c "grep -m1 '^/goal ' \"$plan\" | grep -Eq '[0-9]+ turns'"
check "has a run policy" grep -q '^## Run policy' "$plan"
check "has a baseline" grep -q '^## Baseline' "$plan"

if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAIL. Fix the plan and run this check again before handing over."
  exit 1
fi
echo "RESULT: PASS"
