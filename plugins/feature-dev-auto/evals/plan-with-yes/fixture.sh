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
git add -A
git commit -qm "textkit baseline"
