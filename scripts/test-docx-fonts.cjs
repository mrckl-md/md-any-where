const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../Sources/DOTMD/Resources/docx-export.js'), 'utf8');
const context = { window: {}, document: {}, localStorage: {} };
vm.runInNewContext(source, context);

const { cleanSettings, preset, parseInstruction } = context.window.dotmdDocx;
const defaults = cleanSettings({});
assert.equal(defaults.bodyCjkFont, '宋体');
assert.equal(defaults.bodyLatinFont, 'Times New Roman');
assert.equal(defaults.mathLatinFont, 'Cambria Math');
assert.equal(preset('academic-cn').mathLatinFont, 'Times New Roman');
assert.equal(preset('standard').mathLatinFont, 'Cambria Math');

const migrated = cleanSettings({ bodyFont: 'PingFang SC', headingFont: 'Arial' });
assert.equal(migrated.bodyCjkFont, 'PingFang SC');
assert.equal(migrated.headingLatinFont, 'Arial');

const requested = parseInstruction(
  '中文设置为宋体，英语用 Times New Roman，公式也用 Times New Roman，标题中文用黑体',
  defaults
);
assert.equal(requested.bodyCjkFont, '宋体');
assert.equal(requested.bodyLatinFont, 'Times New Roman');
assert.equal(requested.mathLatinFont, 'Times New Roman');
assert.equal(requested.headingCjkFont, '黑体');
assert.equal(requested.mathCjkFont, '宋体');
console.log('DOCX script-specific font settings and instruction parsing passed.');
