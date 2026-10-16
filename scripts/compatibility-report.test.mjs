import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildBadge, parseVitestLog, summary } from './compatibility-report.mjs';

test('sums vitest summaries and ignores file counts', () => {
  const parsed = parseVitestLog(`
 Test Files  14 passed (14)
      Tests  226 passed (226)

 Test Files  1 failed | 2 passed (3)
      Tests  2 failed | 57 passed (59)
      Tests  4 skipped (4)
`);
  assert.deepEqual(parsed, { passed: 283, total: 289, reports: 3 });
});

test('strips color and counts a fully failed run as zero passed', () => {
  const parsed = parseVitestLog('\u001b[31m      Tests  3 failed (3)\u001b[0m\n');
  assert.deepEqual(parsed, { passed: 0, total: 3, reports: 1 });
});

test('badge uses the workspace total and the cloned OpenUI version', () => {
  const badge = buildBadge('1.0.1', [
    { name: 'parser', passed: 99, total: 99, reports: 1 },
    { name: 'lang-core', passed: 226, total: 226, reports: 1 },
    { name: 'workspace', passed: 400, total: 402, reports: 8 },
  ]);
  assert.equal(badge.label, 'OpenUI 1.0.1');
  assert.equal(badge.message, '400/402');
  assert.equal(badge.isError, true);
  assert.equal(badge.color, 'e05d44');
  assert.equal(Object.hasOwn(badge, 'stages'), false);
  assert.match(
    summary(badge, [{ name: 'workspace', passed: 400, total: 402 }]),
    /\| workspace \| 400\/402 \|/,
  );
});

test('a complete workspace run is compatible', () => {
  const badge = buildBadge('1.2.0', [
    { name: 'parser', passed: 1, total: 1, reports: 1 },
    { name: 'lang-core', passed: 2, total: 2, reports: 1 },
    { name: 'workspace', passed: 3, total: 3, reports: 1 },
  ]);
  assert.equal(badge.isError, false);
  assert.equal(badge.color, 'EDED91');
  assert.equal(badge.message, '3/3');
});
