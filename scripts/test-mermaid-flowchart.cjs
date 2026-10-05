const assert = require('node:assert/strict');
// These assertions intentionally exercise the Simplified Chinese error catalog.
require('../Sources/DOTMD/Resources/i18n.js').setLanguage('zh-Hans');
const renderer = require('../Sources/DOTMD/Resources/mermaid-flowchart.js');

const source = `flowchart LR
  input[训练数据] --> forward[前向传播]
  forward --> loss{损失收敛?}
  loss -->|否| backward[反向传播]
  backward -.-> forward
  loss ==>| 是 | done((完成))`;
const graph = renderer.parse(source);
assert.equal(graph.direction, 'LR');
assert.equal(graph.nodes.length, 5);
assert.equal(graph.edges.length, 5);
assert.equal(graph.edges[2].label, '否');
const svg = renderer.renderSVG(source);
assert.match(svg, /^<svg/);
assert.match(svg, /反向传播/);
assert.doesNotMatch(svg, /<script/i);
assert.match(svg, /<path class="dotmd-flow-edge" d="M [\d.]+ [\d.]+ C /,
  'Connections should be smoothly routed from node boundaries, not through labels');
const referenceStyle = `flowchart TD
  raw[原始文稿] --> choice{值得保留？}
  choice -->|否| discard[丢弃]
  choice -->|是| clean[整理为 Markdown]
  clean --> output[完成]`;
const vertical = renderer.renderSVG(referenceStyle);
assert.match(vertical, /<polygon/);
assert.match(vertical, /值得保留？/);
assert.match(vertical, />否<\/text>/);
assert.match(vertical, />是<\/text>/);
assert.throws(() => renderer.parse('sequenceDiagram\nA->>B: hello'), /第一行/);
console.log('Offline Mermaid flowchart parser and SVG renderer passed.');
