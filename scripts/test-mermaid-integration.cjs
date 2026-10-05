const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const resourceDirectory = path.resolve(__dirname, '..', 'Sources', 'DOTMD', 'Resources');
const appDirectory = path.join(process.env.DOT_MD_APP_PATH || path.resolve(__dirname, '..', 'dist', 'DOT MD.app'), 'Contents', 'Resources', 'Editor');
const fixture = fs.readFileSync(path.resolve(__dirname, '..', '示例-复杂公式与流程图.md'), 'utf8');

function testPackagedRenderer(directory) {
  const html = fs.readFileSync(path.join(directory, 'index.html'), 'utf8');
  const app = fs.readFileSync(path.join(directory, 'app.js'), 'utf8');
  assert.ok(html.indexOf('src="mermaid-flowchart.js"') < html.indexOf('src="app.js"'),
    'Flowchart module must load before the editor');
  assert.match(app, /dotmdMermaid\.installMarkdownIt\(md\)/, 'Editor must install the same tested Markdown renderer');

  const MarkdownIt = require(path.join(directory, 'vendor', 'markdown-it', 'markdown-it.min.js'));
  const renderer = require(path.join(directory, 'mermaid-flowchart.js'));
  const markdown = MarkdownIt({html:false});
  renderer.installMarkdownIt(markdown);
  const rendered = markdown.render(fixture);
  assert.match(rendered, /class="dotmd-mermaid"/, 'The example Mermaid fence must become a diagram container');
  assert.doesNotMatch(rendered, /<pre><code class="language-mermaid"/, 'Mermaid must never fall back to a raw code block');
  const fencedSource = fixture.match(/```mermaid\n([\s\S]*?)\n```/)?.[1];
  assert.ok(fencedSource);
  assert.match(renderer.renderSVG(fencedSource), /<polygon/, 'Decision node must render as a diamond');
  assert.match(renderer.renderSVG(fencedSource), /导出结果/, 'Final node must be visible');
  assert.match(markdown.render('```js\nconst x = 1;\n```'), /<pre><code/, 'Other languages must stay ordinary code');
}

testPackagedRenderer(resourceDirectory);
if (fs.existsSync(appDirectory)) testPackagedRenderer(appDirectory);
console.log('Source and bundled Markdown-to-Mermaid rendering integration passed.');
