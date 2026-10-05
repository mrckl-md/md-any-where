const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const app = process.env.MD_ANY_WHERE_APP_PATH || path.join(root, 'dist', 'md any where.app');
const helper = path.join(app, 'Contents', 'MacOS', 'md-any-where-agent');
assert.ok(fs.existsSync(helper), 'Bundled md-any-where-agent helper must exist');
const input = [
  {jsonrpc:'2.0', id:1, method:'initialize', params:{protocolVersion:'2025-06-18'}},
  {jsonrpc:'2.0', method:'notifications/initialized'},
  {jsonrpc:'2.0', id:2, method:'tools/list'}
].map(value => JSON.stringify(value)).join('\n') + '\n';
const run = spawnSync(helper, ['mcp'], {input, encoding:'utf8', timeout:5000});
assert.equal(run.status, 0, run.stderr);
const responses = run.stdout.trim().split('\n').map(JSON.parse);
assert.equal(responses[0].result.serverInfo.name, 'MDAnyWhere');
assert.equal(responses[0].result.serverInfo.title, 'md any where');
assert.equal(responses[0].result.serverInfo.version, '1.0.0');
const names = responses[1].result.tools.map(tool => tool.name);
for (const name of ['mdanywhere_status','mdanywhere_list_documents','mdanywhere_read_document','mdanywhere_create_document',
  'mdanywhere_replace_document','mdanywhere_append_text','mdanywhere_insert_diagram','mdanywhere_find_replace','mdanywhere_save_document']) {
  assert.ok(names.includes(name), `MCP tool ${name} must be exposed`);
}
console.log('md any where MCP stdio handshake and tool catalog passed.');
