#!/usr/bin/env bash
# Creates the "textkit" sample project used by the eval cases:
# a tiny ESM string library with a node:test suite and a git history.
set -euo pipefail

mkdir -p src test
cat > package.json <<'EOF'
{
  "name": "textkit",
  "version": "1.0.0",
  "type": "module",
  "scripts": { "test": "node --test" }
}
EOF
cat > CLAUDE.md <<'EOF'
# textkit
Small ESM string utility library. No runtime dependencies.
- Every exported function has a JSDoc comment.
- Tests live in test/*.test.js and use node:test with node:assert/strict.
- Run tests with `npm test`.
EOF
cat > src/strings.js <<'EOF'
/**
 * Uppercase the first character of a string.
 * @param {string} text
 * @returns {string}
 */
export function capitalize(text) {
  if (typeof text !== 'string') throw new TypeError('text must be a string');
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/**
 * Shorten a string to at most `max` characters, adding an ellipsis when cut.
 * @param {string} text
 * @param {number} max
 * @returns {string}
 */
export function truncate(text, max) {
  if (typeof text !== 'string') throw new TypeError('text must be a string');
  if (text.length <= max) return text;
  return text.slice(0, Math.max(0, max - 1)) + '…';
}
EOF
cat > src/index.js <<'EOF'
export { capitalize, truncate } from './strings.js';
EOF
cat > test/strings.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { capitalize, truncate } from '../src/strings.js';

test('capitalize uppercases the first letter', () => {
  assert.equal(capitalize('hello'), 'Hello');
});

test('capitalize rejects non-strings', () => {
  assert.throws(() => capitalize(42), TypeError);
});

test('truncate leaves short strings alone', () => {
  assert.equal(truncate('abc', 5), 'abc');
});

test('truncate cuts and adds an ellipsis', () => {
  assert.equal(truncate('abcdef', 4), 'abc…');
});
EOF
git init -q -b main
git config user.name "eval"
git config user.email "eval@example.com"
mkdir -p docs/plans/slugify
cat > docs/plans/slugify/PLAN.md <<'PLAN_EOF'
# Plan: slugify(text, options)

Status: APPROVED, EXECUTING
Created: 2026-10-07 · Branch: main · Slug: slugify

## Goal and scope
Add `slugify(text, options)` to textkit. It turns any string into a URL-safe slug: lowercase, ASCII only, words joined by a separator (default `-`). It is exported from `src/index.js`.
- In scope: `slugify` in `src/strings.js` with JSDoc, tests, the export from `src/index.js`, a `separator` option.
- Out of scope: max length, transliteration of non-Latin scripts (CJK, Cyrillic), custom replacement maps, uniqueness/dedup, new dependencies, package.json changes, README.

## Decisions from the user
None: planned with --yes

## Assumptions
1. Only one option: `separator` (string, default `'-'`). `options` itself is optional (`slugify('a b')` works).
2. Accents are stripped via `normalize('NFKD')` and removing combining marks (`Héllo` → `hello`).
3. Characters with no ASCII form after accent stripping (e.g. `ß`, CJK, emoji) are not transliterated. They act as word breaks, so `Straße` → `stra-e` and `日本` → `''`.
4. Apostrophes (`'` and `’`) are removed without splitting the word (`don't` → `dont`).
5. Every other run of non-`[a-z0-9]` characters is one word break. Leading and trailing breaks are dropped. Input with no alphanumerics gives `''`.
6. Digits are kept. Underscores are treated as word breaks.
7. Non-string `text` throws `TypeError('text must be a string')` (same as existing functions). Non-string `separator` throws `TypeError('separator must be a string')`. An empty-string separator is allowed. `options` defaults to `{}` (for `undefined` only; `null` is unspecified and untested). `{ separator: undefined }` uses the default `-`.
8. Implementation: lowercase, NFKD-normalize, strip `/[̀-ͯ]/g`, remove apostrophes, `match(/[a-z0-9]+/g)`, then `Array.join(separator)`. Separators with regex characters (`.`, `_`, `--`) need no escaping.
9. Test names start with their criterion ID (e.g. `A3: collapses punctuation`) so each criterion can be shown passing with `node --test --test-name-pattern="A3"`.
10. Commits include only task files; `docs/plans/slugify/` is committed once, in the T1 commit.
11. The new tests go in the existing `test/strings.test.js`, plus a small `test/index.test.js` that checks the export from `src/index.js`.

## Run policy
- Turn budget: 25 turns
- New dependencies: not allowed
- Never touch: `package.json`, `CLAUDE.md`, existing tests. The only allowed edit to `test/strings.test.js` is adding `slugify` to its import line and appending new tests
- Commits: one local commit per task. No push, no pull request.

## Architecture decision
- Chosen: minimal change. One pure function appended to `src/strings.js` next to `capitalize`/`truncate`, re-exported from `src/index.js`. Why: the library is two tiny files with a flat function-per-export style, and no helper is shared.
- Rejected: separate `src/slugify.js` module with its own test file, because it breaks the one-source-file-one-test-file layout for a ~15-line function.
- Rejected: a configurable options framework (`lowercase`, `maxLength`, `replacements`), because it was not requested.
- Not run: the plan skill's parallel architect agents were skipped because the codebase is two files and the choice was clear. The red-team agent still runs.
- Key files: `src/strings.js`: add `slugify`. `src/index.js`: add `slugify` to the export list. `test/strings.test.js`: add slugify tests. `test/index.test.js`: new, export check.

## Baseline (before any change)
- `npm test`: 4 passed, 0 failed
- lint / typecheck / build: not configured (no scripts, no CI)

## Tasks
Tasks run in order.
- [ ] T1 Write failing tests. Files: `test/strings.test.js`, `test/index.test.js`. Test first: this is the test task. Cover A1–A8 in the Test plan, including A5b and A6b. Proof: `npm test` exits non-zero and the output shows `does not provide an export named 'slugify'` (a link-time SyntaxError is the accepted red state).
- [ ] T2 Implement `slugify` with JSDoc (`@param {string} text`, `@param {{separator?: string}} [options]`, `@returns {string}`). Files: `src/strings.js`. Proof: `node --test test/strings.test.js` exits 0.
- [ ] T3 Export from index. Files: `src/index.js` (`export { capitalize, truncate, slugify } from './strings.js';`). Proof: `node --test test/index.test.js` exits 0.
- [ ] T4 Full verification. Proof: `npm test` exits 0 with the 4 baseline tests still passing, and the smoke command in A10 prints `hello-world`.

## Test plan
| # | Acceptance criterion | Check | Type | Expected result |
|---|---|---|---|---|
| A1 | Lowercases and joins words with `-` | `node --test test/strings.test.js` | unit | exit 0; `slugify('Hello World')` = `hello-world` |
| A2 | Accents stripped to ASCII | same | unit | `slugify('Héllo Wörld')` = `hello-world` |
| A3 | Punctuation and repeated whitespace collapse; edges trimmed | same | unit | `slugify('  Hi,  there!! ')` = `hi-there` |
| A4 | Apostrophes removed; digits kept | same | unit | `slugify("Don't stop 24/7")` = `dont-stop-24-7` |
| A5 | Custom separator, including regex characters | same | unit | `slugify('a b c', { separator: '_' })` = `a_b_c`; `{ separator: '.' }` = `a.b.c` |
| A6 | No alphanumerics gives empty string; non-ASCII-only gives empty string | same | unit | `slugify('!!!')` = `''`; `slugify('日本')` = `''` |
| A5b | Empty and multi-char separators; undefined separator | same | unit | `{separator: ''}` on `'a b'` = `ab`; `{separator: '--'}` = `a--b`; `{separator: undefined}` = `a-b` |
| A6b | Non-decomposable letters are word breaks | same | unit | `slugify('Straße')` = `stra-e` |
| A7 | Bad input throws TypeError | same | unit | `slugify(42)` and `slugify('a', { separator: 1 })` throw TypeError |
| A8 | Exported from `src/index.js` | `node --test test/index.test.js` | unit | exit 0; `slugify` is a function |
| A9 | JSDoc present on exported function | `grep -B10 "export function slugify" src/strings.js` | static | output contains `/**` and `@returns` |
| A10 | End to end through the package entry | `node -e "import('./src/index.js').then(m=>console.log(m.slugify('Héllo, Wörld!')))"` | smoke | prints `hello-world` |
| R1 | No regressions | `npm test` | regression | exit 0; the 4 baseline tests still pass |
| Q1 | Lint/build | none configured | n/a | skipped |

## Done condition
```
/goal Use the feature-dev-auto:execute skill to carry out docs/plans/slugify/PLAN.md. The goal is met only when ALL of these are shown in the conversation: (1) every task in PLAN.md is checked [x] or marked BLOCKED with a reason; (2) a final verification turn runs every check in the Test plan, including `node --test test/strings.test.js`, `node --test test/index.test.js`, `grep -B10 "export function slugify" src/strings.js`, `node -e "import('./src/index.js').then(m=>console.log(m.slugify('Héllo, Wörld!')))"` and `npm test`, and shows each one passing with the expected result (baseline: 4 passing tests, no failures); (3) a code review by three feature-dev-auto:code-reviewer agents left no unresolved issue scored 80 or above; (4) docs/plans/slugify/SUMMARY.md has been written and the last message ends with the line "FEATURE-DEV-AUTO STATUS: DONE". Constraints for the whole run: never ask the user a question; do not delete, skip or weaken any existing test; do not push or open a pull request; do not edit package.json or CLAUDE.md; add no dependencies; stay within the plan's scope and run policy. If 25 turns pass without meeting the goal, write SUMMARY.md with status INCOMPLETE, end with "FEATURE-DEV-AUTO STATUS: INCOMPLETE", and treat that as the end of the goal.
```
PLAN_EOF
cat > docs/plans/slugify/PROGRESS.md <<'PROGRESS_EOF'
# Progress: slugify
Status: NOT STARTED
Base commit: (set by the first execute turn)

## Log
PROGRESS_EOF
git add -A
git commit -qm "textkit baseline + approved slugify plan"
