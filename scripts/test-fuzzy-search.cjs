const assert = require('node:assert/strict');
const { findInLine, boundedEditDistance } = require('../Sources/DOTMD/Resources/fuzzy-search.js');

assert.equal(boundedEditDistance('formula', 'formla', 2), 1);
assert.equal(boundedEditDistance('markdown', 'unrelated', 2), 3);

const examples = [
  ['Markdown editor', 'markdown', 1],
  ['Markdown editor', 'Markdwon', 0.66],
  ['apple pie', 'aple', 0.66],
  ['中文公式编辑', '公式编缉', 0.66]
];
for (const [line, query, minimumScore] of examples) {
  const result = findInLine(line, query);
  assert.ok(result.match, `Expected ${query} to match ${line}`);
  assert.ok(result.match.score >= minimumScore);
  assert.equal(result.limited, false);
}

assert.equal(findInLine('a completely different sentence', 'xyz').match, null);
assert.equal(findInLine('content', 'x'.repeat(65)).match, null);

// A long minified line must have bounded work even when many anchors repeat.
const pathological = findInLine('ab'.repeat(50_000), 'abbb');
assert.ok(pathological.match || pathological.limited);

console.log('Fuzzy search tests passed.');
