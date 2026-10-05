const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const app = process.env.DOT_MD_APP_PATH || path.join(root, 'dist', 'DOT MD.app');
const helper = path.join(app, 'Contents', 'MacOS', 'dotmd-agent');
assert.ok(fs.existsSync(helper), 'Bundled dotmd-agent helper must exist');
const input = [
  {jsonrpc:'2.0', id:1, method:'initialize', params:{protocolVersion:'2025-06-18'}},
  {jsonrpc:'2.0', method:'notifications/initialized'},
  {jsonrpc:'2.0', id:2, method:'tools/list'}
].map(value => JSON.stringify(value)).join('\n') + '\n';
const run = spawnSync(helper, ['mcp'], {input, encoding:'utf8', timeout:5000});
assert.equal(run.status, 0, run.stderr);
const responses = run.stdout.trim().split('\n').map(JSON.parse);
assert.equal(responses[0].result.serverInfo.name, 'DOT MD');
assert.equal(responses[0].result.serverInfo.version, '1.0.0');
const names = responses[1].result.tools.map(tool => tool.name);
for (const name of ['dotmd_status','dotmd_list_documents','dotmd_read_document','dotmd_create_document',
  'dotmd_replace_document','dotmd_append_text','dotmd_insert_diagram','dotmd_find_replace','dotmd_save_document']) {
  assert.ok(names.includes(name), `MCP tool ${name} must be exposed`);
}
console.log('DOT MD MCP stdio handshake and tool catalog passed.');
